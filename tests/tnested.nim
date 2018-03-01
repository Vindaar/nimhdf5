import ospaths
import nimhdf5

const
  File = "dset.h5"
  GrpName = "/test/a/nested/group"

proc writeNestedGroup(h5f: var H5FileObj): H5Group =
  result = h5f.create_group(GrpName)

when isMainModule:

  var h5f = H5file(File, "rw")

  var g = writeNestedGroup(h5f)

  assert(g.name == GrpName)

  assert(g.parent == parentDir(GrpName))

  assert(g.file == File)

  let err = h5f.close()
  assert(err >= 0)
