import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/dset"
  Dset2Name = "dset2"
const data = @[0, 1, 2 ,3, 4, 5, 6, 7, 8, 9]

proc create_dset(h5f: var H5FileObj, name: string): H5DataSet =
  result = h5f.create_dataset(name, 10, int)
  result[result.all] = data

proc assert_fields(dset: H5DataSet) =
  assert(dset.shape == @[10, 1])
  assert(dset.dtype == "int64")

proc assert_data(dset: var H5DataSet) =
  # read all data
  let read = dset[int]
  for i in 0 ..< data.len:
    # compare read data with
    # 1. written data
    doAssert read[i] == data[i]
    # 2. reading by single element
    let val = dset[i, int]
    doAssert read[i] == val
  # compare some elements read individually
  doAssert read[0 .. 2] == dset[@[0, 1, 2], int]
  doAssert @[read[0], read[3], read[8]] == dset[@[0, 3, 8], int]

when isMainModule:
  # open file, create dataset
  var
    h5f = H5Open(File, "rw")
    dset = h5f.create_dset(DsetName)
    dset2 = h5f.create_dset("/foo/" & Dset2Name)
  # perform 1st checks on still open file
  dset.assert_fields()
  dset2.assert_fields()

  dset.assert_data()
  dset2.assert_fields()

  var err = h5f.close()
  doAssert(err >= 0)

  # reopen and read from group directly
  h5f = H5Open(File, "r")
  let grp = h5f["/foo".grp_str]

  # check that giving full path is `KeyError`
  try:
    discard grp[("/foo" & Dset2Name).dset_str]
    doAssert false
  except KeyError:
    doAssert true

  # access with relative dset works
  dset2 = grp[Dset2Name.dset_str]

  dset2.assert_fields()
  dset2.assert_data()

  err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
