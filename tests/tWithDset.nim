import nimhdf5
import sequtils
import os

const
  File = "tests/tWithDset.h5"
  di64 = @[1'i64, 2, 3, 4]
  diS64 = di64.mapIt(di64)

proc write[T; U](h5f: var H5FileObj, data: seq[T], dtype: typedesc[U]): H5DataSet =
  when T is seq:
    result = h5f.create_dataset("/dsetS" & $dtype, data.len, seq[dtype])
    result[result.all] = data
  else:
    result = h5f.create_dataset("/dset" & $dtype, data.len, dtype)
    result[result.all] = data
  echo result

template writeData(typ, dkind: untyped): untyped {.dirty.} =
  block:
    doAssert h5f.write(di64.mapIt(it.typ), typ).dtypeAnyKind == dkind
    var data = di64.mapIt(di64.mapIt(it.typ))
    let dset = h5f.write(data, typ)
    doAssert dset.dtypeAnyKind == dkSequence
    doAssert dset.dtypeBaseKind == dkind

template readData(typ, dkind): untyped {.dirty.} =
  block:
    let h5dset = h5f[("/dset" & $typ).dset_str]
    withDset(h5dset):
      let tmp = di64.mapIt(it.typ)
      when typeof(tmp) is typeof(dset): ## Need to use this when, as this code is only valid
                                        ## in the correct type branch.
        doAssert tmp == dset
    let h5dsetS = h5f[("/dsetS" & $typ).dset_str]
    withDset(h5dsetS):
      let tmp = di64.mapIt(di64.mapIt(it.typ))
      when typeof(tmp) is typeof(dset):
        doAssert tmp == dset

    ## one case is enough for `withDset` overload taking a dset name
    h5f.withDset("/dsetS" & $typ):
      let tmp = di64.mapIt(di64.mapIt(it.typ))
      when typeof(tmp) is typeof(dset):
        doAssert tmp == dset

when isMainModule:
  # open file, create dataset
  var
    h5f = H5open(File, "rw")

  # write all datasets
  writeData(int64,   dkInt64)
  writeData(int32,   dkInt32)
  writeData(int16,   dkInt16)
  writeData( int8,   dkInt8)
  writeData(uint64,  dkUInt64)
  writeData(uint32,  dkUInt32)
  writeData(uint16,  dkUInt16)
  writeData( uint8,  dkUInt8)
  writeData(float32, dkFloat32)
  writeData(float64, dkFloat64)

  var err = h5f.close()
  assert(err >= 0)
  h5f = H5open(File, "r")

  readData(int64,   dkInt64)
  readData(int32,   dkInt32)
  readData(int16,   dkInt16)
  readData( int8,   dkInt8)
  readData(uint64,  dkUInt64)
  readData(uint32,  dkUInt32)
  readData(uint16,  dkUInt16)
  readData( uint8,  dkUInt8)
  readData(float32, dkFloat32)
  readData(float64, dkFloat64)

  err = h5f.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
