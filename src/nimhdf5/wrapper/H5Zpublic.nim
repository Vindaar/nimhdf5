##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
##  Copyright by The HDF Group.                                               *
##  Copyright by the Board of Trustees of the University of Illinois.         *
##  All rights reserved.                                                      *
##                                                                            *
##  This file is part of HDF5.  The full HDF5 copyright notice, including     *
##  terms governing use, modification, and redistribution, is contained in    *
##  the COPYING file, which can be found at the root of the source code       *
##  distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.  *
##  If you do not have access to either file, you may request a copy from     *
##  help@hdfgroup.org.                                                        *
##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

{.deadCodeElim: on.}

##  Programmer:  Robb Matzke <matzke@llnl.gov>
##               Thursday, April 16, 1998
##

##  Public headers needed by this file

import
  H5public, ../H5nimtypes

when not declared(libname):
  when defined(Windows):
    const
      libname* = "hdf5.dll"
  elif defined(MacOSX):
    const
      libname* = "libhdf5.dylib"
  else:
    const
      libname* = "libhdf5.so"

##
##  Filter identifiers.  Values 0 through 255 are for filters defined by the
##  HDF5 library.  Values 256 through 511 are available for testing new
##  filters. Subsequent values should be obtained from the HDF5 development
##  team at hdf5dev@ncsa.uiuc.edu.  These values will never change because they
##  appear in the HDF5 files.
##

type
  H5Z_filter_t* = cint

##  Filter IDs

const
  H5Z_FILTER_ERROR* = (- 1)      ## no filter
  H5Z_FILTER_NONE* = 0
  H5Z_FILTER_DEFLATE* = 1
  H5Z_FILTER_SHUFFLE* = 2
  H5Z_FILTER_FLETCHER32* = 3
  H5Z_FILTER_SZIP* = 4
  H5Z_FILTER_NBIT* = 5
  H5Z_FILTER_SCALEOFFSET* = 6
  H5Z_FILTER_RESERVED* = 256
  H5Z_FILTER_MAX* = 65535

##  General macros

const
  H5Z_FILTER_ALL* = 0
  H5Z_MAX_NFILTERS* = 32

##  (should probably be allowed to be an
##  unlimited amount, but currently each
##  filter uses a bit in a 32-bit field,
##  so the format would have to be
##  changed to accomodate that)
##
##  Flags for filter definition (stored)

const
  H5Z_FLAG_DEFMASK* = 0x000000FF
  H5Z_FLAG_MANDATORY* = 0x00000000
  H5Z_FLAG_OPTIONAL* = 0x00000001

##  Additional flags for filter invocation (not stored)

const
  H5Z_FLAG_INVMASK* = 0x0000FF00
  H5Z_FLAG_REVERSE* = 0x00000100
  H5Z_FLAG_SKIP_EDC* = 0x00000200

##  Special parameters for szip compression
##  [These are aliases for the similar definitions in szlib.h, which we can't
##  include directly due to the duplication of various symbols with the zlib.h
##  header file]

const
  H5_SZIP_ALLOW_K13_OPTION_MASK* = 1
  H5_SZIP_CHIP_OPTION_MASK* = 2
  H5_SZIP_EC_OPTION_MASK* = 4
  H5_SZIP_NN_OPTION_MASK* = 32
  H5_SZIP_MAX_PIXELS_PER_BLOCK* = 32

##  Macros for the shuffle filter

const
  H5Z_SHUFFLE_USER_NPARMS* = 0
  H5Z_SHUFFLE_TOTAL_NPARMS* = 1

##  Macros for the szip filter

const
  H5Z_SZIP_USER_NPARMS* = 2
  H5Z_SZIP_TOTAL_NPARMS* = 4
  H5Z_SZIP_PARM_MASK* = 0
  H5Z_SZIP_PARM_PPB* = 1
  H5Z_SZIP_PARM_BPP* = 2
  H5Z_SZIP_PARM_PPS* = 3

##  Macros for the nbit filter

const
  H5Z_NBIT_USER_NPARMS* = 0

##  Macros for the scale offset filter

const
  H5Z_SCALEOFFSET_USER_NPARMS* = 2

##  Special parameters for ScaleOffset filter

const
  H5Z_SO_INT_MINBITS_DEFAULT* = 0

type
  H5Z_SO_scale_type_t* {.size: sizeof(cint).} = enum
    H5Z_SO_FLOAT_DSCALE = 0, H5Z_SO_FLOAT_ESCALE = 1, H5Z_SO_INT = 2


##  Current version of the H5Z_class_t struct

const
  H5Z_CLASS_T_VERS* = (1)

##  Values to decide if EDC is enabled for reading data

type
  H5Z_EDC_t* {.size: sizeof(cint).} = enum
    H5Z_ERROR_EDC = - 1,         ##  error value
    H5Z_DISABLE_EDC = 0, H5Z_ENABLE_EDC = 1, H5Z_NO_EDC = 2


##  Bit flags for H5Zget_filter_info

const
  H5Z_FILTER_CONFIG_ENCODE_ENABLED* = (0x00000001)
  H5Z_FILTER_CONFIG_DECODE_ENABLED* = (0x00000002)

##  Return values for filter callback function

type
  H5Z_cb_return_t* {.size: sizeof(cint).} = enum
    H5Z_CB_ERROR = - 1, H5Z_CB_FAIL = 0, ##  I/O should fail if filter fails.
    H5Z_CB_CONT = 1,            ##  I/O continues if filter fails.
    H5Z_CB_NO = 2


##  Filter callback function definition

type
  H5Z_filter_func_t* = proc (filter: H5Z_filter_t; buf: pointer; buf_size: csize;
                          op_data: pointer): H5Z_cb_return_t {.cdecl.}

##  Structure for filter callback property

type
  H5Z_cb_t* = object
    `func`*: H5Z_filter_func_t
    op_data*: pointer

##
##  Before a dataset gets created, the "can_apply" callbacks for any filters used
##  in the dataset creation property list are called
##  with the dataset's dataset creation property list, the dataset's datatype and
##  a dataspace describing a chunk (for chunked dataset storage).
##
##  The "can_apply" callback must determine if the combination of the dataset
##  creation property list setting, the datatype and the dataspace represent a
##  valid combination to apply this filter to.  For example, some cases of
##  invalid combinations may involve the filter not operating correctly on
##  certain datatypes (or certain datatype sizes), or certain sizes of the chunk
##  dataspace.
##
##  The "can_apply" callback can be the NULL pointer, in which case, the library
##  will assume that it can apply to any combination of dataset creation
##  property list values, datatypes and dataspaces.
##
##  The "can_apply" callback returns positive a valid combination, zero for an
##  invalid combination and negative for an error.
##

type
  H5Z_can_apply_func_t* = proc (dcpl_id: hid_t; type_id: hid_t; space_id: hid_t): htri_t {.
      cdecl.}

##
##  After the "can_apply" callbacks are checked for new datasets, the "set_local"
##  callbacks for any filters used in the dataset creation property list are
##  called.  These callbacks receive the dataset's private copy of the dataset
##  creation property list passed in to H5Dcreate (i.e. not the actual property
##  list passed in to H5Dcreate) and the datatype ID passed in to H5Dcreate
##  (which is not copied and should not be modified) and a dataspace describing
##  the chunk (for chunked dataset storage) (which should also not be modified).
##
##  The "set_local" callback must set any parameters that are specific to this
##  dataset, based on the combination of the dataset creation property list
##  values, the datatype and the dataspace.  For example, some filters perform
##  different actions based on different datatypes (or datatype sizes) or
##  different number of dimensions or dataspace sizes.
##
##  The "set_local" callback can be the NULL pointer, in which case, the library
##  will assume that there are no dataset-specific settings for this filter.
##
##  The "set_local" callback must return non-negative on success and negative
##  for an error.
##

type
  H5Z_set_local_func_t* = proc (dcpl_id: hid_t; type_id: hid_t; space_id: hid_t): herr_t {.
      cdecl.}

##
##  A filter gets definition flags and invocation flags (defined above), the
##  client data array and size defined when the filter was added to the
##  pipeline, the size in bytes of the data on which to operate, and pointers
##  to a buffer and its allocated size.
##
##  The filter should store the result in the supplied buffer if possible,
##  otherwise it can allocate a new buffer, freeing the original.  The
##  allocated size of the new buffer should be returned through the BUF_SIZE
##  pointer and the new buffer through the BUF pointer.
##
##  The return value from the filter is the number of bytes in the output
##  buffer. If an error occurs then the function should return zero and leave
##  all pointer arguments unchanged.
##

type
  H5Z_func_t* = proc (flags: cuint; cd_nelmts: csize; cd_values: ptr cuint; nbytes: csize;
                   buf_size: ptr csize; buf: ptr pointer): csize {.cdecl.}

##
##  The filter table maps filter identification numbers to structs that
##  contain a pointers to the filter function and timing statistics.
##

type
  H5Z_class2_t* = object
    version*: cint             ##  Version number of the H5Z_class_t struct
    id*: H5Z_filter_t          ##  Filter ID number
    encoder_present*: cuint    ##  Does this filter have an encoder?
    decoder_present*: cuint    ##  Does this filter have a decoder?
    name*: cstring             ##  Comment for debugging
    can_apply*: H5Z_can_apply_func_t ##  The "can apply" callback for a filter
    set_local*: H5Z_set_local_func_t ##  The "set local" callback for a filter
    filter*: H5Z_func_t        ##  The actual filter function


proc H5Zregister*(cls: ptr H5Z_class2_t): herr_t {.cdecl, importc: "H5Zregister",
                                                   dynlib: libname.}

proc H5Zunregister*(id: H5Z_filter_t): herr_t {.cdecl, importc: "H5Zunregister",
    dynlib: libname.}
proc H5Zfilter_avail*(id: H5Z_filter_t): htri_t {.cdecl, importc: "H5Zfilter_avail",
    dynlib: libname.}
proc H5Zget_filter_info*(filter: H5Z_filter_t; filter_config_flags: ptr cuint): herr_t {.
    cdecl, importc: "H5Zget_filter_info", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##
  ##  The filter table maps filter identification numbers to structs that
  ##  contain a pointers to the filter function and timing statistics.
  ##
  type
    H5Z_class1_t* = object
      id*: H5Z_filter_t        ##  Filter ID number
      name*: cstring           ##  Comment for debugging
      can_apply*: H5Z_can_apply_func_t ##  The "can apply" callback for a filter
      set_local*: H5Z_set_local_func_t ##  The "set local" callback for a filter
      filter*: H5Z_func_t      ##  The actual filter function
