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
