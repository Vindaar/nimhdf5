import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/group1/dset"
var d_ar = @[ @[ @[1'f64, 2, 3, 4, 5],
                 @[6'f64, 7, 8, 9, 10] ],
              @[ @[1'f64, 2, 3, 4, 5],
                 @[6'f64, 7, 8, 9, 10] ] ]


proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset("/group1/dset", (2, 2, 5), float64)
  result[result.all] = d_ar

proc assert_fields(h5f: var H5FileObj, dset: var H5DataSet) =
  assert(dset.shape == @[2, 2, 5])

  # non resizable dataset means maxshape same as current shape
  assert(dset.maxshape == dset.shape)

  assert(dset.dtype == "float64")
  
  # currently if we hand a float64 for a datatype, we end up with
  # akFloat after creation, but when reading it back we get a
  # akFloat64. The first is due to Nim defining float64
  # 1. as the default float type on a 64 bit machine 
  # 2. in case of float64 actually even more nuanced, in the sense
  #    that Nim defines float as an alias for float64
  let anyKindCheck = if dset.dtypeAnyKind == akFloat or dset.dtypeAnyKind == akFloat64: true else: false
  assert(anyKindCheck)#dset.dtypeAnyKind == akFloat)

  assert(dset.parent == parentDir(DsetName))

  assert(dset.file == File)

proc assert_data(dset: var H5DataSet) =
  
  let data = dset[float64]

  # now flatten the data we wrote to file
  # have to flatten since do not return the data in
  # the shape of the array we write, but rather as
  # a flattened array, i.e.
  # assert(data.shape == d_ar.shape)
  # would fail
  let d_arflat = d_ar.flatten
  for i in 0 ..< data.len:
    assert(data[i] == d_arflat[i])

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset()
  # perform 1st checks on still open file
  h5f.assert_fields(dset)
  # close and reopen
  var err = h5f.close()
  assert(err >= 0)
  var
    h5f_read = H5File(File, "r")
  # get same dset from before
  dset = h5f_read[DsetName.dset_str]
  # check if assertions still hold true (did we read correctly?)
  h5f_read.assert_fields(dset)

  # now read actual data and compare with what we wrote to file
  dset.assert_data()
  
  err = h5f_read.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
