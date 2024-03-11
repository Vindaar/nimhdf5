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
  SeqStrAttr = @["foo", "bar"]
  TupAttr = (1.1, 2)
  NamedTupAttr = (foo: 5.5, bar: 12)
  ## WARNING: Trying to read a dataset / group with an attribute like the following
  ## crashes `hdfview`, at least as of version `3.3.0`!
  NamedTupStrAttr = (foo: "hello", bar: 12.5)
  NamedTupSeqComplexAttr = @[(foo: "hello", bar: 12.5), (foo: "World", bar: 48.2)]
  NumAttr = 8

proc write_attrs(grp: var H5Group) =

  # # now write some attributes
  grp.attrs["Time"] = TimeStr
  grp.attrs["Counter"] = Counter
  grp.attrs["Seq"] = SeqAttr
  grp.attrs["SeqStr"] = SeqStrAttr
  grp.attrs["Tuple"] = TupAttr
  grp.attrs["NamedTuple"] = NamedTupAttr
  grp.attrs["ComplexNamedTuple"] = NamedTupStrAttr
  grp.attrs["ComplexNamedSeqTuple"] = NamedTupSeqComplexAttr

proc assert_attrs(grp: var H5Group) =
  template readAndCheck(arg, typ, exp): untyped =
    let data = grp.attrs[arg, typ]
    echo "Read: ", data
    doAssert data == exp, "Mismatch, was = " & $data & ", but expected = " & $exp

  readAndCheck("Time", string, TimeStr)
  readAndCheck("Counter", int, Counter)
  readAndCheck("Seq", seq[int], SeqAttr)
  readAndCheck("SeqStr", seq[string], SeqStrAttr)
  readAndCheck("Tuple", (float, int), TupAttr)
  readAndCheck("NamedTuple", tuple[foo: float, bar: int], NamedTupAttr)
  readAndCheck("ComplexNamedTuple", tuple[foo: string, bar: float], NamedTupStrAttr)
  readAndCheck("ComplexNamedSeqTuple", seq[tuple[foo: string, bar: float]], NamedTupSeqComplexAttr)

  doAssert("Time" in grp.attrs)
  doAssert("NoTime" notin grp.attrs)
  let nameCheck = if grp.attrs.parent_name == formatName(GrpName) or
                     grp.attrs.parent_name == formatName(GrpCopy):
                    true
                  else:
                    false
  doAssert(nameCheck)
  doAssert(grp.attrs.parent_type == "H5Group")
  when defined(linux):
    doAssert(grp.attrs.num_attrs == NumAttr)
  # on Windows the file is not fully flushed etc at this point yet!

proc assert_delete(grp: var H5Group) =
  var AttrNumber = NumAttr
  template removeCheck(arg, num): untyped =
   doAssert(grp.deleteAttribute(arg))
   dec AttrNumber
   when defined(linux): # on Windows the file is not fully flushed etc at this point yet!
     doAssert(grp.attrs.num_attrs == AttrNumber)
  removeCheck("Time", AttrNumber)
  removeCheck("Counter", AttrNumber)
  removeCheck("Seq", AttrNumber)
  removeCheck("SeqStr", AttrNumber)
  removeCheck("Tuple", AttrNumber)
  removeCheck("NamedTuple", AttrNumber)
  removeCheck("ComplexNamedTuple", AttrNumber)
  removeCheck("ComplexNamedSeqTuple", AttrNumber)

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

import options, json
proc main() =
  var
    h5f = H5open(File, "rw")
    grp = h5f.create_group(GrpName)
    grpCp = h5f.create_group(GrpCopy)
    err: herr_t

  grp.write_attrs
  grp.assert_attrs

  ## Just see that also reading `dkObject` types works!
  for typ, attr in attrsJson(grp.attrs, withType = true):
    echo typ, " = ", attr.pretty()

  # copy attributes of grp to grpCp
  grpCp.copy_attributes(grp.attrs)
  # Alternatively can copy the whole group:
  #echo h5f.copy(grp, some(GrpCopy))
  #var grpCp = h5f[GrpCopy.grp_str]
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
  #
  grp.assert_overwrite

  err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)

when isMainModule:
  main()
