import nimhdf5
import sequtils
import os
import ospaths
import typeinfo

const
  File = "tests/dset.h5"
  DsetName1 = "chunked1"
  DsetName2 = "chunked2"
  DsetName3 = "chunked3"
  DsetName4 = "chunked4"
  DsetName5 = "chunked5"
  DsetName6 = "chunked6"
  DsetName7 = "chunked7"
  DsetName8 = "chunked8"


var d_ar = toSeq(0 ..< 81).reshape([9, 9])

template check(actions: untyped) =
  try:
    actions
    raise newException(Exception, "Regression in t17.nim!")
  except ValueError:
    discard

proc main =
  # open file, create dataset
  var
    h5f = H5open(File, "rw")

  var dset1 = h5f.create_dataset(DsetName2, (9, 9), int,
                                 chunksize = @[27, 27],
                                 maxshape = @[27, 27])
  # to be fixed; maxshape needs to be set to
  # max(dset.shape, chunksize)
  var dset2 = h5f.create_dataset(DsetName2, (9, 9), int,
                                 chunksize = @[27, 27],
                                 maxshape = @[])
  # not allowed
  check:
    var dset3 = h5f.create_dataset(DsetName3, (9, 9), int,
                                   chunksize = @[27, 27],
                                   maxshape = @[9, 9])
  # not allowed
  check:
    var dset4 = h5f.create_dataset(DsetName4, (9, 9), int,
                                   chunksize = @[27, 0],
                                   maxshape = @[27, 27])
  # not allowed
  check:
    var dset5 = h5f.create_dataset(DsetName5, (9, 9), int,
                                   chunksize = @[27, 27],
                                   maxshape = @[0, 27])

  # not allowed
  check:
    var dset6 = h5f.create_dataset(DsetName6, (9, 9), int,
                                   chunksize = @[],
                                   maxshape = @[27])
  # not allowed
  check:
    var dset7 = h5f.create_dataset(DsetName7, (9, 9), int,
                                   chunksize = @[],
                                   maxshape = @[3, 12])
  # allowed
  var dset8 = h5f.create_dataset(DsetName8, (9, 9), int,
                                 chunksize = @[],
                                 maxshape = @[9, 9])

  # now resize dataset
  var err = h5f.close()
  assert(err >= 0)

when isMainModule:
  main()
  # clean up after ourselves
  removeFile(File)
