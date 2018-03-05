import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/group1/resize"

var d_ar = @[ @[1, 1, 1],
              @[1, 1, 1],
              @[1, 1, 1] ]

proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset(DsetName, (3, 3), int, chunksize = @[3, 3], maxshape = @[9, 9])
  result[result.all] = d_ar

proc assert_fields(h5f: var H5FileObj, dset: var H5DataSet, resized: bool) =
  if resized == false:
    assert(dset.shape == @[3, 3])
  else:
    assert(dset.shape == @[9, 9])

  assert(dset.maxshape == @[9, 9])

  let dtypeCheck = if dset.dtype == "int" or dset.dtype == "int64": true else: false
  assert(dtypeCheck)
  
  # currently if we hand a float64 for a datatype, we end up with
  # akFloat after creation, but when reading it back we get a
  # akFloat64. The first is due to Nim defining float64
  # 1. as the default float type on a 64 bit machine 
  # 2. in case of float64 actually even more nuanced, in the sense
  #    that Nim defines float as an alias for float64
  let anyKindCheck = if dset.dtypeAnyKind == akInt or dset.dtypeAnyKind == akInt64: true else: false
  assert(anyKindCheck)

  assert(dset.parent == parentDir(DsetName))

  assert(dset.file == File)

proc assert_data(dset: var H5DataSet, resized: bool) =

  if resized == false:
    let data = dset[int]
    # now flatten the data we wrote to file
    # have to flatten since do not return the data in
    # the shape of the array we write, but rather as
    # a flattened array, i.e.
    # assert(data.shape == d_ar.shape)
    # would fail
    let d_arflat = d_ar.flatten
    for i in 0 ..< data.len:
      assert(data[i] == d_arflat[i])
  else:
    # else read a hyperslab of the data and check the
    # parts we wrote
    # using full_output to only get part we originally wrote and the
    # whole resized array
    let
      data_small = dset.read_hyperslab(int64, offset = @[0, 0], count = @[3, 3], full_output = false)
      data_full  = dset.read_hyperslab(int64, offset = @[0, 0], count = @[3, 3], full_output = true)
      # data we wrote in bottom right corner of dataset
      data_new   = dset.read_hyperslab(int64, offset = @[6, 6], count = @[3, 3], full_output = false)
      # flattened written array
      d_arflat = d_ar.flatten
    # compare small dataset and bottom right corner
    for i in 0 ..< data_small.len:
      assert(data_small[i] == d_arflat[i])
      # same as new
      assert(data_new[i] == d_arflat[i])
    # full dataset
    assert(data_full.len == foldl(dset.shape, a * b))
    # first element
    assert(data_full[0] == d_ar[0][0])
    # first element of second row
    assert(data_full[dset.shape[0]] == d_ar[1][0])

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset()
  # perform 1st checks on still open file
  h5f.assert_fields(dset, false)
  # now resize dataset
  dset.resize((9, 9))
  # write same dataset located in top left of 9x9 dset into bottom
  # right corner
  dset.write_hyperslab(d_ar, offset = @[6, 6], count = d_ar.shape)
  h5f.assert_fields(dset, true)
  # close and reopen
  var err = h5f.close()
  assert(err >= 0)
  var
    h5f_read = H5File(File, "r")
  # get same dset from before
  dset = h5f_read[DsetName.dset_str]
  # check if assertions still hold true (did we read correctly?)
  echo "Asserting fields of read data"
  h5f_read.assert_fields(dset, true)
  # now read actual data and compare with what we wrote to file
  dset.assert_data(true)
  
  err = h5f_read.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
