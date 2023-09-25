# Package

version       = "0.5.9"
author        = "Sebastian Schmidt"
description   = "Bindings for the HDF5 data format C library"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["examples, c_headers"]
skipExt       = @["nim~"]

# Dependencies

requires "nim >= 1.6.0"
requires "https://github.com/vindaar/seqmath >= 0.1.17"
# for blosc support install:
# requires "nblosc >= 1.15.0"

task testDeps, "Install dependencies for tests":
  exec "nimble install -y datamancer"

template tests(): untyped {.dirty.} =
  exec "nim c -r tests/tbasic.nim"
  exec "nim c -r tests/tdset.nim"
  exec "nim c -r tests/tread_write1D.nim"
  exec "nim c -r tests/tgroups.nim"
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
  exec "nim c -r tests/tCompoundWithBool.nim"
  exec "nim c -r tests/tCompoundWithVlenStr.nim"
  exec "nim c -r tests/tCompoundWithSeq.nim"
  exec "nim c -r tests/tContainsIterator.nim"
  exec "nim c -r tests/twrite_string.nim"
  # regression tests
  exec "nim c -r tests/tint64_dset.nim"
  exec "nim c -r tests/t17.nim"
  exec "nim c -r tests/tIntegerTypes.nim"
  exec "nim c -r tests/tWithDset.nim"
  # at least run the high level examples to avoid regressions
  if fileExists("dset.h5"): # as a test, we need to get rid of the high level H5 output file
    rmFile("dset.h5")
  exec "nim c -r examples/h5_high_level_example.nim"

task test, "Runs all tests":
  tests()

task testCI, "Run all tests in CI, including serialization":
  # For the following we need to add a nimble task to install test dependencies
  tests()
  # and the serialization test requiring `datamancer`
  exec "nim c -r tests/tSerialize.nim"
