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
##
##  This file contains public declarations for the H5D module.
##

##  System headers needed by this file
##  Public headers needed by this file

import
  H5public, H5Ipublic, ../H5nimtypes, ../h5libname




## ***************
##  Public Macros
## ***************
##  Macros used to "unset" chunk cache configuration parameters

const
  H5D_CHUNK_CACHE_NSLOTS_DEFAULT* = (-1.csize)
  H5D_CHUNK_CACHE_NBYTES_DEFAULT* = (-1.csize)
  H5D_CHUNK_CACHE_W0_DEFAULT* = (- 1.0)

##  Bit flags for the H5Pset_chunk_opts() and H5Pget_chunk_opts()

const
  H5D_CHUNK_DONT_FILTER_PARTIAL_CHUNKS* = (0x00000002)

##  Property names for H5LTDdirect_chunk_write

const
  H5D_XFER_DIRECT_CHUNK_WRITE_FLAG_NAME* = "direct_chunk_flag"
  H5D_XFER_DIRECT_CHUNK_WRITE_FILTERS_NAME* = "direct_chunk_filters"
  H5D_XFER_DIRECT_CHUNK_WRITE_OFFSET_NAME* = "direct_chunk_offset"
  H5D_XFER_DIRECT_CHUNK_WRITE_DATASIZE_NAME* = "direct_chunk_datasize"

## *****************
##  Public Typedefs
## *****************
##  Values for the H5D_LAYOUT property

type
  H5D_layout_t* {.size: sizeof(cint).} = enum
    H5D_LAYOUT_ERROR = - 1, H5D_COMPACT = 0, ## raw data is very small
    H5D_CONTIGUOUS = 1,         ## the default
    H5D_CHUNKED = 2,            ## slow and fancy
    H5D_VIRTUAL = 3,            ## actual data is stored in other datasets
    H5D_NLAYOUTS = 4


##  Types of chunk index data structures

type
  H5D_chunk_index_t* {.size: sizeof(cint).} = enum
    H5D_CHUNK_IDX_BTREE = 0,    ##  v1 B-tree index (default)
    H5D_CHUNK_IDX_SINGLE = 1,   ##  Single Chunk index (cur dims[]=max dims[]=chunk dims[]; filtered & non-filtered)
    H5D_CHUNK_IDX_NONE = 2,     ##  Implicit: No Index (H5D_ALLOC_TIME_EARLY, non-filtered, fixed dims)
    H5D_CHUNK_IDX_FARRAY = 3,   ##  Fixed array (for 0 unlimited dims)
    H5D_CHUNK_IDX_EARRAY = 4,   ##  Extensible array (for 1 unlimited dim)
    H5D_CHUNK_IDX_BT2 = 5,      ##  v2 B-tree index (for >1 unlimited dims)
    H5D_CHUNK_IDX_NTYPES      ##  This one must be last!


##  Values for the space allocation time property

type
  H5D_alloc_time_t* {.size: sizeof(cint).} = enum
    H5D_ALLOC_TIME_ERROR = - 1, H5D_ALLOC_TIME_DEFAULT = 0, H5D_ALLOC_TIME_EARLY = 1,
    H5D_ALLOC_TIME_LATE = 2, H5D_ALLOC_TIME_INCR = 3


##  Values for the status of space allocation

type
  H5D_space_status_t* {.size: sizeof(cint).} = enum
    H5D_SPACE_STATUS_ERROR = - 1, H5D_SPACE_STATUS_NOT_ALLOCATED = 0,
    H5D_SPACE_STATUS_PART_ALLOCATED = 1, H5D_SPACE_STATUS_ALLOCATED = 2


##  Values for time of writing fill value property

type
  H5D_fill_time_t* {.size: sizeof(cint).} = enum
    H5D_FILL_TIME_ERROR = - 1, H5D_FILL_TIME_ALLOC = 0, H5D_FILL_TIME_NEVER = 1,
    H5D_FILL_TIME_IFSET = 2


##  Values for fill value status

type
  H5D_fill_value_t* {.size: sizeof(cint).} = enum
    H5D_FILL_VALUE_ERROR = - 1, H5D_FILL_VALUE_UNDEFINED = 0,
    H5D_FILL_VALUE_DEFAULT = 1, H5D_FILL_VALUE_USER_DEFINED = 2


##  Values for VDS bounds option

type
  H5D_vds_view_t* {.size: sizeof(cint).} = enum
    H5D_VDS_ERROR = - 1, H5D_VDS_FIRST_MISSING = 0, H5D_VDS_LAST_AVAILABLE = 1


##  Callback for H5Pset_append_flush() in a dataset access property list

type
  H5D_append_cb_t* = proc (dataset_id: hid_t; cur_dims: ptr hsize_t; op_data: pointer): herr_t {.
      cdecl.}

## ******************
##  Public Variables
## ******************
## *******************
##  Public Prototypes
## *******************

##  Define the operator function pointer for H5Diterate()

type
  H5D_operator_t* = proc (elem: pointer; type_id: hid_t; ndim: cuint; point: ptr hsize_t;
                       operator_data: pointer): herr_t {.cdecl.}

##  Define the operator function pointer for H5Dscatter()

type
  H5D_scatter_func_t* = proc (src_buf: ptr pointer; ## out
                           src_buf_bytes_used: ptr csize; ## out
                           op_data: pointer): herr_t {.cdecl.}

##  Define the operator function pointer for H5Dgather()

type
  H5D_gather_func_t* = proc (dst_buf: pointer; dst_buf_bytes_used: csize;
                          op_data: pointer): herr_t {.cdecl.}

proc H5Dcreate2*(loc_id: hid_t; name: cstring; type_id: hid_t; space_id: hid_t;
                lcpl_id: hid_t; dcpl_id: hid_t; dapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Dcreate2", dynlib: libname.}
proc H5Dcreate_anon*(file_id: hid_t; type_id: hid_t; space_id: hid_t; plist_id: hid_t;
                    dapl_id: hid_t): hid_t {.cdecl, importc: "H5Dcreate_anon",
    dynlib: libname.}
proc H5Dopen2*(file_id: hid_t; name: cstring; dapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Dopen2", dynlib: libname.}
proc H5Dclose*(dset_id: hid_t): herr_t {.cdecl, importc: "H5Dclose", dynlib: libname.}
proc H5Dget_space*(dset_id: hid_t): hid_t {.cdecl, importc: "H5Dget_space",
                                        dynlib: libname.}
proc H5Dget_space_status*(dset_id: hid_t; allocation: ptr H5D_space_status_t): herr_t {.
    cdecl, importc: "H5Dget_space_status", dynlib: libname.}
proc H5Dget_type*(dset_id: hid_t): hid_t {.cdecl, importc: "H5Dget_type",
                                       dynlib: libname.}
proc H5Dget_create_plist*(dset_id: hid_t): hid_t {.cdecl,
    importc: "H5Dget_create_plist", dynlib: libname.}
proc H5Dget_access_plist*(dset_id: hid_t): hid_t {.cdecl,
    importc: "H5Dget_access_plist", dynlib: libname.}
proc H5Dget_storage_size*(dset_id: hid_t): hsize_t {.cdecl,
    importc: "H5Dget_storage_size", dynlib: libname.}
proc H5Dget_offset*(dset_id: hid_t): haddr_t {.cdecl, importc: "H5Dget_offset",
    dynlib: libname.}
proc H5Dread*(dset_id: hid_t; mem_type_id: hid_t; mem_space_id: hid_t;
             file_space_id: hid_t; plist_id: hid_t; buf: pointer): herr_t {.cdecl,
    importc: "H5Dread", dynlib: libname.}
  ## out
proc H5Dwrite*(dset_id: hid_t; mem_type_id: hid_t; mem_space_id: hid_t;
              file_space_id: hid_t; plist_id: hid_t; buf: pointer): herr_t {.cdecl,
    importc: "H5Dwrite", dynlib: libname.}
proc H5Diterate*(buf: pointer; type_id: hid_t; space_id: hid_t; op: H5D_operator_t;
                operator_data: pointer): herr_t {.cdecl, importc: "H5Diterate",
    dynlib: libname.}
proc H5Dvlen_reclaim*(type_id: hid_t; space_id: hid_t; plist_id: hid_t; buf: pointer): herr_t {.
    cdecl, importc: "H5Dvlen_reclaim", dynlib: libname.}
proc H5Dvlen_get_buf_size*(dataset_id: hid_t; type_id: hid_t; space_id: hid_t;
                          size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Dvlen_get_buf_size", dynlib: libname.}
proc H5Dfill*(fill: pointer; fill_type: hid_t; buf: pointer; buf_type: hid_t;
             space: hid_t): herr_t {.cdecl, importc: "H5Dfill", dynlib: libname.}
proc H5Dset_extent*(dset_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Dset_extent", dynlib: libname.}
proc H5Dflush*(dset_id: hid_t): herr_t {.cdecl, importc: "H5Dflush", dynlib: libname.}
proc H5Drefresh*(dset_id: hid_t): herr_t {.cdecl, importc: "H5Drefresh",
                                       dynlib: libname.}
proc H5Dscatter*(op: H5D_scatter_func_t; op_data: pointer; type_id: hid_t;
                dst_space_id: hid_t; dst_buf: pointer): herr_t {.cdecl,
    importc: "H5Dscatter", dynlib: libname.}
proc H5Dgather*(src_space_id: hid_t; src_buf: pointer; type_id: hid_t;
               dst_buf_size: csize; dst_buf: pointer; op: H5D_gather_func_t;
               op_data: pointer): herr_t {.cdecl, importc: "H5Dgather",
                                        dynlib: libname.}
proc H5Ddebug*(dset_id: hid_t): herr_t {.cdecl, importc: "H5Ddebug", dynlib: libname.}
##  Internal API routines

proc H5Dformat_convert*(dset_id: hid_t): herr_t {.cdecl,
    importc: "H5Dformat_convert", dynlib: libname.}
proc H5Dget_chunk_index_type*(did: hid_t; idx_type: ptr H5D_chunk_index_t): herr_t {.
    cdecl, importc: "H5Dget_chunk_index_type", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  const
    H5D_CHUNK_BTREE* = H5D_CHUNK_IDX_BTREE
  ##  Typedefs
  ##  Function prototypes
  proc H5Dcreate1*(file_id: hid_t; name: cstring; type_id: hid_t; space_id: hid_t;
                  dcpl_id: hid_t): hid_t {.cdecl, importc: "H5Dcreate1",
                                        dynlib: libname.}
  proc H5Dopen1*(file_id: hid_t; name: cstring): hid_t {.cdecl, importc: "H5Dopen1",
      dynlib: libname.}
  proc H5Dextend*(dset_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
      importc: "H5Dextend", dynlib: libname.}
