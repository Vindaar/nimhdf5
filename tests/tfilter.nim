## example script to test filtering of data in nimhdf5

import sequtils, strformat
import os

import nimhdf5
import nimhdf5/hdf5_wrapper

const Filename = "cmprss.h5"
const dataShape = @[100, 100]
const chunkSize = @[20, 20]

when isMainModule:

  var h5f = H5File(Filename, "rw")

  let filter =  H5Filter(kind: fkZlib, zlibLevel: 9)

  # SZIP compression needs to be available in the hdf5 library
  let filterSzip =  H5Filter(kind: fkSzip,
                             optionMask: SzipOptionMask.NearestNeighbor,
                             pixPerBlock: 16)

  var dset = h5f.create_dataset("compressed_data",
                                dataShape, int,
                                chunkSize,
                                dataShape,
                                filter)

  var write: seq[seq[int]] = newSeqOf2D[int](dataShape)
  for i in 0 ..< dataShape[0]:
    for j in 0 ..< dataShape[1]:
      write[i][j] = i + j
  dset[dset.all] = write

  discard h5f.close()

  # open file and read again
  h5f = H5file(Filename, "r")
  dset = h5f["compressed_data".dset_str]
  let read = dset[int64].reshape2D(dataShape)
  for i in 0 ..< dataShape[0]:
    for j in 0 ..< dataShape[1]:
      doAssert write[i][j] == read[i][j]

  removeFile(Filename)
