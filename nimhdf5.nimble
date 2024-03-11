# Package

version       = "0.6.0"
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

proc callTest(fname: string) =
  if (NimMajor, NimMinor, NimPatch) >= (2, 0, 0):
    exec "nim c -r " & fname
  else: # for older Nim force usage of Orc!
    exec "nim c -r --mm:orc " & fname

template tests(): untyped {.dirty.} =
  callTest "tests/tbasic.nim"
  callTest "tests/tdset.nim"
  callTest "tests/tread_write1D.nim"
  callTest "tests/tgroups.nim"
  callTest "tests/tcopy.nim"
  callTest "tests/tattributes.nim"
  callTest "tests/tvlen_array.nim"
  callTest "tests/tempty_hyperslab.nim"
  callTest "tests/tresize.nim"
  callTest "tests/treshape.nim"
  callTest "tests/tutil.nim"
  callTest "tests/tnested.nim"
  callTest "tests/tfilter.nim"
  callTest "tests/toverwrite.nim"
  callTest "tests/tconvert.nim"
  callTest "tests/tdelete.nim"
  callTest "tests/tresize_by_add.nim"
  callTest "tests/tStringAttributes.nim"
  callTest "tests/tCompound.nim"
  callTest "tests/tCompoundWithBool.nim"
  callTest "tests/tCompoundWithVlenStr.nim"
  callTest "tests/tCompoundWithSeq.nim"
  callTest "tests/tContainsIterator.nim"
  callTest "tests/twrite_string.nim"
  # regression tests
  callTest "tests/tint64_dset.nim"
  callTest "tests/t17.nim"
  callTest "tests/tIntegerTypes.nim"
  if NimMajor >= 2:
    callTest "tests/tWithDset.nim"
  # at least run the high level examples to avoid regressions
  if fileExists("dset.h5"): # as a test, we need to get rid of the high level H5 output file
    rmFile("dset.h5")
  callTest "examples/h5_high_level_example.nim"

task test, "Runs all tests":
  tests()

task testCI, "Run all tests in CI, including serialization":
  # For the following we need to add a nimble task to install test dependencies
  tests()
  # and the serialization test requiring `datamancer`
  exec "nim c -r tests/tSerialize.nim"
