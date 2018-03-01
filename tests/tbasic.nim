
const FILE = "simple_objects.nim"

when isMainModule:

  var h5f = H5file(FILE, "rw")

  assert(h5f.name == FILE)

  let err = h5f.close()

  # unless closing did not work, should return >= 0
  assert(err >= 0)
  
