import nimhdf5
import sequtils
import os
import ospaths
import typeinfo
import strformat
import algorithm
import typetraits

const
  File = "tests/treshape.h5"
  Dset2D = "/group1/reshape2D"
  Dset3D = "/group1/reshape3D"  

var d2d = @[ @[1, 1, 1],
             @[1, 1, 1],
             @[1, 1, 1] ]
var d3d = @[ @[ @[1, 2, 3, 4, 5],
                @[6, 7, 8, 9, 10]],
             @[ @[1, 2, 3, 4, 5],
                @[6, 7, 8, 9, 10]]]

proc create_dset(h5f: var H5FileObj): (H5DataSet, H5DataSet) =
  var
    d1 = h5f.create_dataset(Dset2D, (3, 3), int)
    d2 = h5f.create_dataset(Dset3D, (2, 2, 5), int)  
  d1[d1.all] = d2d
  d2[d2.all] = d3d
  result = (d1, d2)

proc assert_data(dset: var H5DataSet, shape: seq[int]) =
  # assert the shape and file
  assert(dset.shape == shape)
  assert(dset.file == File)

  # get the dataset
  let data = dset[int64]
  # now reshape the read back data and compare that
  if dset.shape.len == 2:
    let data_reshaped = data.reshape2D(dset.shape)
    let data_reshaped_alt = data.reshape([3, 3])
    assert data_reshaped.shape == d2d.shape
    assert data_reshaped_alt.shape == d2d.shape
    for i in 0 ..< dset.shape.len:
      let
        dfile = data_reshaped[i]
        dfile_alt = data_reshaped_alt[i]
        dwrite = d2d[i]
      for j in 0 ..< dwrite.len:
        assert dwrite[i] == dfile[i]
        assert dwrite[i] == dfile_alt[i]
  else:
    # for the 3D case
    let data_reshaped = data.reshape3D(dset.shape)
    let data_reshaped_alt = data.reshape([2, 2, 5])    
    assert data_reshaped.shape == d3d.shape
    assert data_reshaped_alt.shape == d3d.shape
    # in this case for convenience compare the flattened arrays
    let
      d_rflat1 = data_reshaped.flatten
      d_rflat2 = data_reshaped_alt.flatten
      d3d_flat = d3d.flatten
    for i in 0 ..< d3d_flat.len:
      assert d3d_flat[i] == d_rflat1[i]
      assert d3d_flat[i] == d_rflat2[i]

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    (dset2d, dset3d) = h5f.create_dset()
  # perform 1st checks on still open file
  assert_data(dset2d, @[3, 3])
  assert_data(dset3d, @[2, 2, 5])
  # close and reopen
  var err = h5f.close()
  assert(err >= 0)
  var
    h5f_read = H5File(File, "r")
  # get same dset from before
  dset2d = h5f_read[Dset2D.dset_str]
  dset3d = h5f_read[Dset3D.dset_str]  
  # check if assertions still hold true (did we read correctly?)
  echo "Asserting fields of read data"
  # now read actual data and compare with what we wrote to file
  assert_data(dset2d, @[3, 3])
  assert_data(dset3d, @[2, 2, 5])  
  
  err = h5f_read.close()
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
