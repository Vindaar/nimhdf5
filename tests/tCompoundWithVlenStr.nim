import nimhdf5, seqmath, os, tables

import nimhdf5 / type_utils # for convertToCstring

const
  File = "tests/tCompoundWithVlenStr.h5"
  Dset = "DComp"
  DsetTup = "DCompTup"

const CacheTabFileName = "cacheTab_effective_eff_test.h5"
let CacheTabFile = getTempDir() / CacheTabFileName
type
  TabKey = (string, string, float)
  #         ^-- calibration filename
  #                 ^-- sha1 hash of the NN model `.pt` file
  #                         ^-- target efficiency
  TabVal = (float, float)
  #         ^-- mean of effective effs
  #                ^-- σ of effective effs
  CacheTabTyp = Table[TabKey, TabVal]

type
  Comp = object
    a: float
    b: int
    c: float32
    s: string
    x: Tup

  Tup = tuple
    d: float
    e: int
    f: int
    t: string

const Size = 10

proc write_dataset[T](h5f: H5File, data: seq[T], name: string) =
  var dset = h5f.create_dataset(name, Size, T)
  #if name == "dt3":
  dset[dset.all] = data

proc assert_dataset[T](h5f: H5File, data: seq[T], name: string) =
  let dset = h5f[name.dset_str]
  let readData = dset[T]
  doAssert readData == data

when isMainModule:
  var data = newSeq[Comp](Size)
  var dataTup = newSeq[Tup](Size)
  for i in 0 ..< Size:
    let tup = (d: i.float * 2.5, e: i * 2, f: i * 3, t: "World")
    data[i] = Comp(a: i.float * 1.1, b: i, c: i.float32 / 1.111, s: "Hello", x: tup)
    dataTup[i] = tup

  #echo "SIZEOF CZM ", sizeof(Comp)
  #let sasa = data[0]
  #for f, v in fieldPairs(sasa):
  #  echo "Size of ", f, " = ", sizeof(v)
  var h5f = H5open(File, "rw")


  #let dt3 = data.convertToCstring() # <- this is irrelevant now
  #echo "DT3!!! ", dt3
  #h5f.write_dataset(dt3, "dt3")
  #echo "NOW PART 2\n\n"
  h5f.write_dataset(data, Dset)

  h5f.write_dataset(dataTup, DsetTup)
  h5f.assert_dataset(data, Dset)
  h5f.assert_dataset(dataTup, DsetTup)



  ### XXX: make me a test!
  #var cacheTab = initTable[TabKey, TabVal](1)
  #for i in 0 ..< 6:
  #  cacheTab[("Calib.h5", "D73DENGNE483848ENRERNE", 0.1 * i.float)] = (0.91243, 0.03)
  #echo "serializing:: "
  #for k, v in cacheTab:
  #  echo k, " of ", v
  #cacheTab.toH5(CacheTabFile)
  #
  #cacheTab = deserializeH5[CacheTabTyp](CacheTabFile)
  #
  #echo "ater deserializing:: "
  #for k, v in cacheTab:
  #  echo k, " of ", v
  #
  #
  #var err = h5f.close()
  #assert err >= 0
  #
  #h5f = H5open(File, "r")
  #h5f.assert_dataset(data, Dset)
  #h5f.assert_dataset(dataTup, DsetTup)
  #
  #err = h5f.close()
  #assert err >= 0

  #removeFile(File)
