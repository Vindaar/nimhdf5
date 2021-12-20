import nimhdf5, os

const
  File = "tests/dset.h5"
  Grp1 = "/foo"
  Grp2 = "/bar"
  Grp3 = "/foo/bar"

when isMainModule:
  var h5f = H5File(File, "rw")

  # manually create group
  let grp1 = h5f.create_group(Grp1)
  doAssert grp1.name == Grp1
  doAssert Grp1 in h5f
  doAssert h5f.isGroup(Grp1)

  # check accessing non existant group using `[]` fails with `KeyError`
  try:
    let grp2 = h5f[Grp2.grp_str]
    doAssert false
  except KeyError:
    doAssert true

  # use `getOrCreateGroup` to create 2
  let grp2 = h5f.getOrCreateGroup(Grp2)
  doAssert grp2.name == Grp2
  doAssert Grp2 in h5f
  doAssert h5f.isGroup(Grp2)

  # create 3 manually and get it using same
  discard h5f.create_group(Grp3)
  let grp3 = h5f.getOrCreateGroup(Grp3)
  doAssert grp3.name == Grp3
  doAssert Grp3 in h5f
  doAssert h5f.isGroup(Grp3)

  let err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
