# Package

version       = "0.2.8"
author        = "Sebastian Schmidt"
description   = "Bindings for the HDF5 data format C library"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["examples, c_headers"]
skipExt       = @["nim~"]

# Dependencies

requires "nim >= 0.18.0"
requires "arraymancer >= 0.3.0"

task test, "Runs all tests":
  exec "nim c -r tests/tbasic.nim"
  exec "nim c -r tests/tdset.nim"
  exec "nim c -r tests/tattributes.nim"
  exec "nim c -r tests/tvlen_array.nim"
  exec "nim c -r tests/tresize.nim"
  exec "nim c -r tests/treshape.nim"
  exec "nim c -r tests/tutil.nim"
  exec "nim c -r tests/tnested.nim"
