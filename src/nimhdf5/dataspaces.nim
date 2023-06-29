#[
This file contains all procedures related to dataspaces.

HDF5 separates the data in a HDF5 file into `datasets`, which are (potentially)
written to disk. However, reading and writing happens via `dataspaces`. In order
to read / write from / to a dataset, dataspaces are needed. A dataspace can
either represent the location of (parts of) data within a dataset on disk, or
provide space in RAM for that data.

If only parts of a large dataset is to be read for instance, a selection of
N elements is done (e.g. as a hyperslab) for the the dataspace describing the
data on disk. A dataspace in memory providing space for these N elements needs
to be provided in which the data is to be stored.
]#

import std / [sequtils, strutils]

import hdf5_wrapper
import H5nimtypes
import util
import datatypes

proc set_chunk*(papl_id: DatasetCreatePropertyListID, chunksize: seq[int]): hid_t =
  ## proc to set chunksize of the given object, should be a dataset,
  ## but we do not perform checks!
  var mchunksize = mapIt(chunksize, hsize_t(it))
  # convert return value of H5Pset_chunk to `hid_t`, because H5 wrapper returns `herr_t`
  result = H5Pset_chunk(papl_id.hid_t, cint(len(mchunksize)), addr(mchunksize[0])).hid_t

proc parseMaxShape(maxshape: seq[int]): seq[hsize_t] =
  ## this proc parses the maxshape given to simple_dataspace by taking into
  ## account the following rules:
  ## @[] -> nil (meaning H5Screate_simple will interpret as same dimension as shape)
  ## per dimension:
  ## `int.high` -> H5S_UNLIMITED
  if maxshape.len == 0:
    result = @[]
  else:
    result = mapIt(maxshape, if it == int.high: H5S_UNLIMITED else: hsize_t(it))

func simple_dataspace*[T: (seq | int)](shape: T, maxshape: seq[int] = @[]): DataspaceID =
  ## create a simple dataspace with max dimension == current_dimension
  ## TODO: rewrite this
  var m_maxshape: seq[hsize_t] = parseMaxShape(maxshape)
  withDebug:
    echo "Creating memory dataspace of shape ", shape
  when T is seq:
    # convert ints to hsize_t (== culonglong) and create mutable copy (need
    # an address to hand it to C function as pointer)
    var mshape = mapIt(shape, hsize_t(it))
    if m_maxshape.len > 0:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), addr(m_maxshape[0])).toDataspaceID()
    else:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), nil).toDataspaceID()
  elif T is int:
    # in this case 1D
    var mshape = hsize_t(shape)
    # maxshape is still a sequence, so take `0` element as address
    if m_maxshape.len > 0:
      H5Screate_simple(cint(1), addr(mshape), addr(m_maxshape[0])).toDataspaceID()
    else:
      H5Screate_simple(cint(1), addr(mshape), nil).toDataspaceID()

func simple_memspace*[T: (seq | int)](shape: T, maxshape: seq[int] = @[]): MemspaceID =
  ## The `HDF5` library does not differentiate between a memspace and a dataspace it seems.
  result = simple_dataspace(shape, maxshape).toMemspaceID()

proc create_simple_memspace_1d*[T](coord: seq[T]): MemspaceID {.inline.} =
  ## TODO: apply naming convention camelCase (internal proc)
  ## convenience proc to create a simple 1D memory space for N coordinates
  ## in memory
  # get enough space for the N coordinates in coord
  result = simple_dataspace(coord.len).toMemspaceID()

proc string_dataspace*[T: seq[string] | string](str: T, dtype: DatatypeID): DataspaceID =
  ## returns a dataspace of size 1 for a string of length N, by
  ## changing the size of the datatype given
  # need at least a minimum size of 1 for a HDF5 string to store
  # the null terminator
  when T is string:
    let dspaceLen = max(str.len, 1)
    discard H5Tset_size(dtype.id, dspaceLen.csize_t)
    # append null termination
    discard H5Tset_strpad(dtype.id, H5T_STR_NULLTERM)
    # now return dataspace of size 1
    result = simple_dataspace(1)
  else:
    # set type to be variable length string
    discard H5Tset_size(dtype.id, H5T_VARIABLE)
    # and create dataspace for each element in the string sequence
    result = simple_dataspace(str.len)

proc getNumberOfDims*(dspace_id: DataspaceID): int =
  ## Return the number of dimensions of a simple (contiguous) dataspace
  result = H5Sget_simple_extent_ndims(dspace_id.id).int

proc getNumberOfPoints*(dspace_id: DataspaceID): int =
  ## Return the number of elements in the given (1D?) dataspace
  result = H5Sget_simple_extent_npoints(dspace_id.id).int

proc getSizeOfDims*(dspace_id: DataspaceID): tuple[shape: seq[int],
                                                   maxshape: seq[int]] =
  ## Return the sizes of all dimensions of a simple (contiguous) dataspace
  ##
  ## Output:
  ##   tuple[shape, maxshape: seq[int]] = a tuple of a seq containing the
  ##     size of each dimension (shape) and a seq containing the maximum allowed
  ##     size of each dimension (maxshape).
  let ndims = getNumberOfDims(dspace_id)
  # given ndims, create a seq in which to store the dimensions of the dataset
  var
    shape = newSeq[hsize_t](ndims)
    maxshape = newSeq[hsize_t](ndims)
  let sdims = H5Sget_simple_extent_dims(dspace_id.id,
                                        addr(shape[0]),
                                        addr(maxshape[0]))
  # now replace max shape values == `H5S_UNLIMITED` by `int.high`
  maxshape = maxshape.mapIt(
    if it == H5S_UNLIMITED: # == -1
      hsize_t(int.high)
    else:
      hsize_t(it))
  if sdims < 0 or sdims != ndims:
    raise newException(HDF5LibraryError,
                       "Call to HDF5 library failed in `getSizeOfDims` " &
                       "after a call to `H5Sget_simple_extent_dims` with return code " &
                       "$#" % $sdims)
  result = (mapIt(shape, int(it)), mapIt(maxshape, int(it)))
