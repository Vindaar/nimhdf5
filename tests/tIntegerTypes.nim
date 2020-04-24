import nimhdf5
import sequtils
import os
import ospaths

# simple test which checks mapping, writing and reading of
# different integer types

const
  File = "tests/tIntegerTypes.h5"
  di64 = @[1'i64, 2, 3, 4]
  di32 = @[1'i32, 2, 3, 4]
  di16 = @[1'i16, 2, 3, 4]
  di8 = @[1'i8, 2, 3, 4]
  du64 = @[1'u64, 2, 3, 4]
  du32 = @[1'u32, 2, 3, 4]
  du16 = @[1'u16, 2, 3, 4]
  du8 = @[1'u8, 2, 3, 4]

proc write[T; U](h5f: var H5FileObj, data: T, dtype: typedesc[U]): H5DataSet =
  echo "/dset" & $dtype
  result = h5f.create_dataset("/dset" & $dtype, 4, dtype)
  result[result.all] = data

proc read[T](h5f: var H5FileObj, dtype: typedesc[T]): seq[T] =
  let dset = "/dset" & $dtype
  echo "READING ", dset
  let dd = h5f[dset.dset_str]
  result = dd[dtype]

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")

  # write all datasets
  doAssert h5f.write(di64, int64).dtypeAnyKind == dkInt64
  doAssert h5f.write(di32, int32).dtypeAnyKind == dkInt32
  doAssert h5f.write(di16, int16).dtypeAnyKind == dkInt16
  doAssert h5f.write(di8, int8).dtypeAnyKind == dkInt8
  doAssert h5f.write(du64, uint64).dtypeAnyKind == dkUInt64
  doAssert h5f.write(du32, uint32).dtypeAnyKind == dkUInt32
  doAssert h5f.write(du16, uint16).dtypeAnyKind == dkUInt16
  doAssert h5f.write(du8, uint8).dtypeAnyKind == dkUInt8

  var err = h5f.close()
  assert(err >= 0)
  h5f = H5File(File, "r")

  doAssert h5f.read(int64) == di64
  doAssert h5f.read(int32) == di32
  doAssert h5f.read(int16) == di16
  doAssert h5f.read(int8) == di8
  doAssert h5f.read(uint64) == du64
  doAssert h5f.read(uint32) == du32
  doAssert h5f.read(uint16) == du16
  doAssert h5f.read(uint8) == du8

  err = h5f.close()
  assert(err >= 0)

  # clean up after ourselves
  #removeFile(File)
