import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/toAdd"
  DsetName2 = "/toAdd2"

var d_ar = @[ @[1, 1, 1],
              @[1, 1, 1],
              @[1, 1, 1] ]

proc create_dset(h5f: var H5FileObj, name: string): H5DataSet =
  result = h5f.create_dataset(name, (3, 3), int, chunksize = @[3, 3], maxshape = @[int.high, 6])
  result[result.all] = d_ar

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset(DsetName)
    dset2 = h5f.create_dset(DsetName2)

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

  let err = h5f.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
