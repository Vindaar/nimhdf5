import nimhdf5, seqmath, os

const
  File = "tests/tCompound.h5"
  Dset = "DComp"
  DsetTup = "DCompTup"
  DsetAnTup = "DCompAnTup"

type
  Comp = object
    a: float
    c: float32 ## having float32 here tests that Nim's alignment is correctly taken care of
               ## (another 4 byte after the float32)
    b: int

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

import typetraits
when isMainModule:
  var data = newSeq[Comp](10)
  var dataTup = newSeq[Tup](10)
  var dataAnTup = newSeq[(float, float32, int)](10) ## anonymous tuple to check we get correct alignment for these
  for i in 0 ..< 10:
    let x = Comp(a: i.float * 1.1, b: i, c: i.float32 / 1.111'f32)
    #echo sizeof(x)
    data[i] = x
    let y = (i.float * 1.1, i.float32 / 1.111'f32, i)
    dataAnTup[i] = y
    #echo sizeof(y)
    #echo sizeof(y[0]), " addr ", cast[uint](addr(y[0]))
    #echo sizeof(y[1]), " addr ", cast[uint](addr(y[1]))
    #echo sizeof(y[2]), " addr ", cast[uint](addr(y[2]))
    dataTup[i] = (d: i.float * 2.5, e: i * 2, f: i * 3)


  var h5f = H5open(File, "rw")

  h5f.write_dataset(data, Dset)
  h5f.write_dataset(dataTup, DsetTup)
  h5f.write_dataset(dataAnTup, DsetAnTup)
  h5f.assert_dataset(data, Dset)
  h5f.assert_dataset(dataTup, DsetTup)
  h5f.assert_dataset(dataAnTup, DsetAnTup)

  var err = h5f.close()
  assert err >= 0

  h5f = H5open(File, "r")
  h5f.assert_dataset(data, Dset)
  h5f.assert_dataset(dataTup, DsetTup)
  h5f.assert_dataset(dataAnTup, DsetAnTup)

  err = h5f.close()
  assert err >= 0

  removeFile(File)
