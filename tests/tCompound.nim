import nimhdf5, seqmath, os

const
  File = "tests/tCompound.h5"
  Dset = "DComp"
  DsetTup = "DCompTup"

type
  Comp = object
    a: float
    b: int
    c: float32

  Tup = tuple
    d: float
    e: int
    f: int

proc write_dataset[T](h5f: H5File, data: seq[T], name: string) =
  var dset = h5f.create_dataset(name, 10, T)
  dset[dset.all] = data

proc assert_dataset[T](h5f: H5File, data: seq[T], name: string) =
  let dset = h5f[name.dset_str]
  let readData = dset[T]
  doAssert readData == data

when isMainModule:
  var data = newSeq[Comp](10)
  var dataTup = newSeq[Tup](10)
  for i in 0 ..< 10:
    data[i] = Comp(a: i.float * 1.1, b: i, c: i.float32 / 1.111)
    dataTup[i] = (d: i.float * 2.5, e: i * 2, f: i * 3)

  var h5f = H5File(File, "rw")

  h5f.write_dataset(data, Dset)
  h5f.write_dataset(dataTup, DsetTup)
  h5f.assert_dataset(data, Dset)
  h5f.assert_dataset(dataTup, DsetTup)

  var err = h5f.close()
  assert err >= 0

  h5f = H5File(File, "r")
  h5f.assert_dataset(data, Dset)
  h5f.assert_dataset(dataTup, DsetTup)

  err = h5f.close()
  assert err >= 0

  removeFile(File)
