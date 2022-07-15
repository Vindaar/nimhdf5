import nimhdf5
import sequtils
import os

const
  File = "tests/dset.h5"
  DsetName = "/dset"
  Dset2Name = "dset2"
  DsetSliceWrite = "dset3"
const data = @[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

proc create_dset(h5f: var H5File, name: string): H5DataSet =
  result = h5f.create_dataset(name, 10, int)
  result[result.all] = data

proc writeSlice(h5f: var H5File): H5DataSet =
  ## write the dataset using slice writing
  result = h5f.create_dataset(DsetSliceWrite, 10, int)
  result.write(0 .. 2, data[0 .. 2])
  result[7 .. 9] = data[7 .. 9]
  result.write(3 .. 6, data[3 .. 6])

proc assert_fields(dset: H5DataSet) =
  assert(dset.shape == @[10])
  assert(dset.dtype == "int64")

proc checkData(read: seq[int]) =
  for i in 0 ..< data.len:
    # compare read data with
    doAssert read[i] == data[i]

proc readData1(dset: H5Dataset): seq[int] =
  # using `[]`
  result = dset[int]

proc readData2(dset: H5Dataset): seq[int] =
  # using regular `read`
  result = dset.read(int)

proc readData3(dset: H5Dataset): seq[int] =
  for i in 0 ..< data.len:
    # compare read data with
    result.add dset[i, int]

proc assert_data(dset: var H5DataSet) =
  # read all data
  let read1 = readData1(dset)
  checkData(read1)

  let read2 = readData2(dset)
  checkData(read2)

  let read3 = readData3(dset)
  checkData(read3)

  # compare some elements read individually
  doAssert read1[0 .. 2] == dset[@[0, 1, 2], int]
  doAssert @[read1[0], read1[3], read1[8]] == dset[@[0, 3, 8], int]

  # read some slices
  let readS1 = dset.read(0 .. 2, int)
  doAssert readS1 == data[0 .. 2]

  let readS2 = dset[2 .. 5, int]
  doAssert readS2 == data[2 .. 5]

when isMainModule:
  # open file, create dataset
  var
    h5f = H5Open(File, "rw")
    dset = h5f.create_dset(DsetName)
    dset2 = h5f.create_dset("/foo/" & Dset2Name)
    dset3 = h5f.writeSlice()
  # perform 1st checks on still open file
  dset.assert_fields()
  dset2.assert_fields()
  dset3.assert_fields()

  dset.assert_data()
  dset2.assert_data()
  dset3.assert_data()

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

  dset3 = h5f[DsetSliceWrite.dset_str]
  dset3.assert_fields()
  dset3.assert_data()

  err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
