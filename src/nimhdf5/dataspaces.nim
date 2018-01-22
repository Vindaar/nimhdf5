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

import sequtils
import future

import hdf5_wrapper
import H5nimtypes
import util
#import datatypes

proc set_chunk*(papl_id: hid_t, chunksize: seq[int]): hid_t =
  # proc to set chunksize of the given object, should be a dataset,
  # but we do not perform checks!
  var mchunksize = mapIt(chunksize, hsize_t(it))
  result = H5Pset_chunk(papl_id, cint(len(mchunksize)), addr(mchunksize[0]))

proc parseMaxShape(maxshape: seq[int]): seq[hsize_t] =
  # this proc parses the maxshape given to simple_dataspace by taking into
  # account the following rules:
  # @[] -> nil (meaning H5Screate_simple will interpret as same dimension as shape)
  # per dimension:
  # `int.high` -> H5S_UNLIMITED
  if maxshape.len == 0:
    result = nil
  else:
    result = mapIt(maxshape, if it == int.high: H5S_UNLIMITED else: hsize_t(it))
  

template simple_dataspace*[T: (seq | int)](shape: T, maxshape: seq[int] = @[]): hid_t =
  # create a simple dataspace with max dimension == current_dimension
  # TODO: rewrite this
  var m_maxshape: seq[hsize_t] = parseMaxShape(maxshape)
  withDebug:
    echo "Creating memory dataspace of shape ", shape
  when T is seq:
    # convert ints to hsize_t (== culonglong) and create mutable copy (need
    # an address to hand it to C function as pointer)
    var mshape = mapIt(shape, hsize_t(it))
    if m_maxshape.len > 0:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), addr(m_maxshape[0]))
    else:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), nil)
  elif T is int:
    # in this case 1D
    var mshape = hsize_t(shape)
    # maxshape is still a sequence, so take `0` element as address
    if m_maxshape.len > 0:
      H5Screate_simple(cint(1), addr(mshape), addr(m_maxshape[0]))
    else:
      H5Screate_simple(cint(1), addr(mshape), nil)

proc create_simple_memspace_1d*[T](coord: seq[T]): hid_t {.inline.} =
  ## convenience proc to create a simple 1D memory space for N coordinates
  ## in memory
  # get enough space for the N coordinates in coord
  result = simple_dataspace(coord.len)

proc string_dataspace*(str: string, dtype: hid_t): hid_t =
  # returns a dataspace of size 1 for a string of length N, by
  # changing the size of the datatype given
  discard H5Tset_size(dtype, len(str))
  # append null termination
  discard H5Tset_strpad(dtype, H5T_STR_NULLTERM)
  # now return dataspace of size 1
  result = simple_dataspace(1)

