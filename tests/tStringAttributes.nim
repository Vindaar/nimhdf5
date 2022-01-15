import nimhdf5
import sequtils

import os
import sugar

const
  File = "tests/strAttrs.h5"
  SimpleStr = "21:19"
  StrSeq = @["A", "funny", "sequence", "ofee", "strings", "/ea", "4vle23"]

proc write_attrs(grp: H5Group) =
  # # now write some attributes
  grp.attrs["Simple"] = SimpleStr
  grp.attrs["Sequence"] = StrSeq

proc assert_attrs(grp: var H5Group) =
  assert(grp.attrs["Simple", string] == SimpleStr)
  let read = grp.attrs["Sequence", seq[string]]
  assert(read == StrSeq)
  assert("Simple" in grp.attrs)
  assert("Sequence" in grp.attrs)

when isMainModule:
  var
    h5f = H5open(File, "rw")

  var grp = h5f.create_group("/")
  grp.write_attrs()
  grp.assert_attrs

  var err = h5f.close()
  assert(err >= 0)

  h5f = H5open(File, "r")
  grp = h5f["/".grp_str]
  grp.assert_attrs

  err = h5f.close()
  assert(err >= 0)

  removeFile(File)
