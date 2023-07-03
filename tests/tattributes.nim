import nimhdf5
import ospaths
import os

const
  File = "tests/attrs.h5"
  GrpName = "group1"
  # group to which we copy attributes
  GrpCopy = "groupCopy"
  TimeStr = "21:19"
  Counter = 128
  SeqAttr = @[1, 2, 3, 4]

proc write_attrs(grp: var H5Group) =

  # # now write some attributes
  grp.attrs["Time"] = TimeStr
  grp.attrs["Counter"] = Counter
  grp.attrs["Seq"] = SeqAttr

proc assert_attrs(grp: var H5Group) =

  doAssert(grp.attrs["Time", string] == TimeStr)
  doAssert(grp.attrs["Counter", int] == Counter)
  doAssert(grp.attrs["Seq", seq[int]] == SeqAttr)
  doAssert("Time" in grp.attrs)
  doAssert("NoTime" notin grp.attrs)
  let nameCheck = if grp.attrs.parent_name == formatName(GrpName) or
                     grp.attrs.parent_name == formatName(GrpCopy):
                    true
                  else:
                    false
  doAssert(nameCheck)
  doAssert(grp.attrs.parent_type == "H5Group")
  doAssert(grp.attrs.num_attrs == 3)

proc assert_delete(grp: var H5Group) =

  doAssert(grp.deleteAttribute("Time"))
  doAssert(grp.attrs.num_attrs == 2)
  doAssert(grp.deleteAttribute("Counter"))
  doAssert(grp.attrs.num_attrs == 1)
  doAssert(grp.deleteAttribute("Seq"))
  doAssert(grp.attrs.num_attrs == 0)

proc assert_overwrite(grp: var H5Group) =
  var mcounter = Counter

  # grp.file_ref[].printOpenObjects()
  # var ids = getOpenObjectIds(grp.file_ref[], okAttr)
  # for id in ids:
  #   let openN = getAttrName(id)
  #   echo id.close(okAttr), " was ", openN

  grp.attrs["Counter"] = mcounter
  doAssert(grp.attrs["Counter", int] == mcounter)
  inc mcounter

  # ids = getOpenObjectIds(grp.file_ref[], okAttr)
  # for id in ids:
  #   let openN = getAttrName(id)
  #   echo id.close(okAttr), " was ", openN
  # grp.file_ref[].printOpenObjects()

  grp.attrs["Counter"] = mcounter
  doAssert(grp.attrs["Counter", int] == mcounter)
  inc mcounter
  grp.attrs["Counter"] = mcounter
  doAssert(grp.attrs["Counter", int] == mcounter)

proc main() =
  var
    h5f = H5open(File, "rw")
    grp = h5f.create_group(GrpName)
    grpCp = h5f.create_group(GrpCopy)
    err: herr_t

  grp.write_attrs
  grp.assert_attrs


  # copy attributes of grp to grpCp
  grpCp.copy_attributes(grp.attrs)
  # now simply assert these attributes in the same way
  grpCp.assert_attrs

  err = h5f.close()
  doAssert(err >= 0)

  # open again, again with write access to delete attributes again
  h5f = H5open(File, "rw")
  grp = h5f[GrpName.grp_str]
  grpCp = h5f[GrpCopy.grp_str]
  # and check again
  grp.assert_attrs
  grpCp.assert_attrs

  # delete an attribute
  grp.assert_delete
  grpCp.assert_delete

  grp.assert_overwrite

  err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)

when isMainModule:
  main()
