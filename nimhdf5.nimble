# Package

version       = "0.2.0"
author        = "Sebastian Schmidt"
description   = "A wrapper for the HDF5 data format C library"
license       = "BSD"
srcDir        = "src"
skipDirs      = @["examples, c_headers"]
skipExt       = @["nim~"]

# Dependencies

requires "nim >= 0.17.2"
requires "arraymancer >= 0.2.0"

