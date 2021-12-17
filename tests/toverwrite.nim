import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName = "/group1/dset"
  DsetRootName = "/dset"
var d_ar = @[ @[1'f64, 2, 3, 4, 5],
              @[6'f64, 7, 8, 9, 10] ]
var d_new = @[ @[1'f64, 2, 3, 4, 5],
               @[6'f64, 7, 8, 9, 10],
               @[11'f64, 12, 13, 14] ]

when isMainModule:
  # open file, create dataset
  var
    h5f = H5File(File, "rw")

  template createAndOverwrite(path: string): untyped =
    var dset = h5f.create_dataset(path, (2, 5), float64)
    dset[dset.all] = d_ar
    doAssert dset.shape == @[2, 5]
    dset = h5f.create_dataset(path, (3, 5), float64, overwrite = true)
    dset[dset.all] = d_new
    doAssert dset.shape == @[3, 5]

    # check dataset still exists
    doAssert path in h5f
    discard h5f.delete(path)
    ## check it doesn't exist anymore
    doAssert (not (path in h5f))


  createAndOverwrite(DsetName)
  createAndOverwrite(DsetRootName)

  let err = h5f.close()
  doAssert(err >= 0)

  # clean up after ourselves
  removeFile(File)
