import sequtils
import hdf5_wrapper

import datatypes
import H5nimtypes

import blosc_filter

const SzipPixPerBlockSeq = toSeq(0'u8 .. 32'u8).filterIt(it mod 2 == 0)
const ZlibCompressionLevel = {0 .. 9}
# define allowed values for the Szip pixels per block (even values < 32)
var tempSet {.compileTime.}: set[uint8] = {}
static:
  for x in SzipPixPerBlockSeq:
    tempSet.incl x
const SzipPixPerBlockSet = tempSet

when HasBloscSupport:
  type
    BloscCompressor* {.pure.} = enum
      BloscLZ = BLOSC_BLOSCLZ
      LZ4 = BLOSC_LZ4
      LZ4HC = BLOSC_LZ4HC
      Snappy = BLOSC_SNAPPY
      Zlib = BLOSC_ZLIB
      Zstd = BLOSC_ZSTD

type
  H5FilterKind* = enum
    fkNone, fkSzip, fkZlib, fkBlosc

  SzipOptionMask* {.pure.} = enum
    EntropyCoding = H5_SZIP_EC_OPTION_MASK
    NearestNeighbor = H5_SZIP_NN_OPTION_MASK

  H5Filter* = object
    case kind*: H5FilterKind
    of fkSzip:
      optionMask*: SzipOptionMask
      pixPerBlock*: int
    of fkZlib:
      zlibLevel*: int
    of fkBlosc:
      when HasBloscSupport:
        bloscLevel*: int
        doShuffle*: bool
        compressor*: BloscCompressor
      else:
        discard
    of fkNone:
      # if no filter used, empty object
      discard

proc setFilters*(dset: H5DataSet, filter: H5Filter) =
  ## parses the given `filter` and sets the dataset creation property list
  ## accordingly
  ## raises:
  ##   HDF5LibraryError: if a call to a H5 lib function fails
  ##   ValueError:
  ##     - if a `pixPerBlock` field of an Szip filter is invalid
  ##       (uneven or larger 32)
  ##     - if `zlibLevel` notin {0 .. 9}
  var status: herr_t = 0

  case filter.kind
  of fkSzip:
    if filter.pixPerBlock.uint8 notin SzipPixPerBlockSet:
      raise newException(ValueError, "Invalid `pixPerBlock` value for SZip " &
        "compression. Valid values are even, positive integers <= 32")
    status = H5Pset_szip(dset.dcpl_id, filter.optionMask.cuint, filter.pixPerBlock.cuint)
  of fkZlib:
    if filter.zlibLevel notin ZlibCompressionLevel:
      raise newException(ValueError, "Invalid `zlibLevel` compression value Zlib " &
        "compression. Valid values are {0 .. 9}")
    status = H5Pset_deflate(dset.dcpl_id, filter.zlibLevel.cuint)
  of fkBlosc:
    # TODO: only
    when HasBloscSupport:
      var filterVals = newSeq[cuint](7)
      filterVals[4] = filter.bloscLevel.cuint
      filterVals[5] = if filter.doShuffle: 1 else: 0
      filterVals[6] = filter.compressor.cuint
      # set the filter
      status = H5Pset_filter(dset.dcpl_id, FILTER_BLOSC, H5Z_FLAG_OPTIONAL,
                             filterVals.len.csize_t, addr filterVals[0])
    else:
      raise newException(NotImplementedError, "Blosc support not available, due " &
        "to missing `nblosc` library!")
    # raise newException(NotImplementedError, "Blosc support not yet implemented!")
  of fkNone:
    discard

  if status < 0:
    raise newException(Hdf5LibraryError, "Call to hdf5 library failed in " &
      "`setFilters` trying to set " & $filter.kind & " filter.")
