import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/group1/emptyHyperslab"

var d_ar = @[ @[1, 1, 1],
              @[1, 1, 1],
              @[1, 1, 1] ]

proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset(DsetName, (3, 3), int)
  result[result.all] = d_ar

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset()

  # write empty hyperslab
  var emptyData: seq[int] = @[]
  dset.write_hyperslab(emptyData, offset = @[0, 0], count = @[0, 0])
  # clean up after ourselves
  removeFile(File)
