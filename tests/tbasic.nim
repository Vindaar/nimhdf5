import nimhdf5
import os

const FILE = "create_close.h5"

when isMainModule:

  var h5f = H5open(FILE, "rw")

  assert(h5f.name == FILE)

  let err = h5f.close()

  # unless closing did not work, should return >= 0
  assert(err >= 0)

  # clean up after ourselves
  removeFile(File)
