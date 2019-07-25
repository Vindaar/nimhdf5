import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/group/dset"
var d_ar = @[ @[1, 2, 3, 4, 5],
              @[6, 7, 8, 9, 10] ]


proc create_dset(h5f: var H5FileObj): H5DataSet =
  result = h5f.create_dataset(DsetName, (2, 5), int)
  result[result.all] = d_ar

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")
    dset = h5f.create_dset()

  # now read data as a different data type
  template assertType(t: untyped): untyped =
    let dConvert = dset.readAs(t).reshape([2, 5])
    doAssert type(dConvert[0][0]) is t
    for i, a in d_ar:
      for j, b in d_ar:
        doAssert t(d_ar[i][j]) == dConvert[i][j]
    # now via `h5f` instead of `dset`
    let dFromFile = h5f.readAs(DsetName, t).reshape([2, 5])
    doAssert dConvert == dFromFile

    # now the same for a subset
    let dIdxs = dset.readAs(@[0, 1], t)
    # NOTE: indices due to broadcastingg of indices given to `readAs`
    doAssert dIdxs[0] == t(d_ar[0][0])
    doAssert dIdxs[1] == t(d_ar[1][1])

  assertType(int8)
  assertType(int16)
  assertType(int32)
  assertType(int64)
  assertType(uint8)
  assertType(uint16)
  assertType(uint32)
  assertType(uint64)
  assertType(float32)
  assertType(float64)

  var err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
