import ./[datatypes, attributes, copyflat, dataspaces]
import std / [tables, json, sequtils, math]


type
  BufferWrapperObj = object
    buf: Buffer
    shape: seq[int]
    dtypeID: DatatypeID
    dspaceID: DataspaceID
    cleanup: proc(buf: Buffer, dtype_c: DatatypeID, dspaceID: DataspaceID)
    tab: MemberSizeTable
  BufferWrapper* = ref BufferWrapperObj

  MemberSizeTable = OrderedTable[string, (int, int, DtypeKind)]

proc `=destroy`(buf: BufferWrapperObj) =
  buf.cleanup(buf.buf, buf.dtypeID, buf.dspaceID)
  `=destroy`(buf.buf)

## Code to read also datasets and groups as JSON:

proc read[T](buf: Buffer, _: typedesc[T]): T =
  ## Wrapper around `copyflat.fromFlat`
  fromFlat(result, buf)

proc write[T](buf: var Buffer, val: T) =
  ## Wrapper around `copyflat.copyflat`
  copyFlat(buf, val)

proc readElement(buf: Buffer, dtype: DtypeKind): JsonNode =
  case dtype
  of dkBool:     result = % buf.read(bool)
  of dkChar:     result = % $buf.read(char)
  of dkEnum:     result = % buf.read(string)
  of dkString:   result = % buf.read(string)
  of dkCString:  result = % buf.read(string)
  of dkInt:      result = % buf.read(int)
  of dkInt8:     result = % buf.read(int8)
  of dkInt16:    result = % buf.read(int16)
  of dkInt32:    result = % buf.read(int32)
  of dkInt64:    result = % buf.read(int64)
  of dkFloat:    result = % buf.read(float)
  of dkFloat32:  result = % buf.read(float32)
  of dkFloat64:  result = % buf.read(float64)
  of dkUInt:     result = % buf.read(uint)
  of dkUInt8:    result = % buf.read(uint8)
  of dkUInt16:   result = % buf.read(uint16)
  of dkUInt32:   result = % buf.read(uint32)
  of dkUInt64:   result = % buf.read(uint64)
  of dkSequence: doAssert false, "Implement nested sequences!"
  of dkObject:   doAssert false, "Implement nested objects!"
  else: doAssert false

proc readCompoundElement(buf: Buffer, tab: MemberSizeTable): JsonNode =
  ## Process a single compound element at current `offsetOf`
  result = newJObject()
  var i = 0
  for name, (idx, size, dtype) in pairs(tab):
    result[name] = % readElement(buf, dtype)
    inc buf.offsetOf, size
    doAssert i == idx
    inc i

proc assign(buf: Buffer, tab: MemberSizeTable, shape: seq[int]): JsonNode =
  if shape.len == 1:
    # assign this row
    result = newJArray()
    for col in 0 ..< shape[0]:
      # this is a single element of the compound type
      result.add readCompoundElement(buf, tab)
  else:
    result = newJArray()
    for row in 0 ..< shape[0]:
      result.add assign(buf, tab, shape[1 .. ^1])

import ./datasets
from hdf5_wrapper import H5Dvlen_reclaim, H5P_DEFAULT
proc reclaim(buf: Buffer, dtype_c: DatatypeID, dspaceID: DataspaceID) =
  ## IMPORTANT: We must assign a `DatatypeID` instead of a raw `hid_t`, because `dataspaceID`
  ## is a `proc`. If we were to write `else: dset.dataspaceId.id` the returned value would
  ## be `=destroy`-ed before the `H5Dvlen_reclaim` call again!
  let err = H5Dvlen_reclaim(dtype_c.id, dspaceId.id, H5P_DEFAULT, buf.data)
  if err != 0:
    raise newException(HDF5LibraryError, "HDF5 library failed to reclaim variable length memory.")

proc read(attr: H5Attr, buf: pointer) =
  ## Wrapper to have same API for both H5Dataset and H5Attr
  attr.readAttribute(buf)

proc readCompoundToBuffer[T: H5Dataset | H5Attr](h5o: T): BufferWrapper =
  ## Reads the given compound data into a `Buffer` for further consumption. Can be converted
  ## to JSON using `toJson` or reused i.e. to copy data using the same memory.
  ##
  ## NOTE: It returns a *wrapped* `Buffer` object, which has a `cleanup` field that contains
  ## a call to `reclaim` so that we return tell the HDF5 lib to reclaim its memory, that is
  ## used in the buffer. It also contains the dataspace ID and shape information.
  let dtype_c = h5o.dtype_c
  let shape = when T is H5Dataset: h5o.shape else: @[getNumberOfPoints(h5o.attr_dspace_id)]
  let dspaceId = when T is H5Dataset: h5o.dataspaceID() else: h5o.attr_dspace_id
  let numMembers = dtype_c.getNumberMembers()
  ## NOTE: In order to support nested objects / seqs, we need to change this approach slightly.
  ## We need to check if a `typ` itself is COMPOUND and instead of constructing a simple table
  ## like this, we'd need a nested data structure so that inside of the data reading from the
  ## buffer, we have the required field sizes of the nested data.
  ## For sequences the problem is slightly different: We need to know the inner type and not just
  ## know it's a sequence.
  var tab = initOrderedTable[string, (int, int, DtypeKind)]()
  for i in 0 ..< numMembers:
    let name = getMemberName(dtype_c, i)
    let typ = getMemberType(dtype_c, i)
    let size = getSize(typ)
    tab[name] = (i, size, typ.h5toNimType())
  # Read the compound data into a buffer
  result = BufferWrapper(shape: shape,
                         dspaceID: dspaceID,
                         dtypeID: dtype_c,
                         tab: tab,
                         cleanup: reclaim)
  result.buf = newBuffer(getSize(dtype_c) * shape.prod)
  # read data
  read(h5o, result.buf.data)

proc toJson(buf: BufferWrapper): JsonNode =
  # copy data to JSON
  result = assign(buf.buf, buf.tab, buf.shape)
  # Reclaim run automatically on `=destroy` of `BufferWrapper`

proc assign[T](data: seq[T], shape: seq[int], idx: var int): JsonNode =
  ## Similar proc to `assign` above but working with a flat 1D array of `shape`
  ## of native data.
  if shape.len == 1:
    # assign this row
    result = newJArray()
    for col in 0 ..< shape[0]:
      # this is a single element of the compound type
      result.add (% data[idx])
      inc idx
  else:
    result = newJArray()
    for row in 0 ..< shape[0]:
      result.add assign(data, shape[1 .. ^1], idx)

proc assign[T](data: seq[T], shape: seq[int]): JsonNode =
  var idx = 0
  result = assign(data, shape, idx)

proc assign[T: not seq](data: T, shape: seq[int]): JsonNode =
  var idx = 0
  result = assign(@[data], shape, idx)

proc readJson*[T: H5Dataset | H5Attr](h5o: T): JsonNode =
  let shape = when T is H5Dataset: h5o.shape else: @[getNumberOfPoints(h5o.attr_dspace_id)]
  template mapChr(s: untyped): untyped =
    when typeof(s) is seq: s.mapIt($it)
    else: $s
  case h5o.dtypeAnyKind
  of dkBool:     result = assign(h5o[bool]          , shape)
  of dkChar:     result = assign(h5o[char].mapChr() , shape)
  of dkEnum:     result = assign(h5o[string]        , shape)
  of dkString:   result = assign(h5o[string]        , shape)
  of dkCString:  result = assign(h5o[string]        , shape)
  of dkInt:      result = assign(h5o[int]           , shape)
  of dkInt8:     result = assign(h5o[int8]          , shape)
  of dkInt16:    result = assign(h5o[int16]         , shape)
  of dkInt32:    result = assign(h5o[int32]         , shape)
  of dkInt64:    result = assign(h5o[int64]         , shape)
  of dkFloat:    result = assign(h5o[float]         , shape)
  of dkFloat32:  result = assign(h5o[float32]       , shape)
  of dkFloat64:  result = assign(h5o[float]         , shape)
  of dkUInt:     result = assign(h5o[uint]          , shape)
  of dkUInt8:    result = assign(h5o[uint8]         , shape)
  of dkUInt16:   result = assign(h5o[uint16]        , shape)
  of dkUInt32:   result = assign(h5o[uint32]        , shape)
  of dkUInt64:   result = assign(h5o[uint64]        , shape)
  of dkObject, dkTuple: result = toJson readCompoundToBuffer(h5o)
  of dkRef:      result = % h5o[int]      ## XXX: H5Reference!
  of dkSequence: result = toJson readCompoundToBuffer(h5o)      ## XXX: VLEN or ND data
  of dkNone, dkArray, dkSet, dkRange, dkPtr, dkFloat128, dkProc, dkPointer: result = newJNull()

import h5_iterators
proc readJson*(d: H5Group): JsonNode =
  result = newJObject()
  for dset in items(d, depth = 1): ## XXX: could there be nested data? If so, groups, so also iterate over groups before
    result[dset.name] = readJson(dset)

proc `[]=`*(h5o: H5Attributes, name: string, val: JsonNode) =
  ## Writes the given JsonNode as native compound data to the attribute
  ## XXX: This still has to be written!
  echo "[WARNING] Assignment of JsonNode as attribute still not implemented!"
  # Requires creating a compound type from JsonNode data and then filling a `Buffer` from
  # the json and finally writing it. Shouldn't be /too/ annoying.

template withAttr*(h5attr: H5Attributes, name: string, actions: untyped) =
  ## convenience template to read and work with an attribute from the file and perform actions
  ## with that attribute, without having to manually check the data type of the attribute

  ## NOTE: There is no `H5Ocopy` for attributes. So this is not only useful for convenience
  ## to get access to the data as Nim objects, but also when copying attributes.
  ## Copying itself can also be done by simply getting the size, reading into a buffer,
  ## copying data type and space and writing the same buffer to a new location.
  let attrObj {.inject.} = h5attr.attr_tab[name]
  case attrObj.dtypeAnyKind
  of dkBool:
    let attr {.inject.} = h5attr[name, bool]
    actions
  of dkChar:
    let attr {.inject.} = h5attr[name, char]
    actions
  of dkString:
    let attr {.inject.} = h5attr[name, string]
    actions
  of dkFloat32:
    let attr {.inject.} = h5attr[name, float32]
    actions
  of dkFloat64:
    let attr {.inject.} = h5attr[name, float64]
    actions
  of dkInt8:
    let attr {.inject.} = h5attr[name, int8]
    actions
  of dkInt16:
    let attr {.inject.} = h5attr[name, int16]
    actions
  of dkInt32:
    let attr {.inject.} = h5attr[name, int32]
    actions
  of dkInt64:
    let attr {.inject.} = h5attr[name, int64]
    actions
  of dkUint8:
    let attr {.inject.} = h5attr[name, uint8]
    actions
  of dkUint16:
    let attr {.inject.} = h5attr[name, uint16]
    actions
  of dkUint32:
    let attr {.inject.} = h5attr[name, uint32]
    actions
  of dkUint64:
    let attr {.inject.} = h5attr[name, uint64]
    actions
  of dkSequence:
    # need to perform same game again...
    case h5attr.attr_tab[name].dtypeBaseKind
    of dkString:
      let attr {.inject.} = h5attr[name, seq[string]]
      actions
    of dkFloat32:
      let attr {.inject.} = h5attr[name, seq[float32]]
      actions
    of dkFloat64:
      let attr {.inject.} = h5attr[name, seq[float64]]
      actions
    of dkInt8:
      let attr {.inject.} = h5attr[name, seq[int8]]
      actions
    of dkInt16:
      let attr {.inject.} = h5attr[name, seq[int16]]
      actions
    of dkInt32:
      let attr {.inject.} = h5attr[name, seq[int32]]
      actions
    of dkInt64:
      let attr {.inject.} = h5attr[name, seq[int64]]
      actions
    of dkUint8:
      let attr {.inject.} = h5attr[name, seq[uint8]]
      actions
    of dkUint16:
      let attr {.inject.} = h5attr[name, seq[uint16]]
      actions
    of dkUint32:
      let attr {.inject.} = h5attr[name, seq[uint32]]
      actions
    of dkUint64:
      let attr {.inject.} = h5attr[name, seq[uint64]]
      actions
    else:
      let attr {.inject.} = readJson(attrObj)
      actions
  else:
    let attr {.inject.} = readJson(attrObj)
    actions

## The following JSON related procs are placeholders. We might implement them fully to be
## able to write compound data at runtime baesd on JSON data.
proc calcSize(n: JsonNode): int =
  case n.kind
  of JInt: result = sizeof(int)
  of JString: result = sizeof(char) * n.str.len
  of JFloat: result = sizeof(float)
  of JBool: result = sizeof(bool)
  of JNull: result = 0
  of JArray:
    result = sizeof(int) # length prefix
    for j in n:
      result += calcSize(j)
  of JObject:
    for k, v in n: ## Key names are irrelevant. This is for compound data.
                   # Or do we use them to fill the member names? Not needed, no?
      result += calcSize(v)

proc copyflat(buf: var Buffer, val: JsonNode) =
  ## NOTE:
  ## Given that the JsonNode type only contains 64 bit sized values (aside from `bool`,
  ## which we (TODO: convert to int?) might convert, we can probably avoid worrying
  ## about any packing logic.
  case val.kind
  of JNull: discard
  of JInt: buf.write(val.num.int)
  of JString: buf.write(getAddr(val.str)) ## Write the string's *address*. JsonNode *must* outlive buffer!
  of JBool: buf.write(val.bval)
  of JFloat: buf.write(val.fnum)
  of JArray:
    ## XXX: needs to be (csize_t(len), pointer(child buffer)) instead
    var chBuf = newBuffer(calcSize(val))
    for x in val: ## Create child buffer for its pointer
      chBuf.copyflat(x)
    buf.children.add chBuf
    buf.write((csize_t(val.len), cast[uint](chBuf.data))) ## add length and child buffer pointer
  of JObject:
    for k, v in val:
      buf.copyflat(v)

proc jsonToH5Buffer(data: JsonNode): Buffer =
  ## Constructs a `Buffer` with data valid for HDF5 writing from given JSON data.
  ## This is our approach to dealing with compound data at runtime.
  ##
  ## Note that this is especially inefficient if the data contains long sequences of
  ## numbers, as each element in a JsonNode is stored from an indirection (which is
  ## flattened in the buffer of course).
  let size = calcSize(data)
  result = newBuffer(size)
  result.copyflat(data)

proc jsonToH5Type(data: JsonNode): DatatypeID =
  case data.kind
  of JNull: discard
  of JInt: result = nimToH5Type(int)
  of JString: result = nimToH5Type(string)
  of JBool: result = nimToH5Type(bool)
  of JFloat: result = nimToH5Type(float)
  of JArray:
    # check all array elements same type!
    var typ = data[0].kind
    for x in data:
      if x.kind != typ:
        raise newException(ValueError, "Heterogeneous JsonNodes cannot be written to an HDF5 file.")
    case typ
    of JInt: result = nimToH5Type(seq[int])
    of JBool: result = nimToH5Type(seq[bool])
    of JFloat: result = nimToH5Type(seq[float])
    of JString: result = nimToH5Type(seq[string])
    else:
      doAssert false, "IMPLEMENT ME: " & $typ
  of JObject:
    for k, v in data:
      doAssert false, "IMPLEMENT ME"

func `%`(c: char): JsonNode = % $c # for `withAttr` returning a char
proc copy_attributes*[T: H5Group | H5DataSet](h5o: T, attrs: H5Attributes) =
  ## copies the attributes contained in `attrs` given to the function to the `h5o` attributes
  ## this can be used to copy attributes also between different files
  # simply walk over all key value pairs in the given attributes and
  # write them as new attributes to `h5o`
  attrs.read_all_attributes()
  for key, value in pairs(attrs.attr_tab):
    ## NOTE: We cannot use `H5Ocopy` or similar. There is no API available to copy attributes
    ## in this way. This is slightly problematic, because we cannot nicely handle reading
    ## for arbitrary types using the `withAttr` template
    attrs.withAttr(key):
      # use injected read attribute value to write it
      if attrObj.dtypeAnyKind != dkObject and attrObj.dtypeBaseKind != dkObject: # simply assign
        h5o.attrs[key] = attr
      else: # copy over from `BufferWrapper`
        let buf = readCompoundToBuffer(attrObj)
        # create the attribute copy
        let dtype = copyType(buf.dtypeID)
        let attribute_id = createAttribute(h5o.attrs.parent_id, key, dtype,
                                           copyDataspace(buf.dspaceID))
        # write the value
        writeAttribute(attribute_id, dtype, buf.buf.data)
        h5o.attrs.num_attrs = h5o.attrs.getNumAttrs

    # close attr again to avoid memory leaking
    value.close()

iterator attrsJson*(attrs: H5Attributes, withType = false): (string, JsonNode) =
  ## yields all attribute keys and their values as `JsonNode`. This way
  ## we can actually return all values to the user with one iterator.
  ## And for attributes the variant object overhead does not matter anyways.
  attrs.read_all_attributes
  for key, att in pairs(attrs.attr_tab):
    attrs.withAttr(key):
      if not withType:
        yield (key, % attr)
      else:
        yield (key, %* {
          "value" : attr,
          "type" : att.dtypeAnyKind
        })
    att.close()

iterator attrsJson*[T: H5File | H5Group | H5DataSet](h5o: T, withType = false): (string, JsonNode) =
  for key, val in attrsJson(h5o.attrs, withType = withType):
    yield (key, val)

proc attrsToJson*[T: H5Group | H5DataSet](h5o: T, withType = false): JsonNode =
  ## returns all attributes as a json node of kind `JObject`
  result = newJObject()
  for key, jval in h5o.attrsJson(withType = withType):
    result[key] = jval
