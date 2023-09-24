import ./[datatypes, attributes, copyflat]
import std / [tables, json, sequtils, math]

func `%`(c: char): JsonNode = % $c # for `withAttr` returning a char
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

## And code to read also datasets and groups as JSON:

proc read[T](buf: Buffer, _: typedesc[T]): T =
  ## Wrapper around `copyflat.fromFlat`
  fromFlat(result, buf)

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

proc readCompoundElement(buf: Buffer, tab: OrderedTable[string, (int, int, DtypeKind)]): JsonNode =
  ## Process a single compound element at current `offsetOf`
  result = newJObject()
  var i = 0
  for name, (idx, size, dtype) in pairs(tab):
    result[name] = % readElement(buf, dtype)
    inc buf.offsetOf, size
    doAssert i == idx
    inc i

proc assign(buf: Buffer, tab: OrderedTable[string, (int, int, DtypeKind)], shape: seq[int]): JsonNode =
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
proc readCompoundJson(d: H5Dataset): JsonNode =
  result = newJObject()
  let numMembers = d.dtype_c.getNumberMembers()
  ## NOTE: In order to support nested objects / seqs, we need to change this approach slightly.
  ## We need to check if a `typ` itself is COMPOUND and instead of constructing a simple table
  ## like this, we'd need a nested data structure so that inside of the data reading from the
  ## buffer, we have the required field sizes of the nested data.
  ## For sequences the problem is slightly different: We need to know the inner type and not just
  ## know it's a sequence.
  var tab = initOrderedTable[string, (int, int, DtypeKind)]()
  for i in 0 ..< numMembers:
    let name = getMemberName(d.dtype_c, i)
    let typ = getMemberType(d.dtype_c, i)
    let size = getSize(typ)
    tab[name] = (i, size, typ.h5toNimType())
  # Read the compound data into a buffer
  let buf = newBuffer(getSize(d.dtype_c) * d.shape.prod)
  # read data
  read(d, buf.data)
  # copy data to JSON
  result = assign(buf, tab, d.shape)
  let dspaceId = d.dataspaceId()
  doAssert H5Dvlen_reclaim(d.dtype_c.id, dspaceId.id, H5P_DEFAULT, buf.data) >= 0

proc readJson*(d: H5Dataset): JsonNode =
  case d.dtypeAnyKind
  of dkBool:     result = % d[bool]
  of dkChar:     result = % d[char].mapIt($it)
  of dkEnum:     result = % d[string]
  of dkString:   result = % d[string]
  of dkCString:  result = % d[string]
  of dkInt:      result = % d[int]
  of dkInt8:     result = % d[int8]
  of dkInt16:    result = % d[int16]
  of dkInt32:    result = % d[int32]
  of dkInt64:    result = % d[int64]
  of dkFloat:    result = % d[float]
  of dkFloat32:  result = % d[float32]
  of dkFloat64:  result = % d[float]
  of dkUInt:     result = % d[uint]
  of dkUInt8:    result = % d[uint8]
  of dkUInt16:   result = % d[uint16]
  of dkUInt32:   result = % d[uint32]
  of dkUInt64:   result = % d[uint64]
  of dkObject, dkTuple: result = readCompoundJson(d)
  of dkRef:      result = % d[int]      ## XXX: H5Reference!
  of dkSequence: result = % d[int]      ## XXX: VLEN or ND data
  of dkNone, dkArray, dkSet, dkRange, dkPtr, dkFloat128, dkProc, dkPointer: result = newJNull()

import h5_iterators
proc readJson*(d: H5Group): JsonNode =
  result = newJObject()
  for dset in items(d, depth = 1): ## XXX: could there be nested data? If so, groups, so also iterate over groups before
    result[dset.name] = readJson(dset)
