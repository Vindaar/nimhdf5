import nimhdf5, tables
import sequtils
import os
import ospaths
import typeinfo
import options

const
  File1 = "tests/dset.h5"
  File2 = "tests/dsetCopy.h5"
  DsetName = "/group1/dset"
var data = @[1, 2, 3, 4]

proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset(DsetName, (4, 1), int64)
  result[result.all] = data
  # add an attribute
  result.attrs["Test"] = "String"

proc assert_data(dset: var H5DataSet) =
  let d = dset[int]
  doAssert(d == data)

proc assert_dset(h5f: var H5FileObj, dset: var H5DataSet, file: string) =
  doAssert(dset.shape == @[4, 1])
  doAssert(dset.parent == parentDir(DsetName))
  doAssert(dset.file == file, dset.file & " vs " & $file)
  doAssert(dset.attrs["Test", string] == "String")

proc assert_file1(h5f: var H5FileObj) =
  var
    dset: H5DataSet
    grp: H5Group
  grp = h5f["/group1".grp_str]
  dset = h5f[(grp.name / "dset").dset_str]
  h5f.assert_dset(dset, h5f.name)

  grp = h5f["/testGrp".grp_str]
  dset = h5f[(grp.name / "tdset").dset_str]
  h5f.assert_dset(dset, h5f.name)

  grp = h5f["/testGrp".grp_str]
  dset = h5f[(grp.name / "tdset2").dset_str]
  h5f.assert_dset(dset, h5f.name)

  dset = h5f[("/test").dset_str]
  h5f.assert_dset(dset, h5f.name)

proc assert_file2(h5f: var H5FileObj) =
  var
    dset: H5DataSet
    grp: H5Group
  grp = h5f["/group1".grp_str]
  dset = h5f[(grp.name / "dset").dset_str]
  h5f.assert_dset(dset, h5f.name)

  grp = h5f["/group1".grp_str]
  dset = h5f[(grp.name / "tdset2").dset_str]
  h5f.assert_dset(dset, h5f.name)

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File1, "rw")
    dset = create_dset(h5f)
  # perform 1st checks on still open file
  h5f.assert_dset(dset, File1)
  #h5f.flush
  #var err = h5f.close()
  #doAssert err >= 0
  #h5f = H5file(File1, "rw")
  #dset = h5f[DsetName.dset_str]

  # copy the dataset to file 2
  var h5out = H5File(File2, "rw")

  # copy dataset to another location in same file
  var success = h5f.copy(dset, target = some("/test"))
  doAssert success
  # try copying onto same dataset, see it fails
  success = h5f.copy(dset, target = some("/test"))
  doAssert(not success)
  # copy dataset to another non existing group (will create subgroup)
  success = h5f.copy(dset, target = some("/testGrp/tdset"))
  doAssert success
  # copy dataset to another existing group
  success = h5f.copy(dset, target = some("/testGrp/tdset2"))
  doAssert success
  # writing to same file without target fails with HDF5LibraryError
  try:
    discard h5f.copy(dset)
  except HDF5LibraryError:
    discard

  # copy dataset to same subgroup in a different file (which does
  # not exist in that file)
  success = h5f.copy(dset, h5out = some(h5out))
  doAssert success
  # copy dataset to same subgroup in a different file (which ``now does``
  # ``exist`` in that file)
  success = h5f.copy(dset, h5out = some(h5out), target = some("/group1/tdset2"))
  doAssert success
  # copy whole group with multiple datasets
  let multiGrp = h5out["/group1".grp_str]
  success = h5out.copy(multiGrp, target = some("/copyGroup"))
  doAssert success
  var err = h5f.close()
  doAssert err >= 0
  # get same dset from before now in other file
  dset = h5out[DsetName.dset_str]
  ## check if assertions still hold true (did we read correctly?)
  h5out.assert_dset(dset, File2)
  #
  ## now read actual data and compare with what we wrote to file
  dset.assert_data()
  #
  err = h5out.close()
  doAssert err >= 0

  # clean up after ourselves
  removeFile(File1)
  removeFile(File2)
