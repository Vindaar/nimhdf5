import nimhdf5
import sequtils
import os
import ospaths

# simple test case used to test the usage of int64 as a type used for
# `create_dataset`, which currently clashes with the definition of `hid_t`
# which is simply an alias for int64

const
  File = "tests/dset_int64.h5"
  DsetName = "/group1/dset"
var d_ar = @[ @[1'i64, 2, 3, 4, 5],
              @[6'i64, 7, 8, 9, 10] ]

proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset("/group1/dset", (2, 5), int64)
  result[result.all] = d_ar

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset()
  # perform 1st checks on still open file
  # close and reopen
  assert dset.dtypeAnyKind == dkInt64

  var err = h5f.close()
  assert(err >= 0)
  var
    h5f_read = H5File(File, "r")
  # get same dset from before
  dset = h5f_read[DsetName.dset_str]
  # check if assertions still hold true (did we read correctly?)
  assert dset.dtypeAnyKind == dkInt64

  err = h5f_read.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
