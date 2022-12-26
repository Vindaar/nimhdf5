import nimhdf5, sets, unittest, sets, strutils
from os import removeFile

const File = "tests/tContainsIterator.h5"
var expDsets = initHashSet[string]()
var expGroups = initHashSet[string]()
proc createDatasets(h5f: H5File) =
  var data = @[1,2,3]
  template createDset(path: untyped): untyped =
    let dset = h5f.create_dataset(path, shape = (data.len, 1), dtype = int)
    dset[dset.all] = data
    expDsets.incl(path)

  createDset("/data")
  createDset("/foo/data")
  createDset("/foo/bar/data")
  createDset("/foo/bar/data2")
  createDset("/foo/baz/data")
  createDset("/bar/data")
  createDset("/baz/data")
  createDset("/baz/data2")

  expGroups.incl "/foo"
  expGroups.incl "/foo/bar"
  expGroups.incl "/foo/baz"
  expGroups.incl "/bar"
  expGroups.incl "/baz"

when isMainModule:
  var h5f = H5open(File, "w")
  h5f.createDatasets()

  block Groups:
    var resGroups = initHashSet[string]()
    for grp in items(h5f):
      resGroups.incl grp.name
      check grp.name in h5f
    check resGroups == expGroups

    resGroups.clear()

    for grp in items(h5f, depth = 2):
      resGroups.incl grp.name
      check grp.name in h5f
    check resGroups == expGroups

    resGroups.clear()

    # check count 1
    let expGroups1 = ["/foo", "/bar", "/baz"].toHashSet
    for grp in items(h5f, depth = 1):
      resGroups.incl grp.name
      check grp.name in h5f
    check resGroups == expGroups1

  block Datasets:
    let rootGrp = h5f["/".grp_str]
    var resDsets = initHashSet[string]()
    # all levels
    for dset in items(rootGrp, depth = -1):
      resDsets.incl dset.name
      check dset.name in h5f
      check dset.name in rootGrp
    check resDsets == expDsets

    resDsets.clear()
    for dset in items(rootGrp, depth = 2):
      resDsets.incl dset.name
      check dset.name in h5f
      check dset.name in rootGrp

    check resDsets == expDsets

    # depth 1 (incl. one level below root group)
    resDsets.clear()
    let expDsets1 = ["/data", "/foo/data", "/bar/data", "/baz/data", "/baz/data2"].toHashSet
    for dset in items(rootGrp, depth = 1):
      resDsets.incl dset.name
      check dset.name in h5f
      check dset.name in rootGrp
    check resDsets == expDsets1

    # default is depth 1
    resDsets.clear()
    for dset in items(rootGrp):
      resDsets.incl dset.name
      check dset.name in h5f
      check dset.name in rootGrp
    check resDsets == expDsets1

    # depth 0 (same level as / in root group)
    resDsets.clear()
    let expDsets0 = ["/data"].toHashSet
    for dset in items(rootGrp, depth = 0):
      resDsets.incl dset.name
      check dset.name in h5f
      check dset.name in rootGrp
    check resDsets == expDsets0


  block NotIn:
    let rootGrp = h5f["/".grp_str]
    check "foobarbaz" notin h5f
    check "foobarbaz" notin rootGrp
    check "foo/bar/baz/bug" notin h5f
    check "foo/bar/baz/bug" notin rootGrp
    check "data" in h5f # insensitive to `/` as there is a data in the root
    check "foo/data" in h5f
    check "data" in rootGrp # insensitive to `/` as there is a data in the root
    check "foo/data" in rootGrp

  let err = h5f.close()
  assert err >= 0

  removeFile(File)
