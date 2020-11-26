# Package

version       = "0.3.11"
author        = "Sebastian Schmidt"
description   = "Bindings for the HDF5 data format C library"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["examples, c_headers"]
skipExt       = @["nim~"]

# Dependencies

requires "nim >= 1.0.0"
requires "https://github.com/vindaar/seqmath >= 0.1.12"

task test, "Runs all tests":
  exec "nim c -r tests/tbasic.nim"
  exec "nim c -r tests/tdset.nim"
  exec "nim c -r tests/tread1D.nim"
  exec "nim c -r tests/tattributes.nim"
  exec "nim c -r tests/tvlen_array.nim"
  exec "nim c -r tests/tempty_hyperslab.nim"
  exec "nim c -r tests/tresize.nim"
  exec "nim c -r tests/treshape.nim"
  exec "nim c -r tests/tutil.nim"
  exec "nim c -r tests/tnested.nim"
  exec "nim c -r tests/tfilter.nim"
  exec "nim c -r tests/toverwrite.nim"
  exec "nim c -r tests/tconvert.nim"
  exec "nim c -r tests/tdelete.nim"
  exec "nim c -r tests/tresize_by_add.nim"
  exec "nim c -r tests/tStringAttributes.nim"
  exec "nim c -r tests/tCompound.nim"
  # regression tests
  exec "nim c -r tests/tint64_dset.nim"
  exec "nim c -r tests/t17.nim"
  exec "nim c -r tests/tIntegerTypes.nim"
