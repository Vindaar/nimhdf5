import sequtils, os, strformat

import nimhdf5/hdf5_wrapper
import nimhdf5

const Filename = "blosc.h5"
const dataShape = @[100, 100]
const chunkSize = @[20, 20]

when isMainModule:

  # first test whether we can register the blosc plugin
  var
    version: string
    date: string
  # TODO: put this into the set filter?
  let r = registerBlosc(version, date)
  assert H5Zfilter_avail(FILTER_BLOSC) == 1

  echo "Blosc version: ", version
  echo "Blosc date: ", date

  # create dataset to store with filter and read back
  var h5f = H5File(Filename, "rw")

  let filter =  H5Filter(kind: fkBlosc, bloscLevel: 4, doShuffle: false,
                         compressor: BloscCompressor.LZ4)

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

  discard h5f.close()

  # clean up again
  removeFile(Filename)
