import nimhdf5
import sequtils
import unittest

const
  File = "tests/dset.h5"
  Dset = "data"
var data = @[1, 2, 3, 4]


when isMainModule:
  ## Simple test which checks whether `withH5` can be used without problems
  ## multiple times in the same scope. Previously this caused problems, because
  ## the body of the template was not inside of a block and we'd get
  ## "previously declared" errors. (Although I'm confused by that, since the
  ## template should be hygenic, no?)
  withH5(File, "rw"):
    discard h5f.write_dataset(Dset, data)
    let dataRead = h5f[Dset, int]
    check dataRead == data

  withH5(File, "r"):
    let dataRead = h5f[Dset, int]
    check dataRead == data

  # and for fun a third time
  withH5(File, "r"):
    let dataRead = h5f[Dset, int]
    check dataRead == data

  removeFile(File)
