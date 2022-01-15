import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/toAdd"
  DsetName2 = "/toAdd2"
  DsetVlen = "/toAddVlen"

var d_ar = @[ @[1, 1, 1],
              @[1, 1, 1],
              @[1, 1, 1] ]
var vlenData = @[ @[1, 2],
                  @[3, 4, 5] ]

proc create_dset(h5f: var H5FileObj, name: string): H5DataSet =
  result = h5f.create_dataset(name, (3, 3), int, chunksize = @[3, 3], maxshape = @[int.high, 6])
  result[result.all] = d_ar

proc create_vlen(h5f: var H5FileObj, name: string): H5DataSet =
  let vlent = special_type(int)
  result = h5f.create_dataset(name, (2, 1), vlent, chunksize = @[2, 1], maxshape = @[4, 1])
  result[result.all] = vlenData

when isMainModule:
  # open file, create dataset
  var
    h5f = H5open(File, "rw")
    dset = h5f.create_dset(DsetName)
    dset2 = h5f.create_dset(DsetName2)
    dsetV = h5f.create_vlen(DsetVlen)

  dset.add d_ar
  doAssert dset.shape == @[6, 3]
  dset2.add(d_ar, axis = 1)
  doAssert dset2.shape == @[3, 6]
  # check that adding again to axis = 1 of dset2 will fail
  try:
    dset2.add(d_ar, axis = 1)
  except ImmutableDatasetError:
    discard
  doAssert dset2.shape == @[3, 6]

  # now check adding also works for variable length data
  doAssert dsetV.shape == @[2, 1]
  dsetV.add vlenData
  doAssert dsetV.shape == @[4, 1]
  try:
    dsetV.add vlenData
  except ImmutableDatasetError:
    discard
  doAssert dsetV.shape == @[4, 1]

  let err = h5f.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
