import nimhdf5
import sequtils, tables
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName1 = "/group/dset"
  DsetName2 = "/group2/dset"
  DsetName3 = "/group3/dset"
var d_ar = @[ @[1, 2, 3, 4, 5],
              @[6, 7, 8, 9, 10] ]

proc create_dset(h5f: var H5FileObj, name: string): H5DataSet =
  result = h5f.create_dataset(name, (2, 5), int)
  result[result.all] = d_ar

when isMainModule:
  # open file, create dataset
  var
    h5f = H5open(File, "rw")
    dset1 = h5f.create_dset(DsetName1)
    dset2 = h5f.create_dset(DsetName2)
    dset3 = h5f.create_dset(DsetName3)

  # check groups and datasets exist
  doAssert "group" in h5f
  doAssert "group2" in h5f
  doAssert "group3" in h5f
  doAssert "group/dset" in h5f
  doAssert "group2/dset" in h5f
  doAssert "group3/dset" in h5f

  doAssert "/group" in h5f.groups
  doAssert "/group2" in h5f.groups
  doAssert "/group3" in h5f.groups
  doAssert "/group/dset" in h5f.datasets
  doAssert "/group2/dset" in h5f.datasets
  doAssert "/group3/dset" in h5f.datasets


  # now delete
  # first delete only dset then group
  doAssert h5f.delete("group/dset")
  doAssert "group/dset" notin h5f
  doAssert "/group/dset" notin h5f.datasets
  doAssert h5f.delete("group")
  doAssert "group" notin h5f
  doAssert "/group" notin h5f.groups

  # now delete group2 and its contents
  doAssert h5f.delete("group2")
  doAssert "group2" notin h5f
  doAssert "/group2" notin h5f.groups
  doAssert "group2/dset" notin h5f
  doAssert "/group2/dset" notin h5f.datasets

  # finally delete group3/dset from relative group3
  var grp3 = h5f["group3".grp_str]
  doAssert grp3.delete("dset")
  doAssert "group3/dset" notin h5f
  doAssert "/group3/dset" notin h5f.datasets
  doAssert "group3/dset" notin grp3
  doAssert "/group3/dset" notin grp3.datasets
  doAssert h5f.delete("group3")
  doAssert "group3" notin h5f
  doAssert "/group3" notin h5f.groups

  doAssert h5f.groups.len == 0
  doAssert h5f.datasets.len == 0

  var err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
