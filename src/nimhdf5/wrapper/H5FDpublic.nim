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
##  Programmer:  Robb Matzke <matzke@llnl.gov>
##               Monday, July 26, 1999
##

import
  H5public, H5Fpublic, ../H5nimtypes, ../h5libname



const                         ## for H5F_close_degree_t
  H5_HAVE_VFL* = 1
  H5FD_VFD_DEFAULT* = 0

##  Types of allocation requests: see H5Fpublic.h

type
  H5FD_mem_t* = H5F_mem_t


##  Map "fractal heap" header blocks to 'ohdr' type file memory, since its
##  a fair amount of work to add a new kind of file memory and they are similar
##  enough to object headers and probably too minor to deserve their own type.
##
##  Map "fractal heap" indirect blocks to 'ohdr' type file memory, since they
##  are similar to fractal heap header blocks.
##
##  Map "fractal heap" direct blocks to 'lheap' type file memory, since they
##  will be replacing local heaps.
##
##  Map "fractal heap" 'huge' objects to 'draw' type file memory, since they
##  represent large objects that are directly stored in the file.
##
##       -QAK
##

const
  H5FD_MEM_FHEAP_HDR* = H5FD_MEM_OHDR
  H5FD_MEM_FHEAP_IBLOCK* = H5FD_MEM_OHDR
  H5FD_MEM_FHEAP_DBLOCK* = H5FD_MEM_LHEAP
  H5FD_MEM_FHEAP_HUGE_OBJ* = H5FD_MEM_DRAW

##  Map "free space" header blocks to 'ohdr' type file memory, since its
##  a fair amount of work to add a new kind of file memory and they are similar
##  enough to object headers and probably too minor to deserve their own type.
##
##  Map "free space" serialized sections to 'lheap' type file memory, since they
##  are similar enough to local heap info.
##
##       -QAK
##

const
  H5FD_MEM_FSPACE_HDR* = H5FD_MEM_OHDR
  H5FD_MEM_FSPACE_SINFO* = H5FD_MEM_LHEAP

##  Map "shared object header message" master table to 'ohdr' type file memory,
##  since its a fair amount of work to add a new kind of file memory and they are
##  similar enough to object headers and probably too minor to deserve their own
##  type.
##
##  Map "shared object header message" indices to 'btree' type file memory,
##  since they are similar enough to B-tree nodes.
##
##       -QAK
##

const
  H5FD_MEM_SOHM_TABLE* = H5FD_MEM_OHDR
  H5FD_MEM_SOHM_INDEX* = H5FD_MEM_BTREE

##  Map "extensible array" header blocks to 'ohdr' type file memory, since its
##  a fair amount of work to add a new kind of file memory and they are similar
##  enough to object headers and probably too minor to deserve their own type.
##
##  Map "extensible array" index blocks to 'ohdr' type file memory, since they
##  are similar to extensible array header blocks.
##
##  Map "extensible array" super blocks to 'btree' type file memory, since they
##  are similar enough to B-tree nodes.
##
##  Map "extensible array" data blocks & pages to 'lheap' type file memory, since
##  they are similar enough to local heap info.
##
##       -QAK
##

const
  H5FD_MEM_EARRAY_HDR* = H5FD_MEM_OHDR
  H5FD_MEM_EARRAY_IBLOCK* = H5FD_MEM_OHDR
  H5FD_MEM_EARRAY_SBLOCK* = H5FD_MEM_BTREE
  H5FD_MEM_EARRAY_DBLOCK* = H5FD_MEM_LHEAP
  H5FD_MEM_EARRAY_DBLK_PAGE* = H5FD_MEM_LHEAP

##  Map "fixed array" header blocks to 'ohdr' type file memory, since its
##  a fair amount of work to add a new kind of file memory and they are similar
##  enough to object headers and probably too minor to deserve their own type.
##
##  Map "fixed array" data blocks & pages to 'lheap' type file memory, since
##  they are similar enough to local heap info.
##
##

const
  H5FD_MEM_FARRAY_HDR* = H5FD_MEM_OHDR
  H5FD_MEM_FARRAY_DBLOCK* = H5FD_MEM_LHEAP
  H5FD_MEM_FARRAY_DBLK_PAGE* = H5FD_MEM_LHEAP

##
##  A free-list map which maps all types of allocation requests to a single
##  free list.  This is useful for drivers that don't really care about
##  keeping different requests segregated in the underlying file and which
##  want to make most efficient reuse of freed memory.  The use of the
##  H5FD_MEM_SUPER free list is arbitrary.
##
##  #define H5FD_FLMAP_SINGLE {						      \
##      H5FD_MEM_SUPER,			/\*default*\/			      \
##      H5FD_MEM_SUPER,			/\*super*\/			      \
##      H5FD_MEM_SUPER,			/\*btree*\/			      \
##      H5FD_MEM_SUPER,			/\*draw*\/			      \
##      H5FD_MEM_SUPER,			/\*gheap*\/			      \
##      H5FD_MEM_SUPER,			/\*lheap*\/			      \
##      H5FD_MEM_SUPER			/\*ohdr*\/			      \
##  }
##  /\*
##   * A free-list map which segregates requests into `raw' or `meta' data
##   * pools.
##   *\/
##  #define H5FD_FLMAP_DICHOTOMY {						      \
##      H5FD_MEM_SUPER,			/\*default*\/			      \
##      H5FD_MEM_SUPER,			/\*super*\/			      \
##      H5FD_MEM_SUPER,			/\*btree*\/			      \
##      H5FD_MEM_DRAW,			/\*draw*\/			      \
##      H5FD_MEM_DRAW,			/\*gheap*\/			      \
##      H5FD_MEM_SUPER,			/\*lheap*\/			      \
##      H5FD_MEM_SUPER			/\*ohdr*\/			      \
##  }
##  /\*
##   * The default free list map which causes each request type to use it's own
##   * free-list.
##   *\/
##  #define H5FD_FLMAP_DEFAULT {						      \
##      H5FD_MEM_DEFAULT,			/\*default*\/			      \
##      H5FD_MEM_DEFAULT,			/\*super*\/			      \
##      H5FD_MEM_DEFAULT,			/\*btree*\/			      \
##      H5FD_MEM_DEFAULT,			/\*draw*\/			      \
##      H5FD_MEM_DEFAULT,			/\*gheap*\/			      \
##      H5FD_MEM_DEFAULT,			/\*lheap*\/			      \
##      H5FD_MEM_DEFAULT			/\*ohdr*\/			      \
##  }
##  Define VFL driver features that can be enabled on a per-driver basis
##  These are returned with the 'query' function pointer in H5FD_class_t
##
##  Defining H5FD_FEAT_AGGREGATE_METADATA for a VFL driver means that
##  the library will attempt to allocate a larger block for metadata and
##  then sub-allocate each metadata request from that larger block.
##

const
  H5FD_FEAT_AGGREGATE_METADATA* = 0x00000001

##
##  Defining H5FD_FEAT_ACCUMULATE_METADATA for a VFL driver means that
##  the library will attempt to cache metadata as it is written to the file
##  and build up a larger block of metadata to eventually pass to the VFL
##  'write' routine.
##
##  Distinguish between updating the metadata accumulator on writes and
##  reads.  This is particularly (perhaps only, even) important for MPI-I/O
##  where we guarantee that writes are collective, but reads may not be.
##  If we were to allow the metadata accumulator to be written during a
##  read operation, the application would hang.
##

const
  H5FD_FEAT_ACCUMULATE_METADATA_WRITE* = 0x00000002
  H5FD_FEAT_ACCUMULATE_METADATA_READ* = 0x00000004
  H5FD_FEAT_ACCUMULATE_METADATA* = (
    H5FD_FEAT_ACCUMULATE_METADATA_WRITE or H5FD_FEAT_ACCUMULATE_METADATA_READ)

##
##  Defining H5FD_FEAT_DATA_SIEVE for a VFL driver means that
##  the library will attempt to cache raw data as it is read from/written to
##  a file in a "data seive" buffer.  See Rajeev Thakur's papers:
##   http://www.mcs.anl.gov/~thakur/papers/romio-coll.ps.gz
##   http://www.mcs.anl.gov/~thakur/papers/mpio-high-perf.ps.gz
##

const
  H5FD_FEAT_DATA_SIEVE* = 0x00000008

##
##  Defining H5FD_FEAT_AGGREGATE_SMALLDATA for a VFL driver means that
##  the library will attempt to allocate a larger block for "small" raw data
##  and then sub-allocate "small" raw data requests from that larger block.
##

const
  H5FD_FEAT_AGGREGATE_SMALLDATA* = 0x00000010

##
##  Defining H5FD_FEAT_IGNORE_DRVRINFO for a VFL driver means that
##  the library will ignore the driver info that is encoded in the file
##  for the VFL driver.  (This will cause the driver info to be eliminated
##  from the file when it is flushed/closed, if the file is opened R/W).
##

const
  H5FD_FEAT_IGNORE_DRVRINFO* = 0x00000020

##
##  Defining the H5FD_FEAT_DIRTY_DRVRINFO_LOAD for a VFL driver means that
##  the library will mark the driver info dirty when the file is opened
##  R/W.  This will cause the driver info to be re-encoded when the file
##  is flushed/closed.
##

const
  H5FD_FEAT_DIRTY_DRVRINFO_LOAD* = 0x00000040

##
##  Defining H5FD_FEAT_POSIX_COMPAT_HANDLE for a VFL driver means that
##  the handle for the VFD (returned with the 'get_handle' callback) is
##  of type 'int' and is compatible with POSIX I/O calls.
##

const
  H5FD_FEAT_POSIX_COMPAT_HANDLE* = 0x00000080

##
##  Defining H5FD_FEAT_HAS_MPI for a VFL driver means that
##  the driver makes use of MPI communication and code may retrieve
##  communicator/rank information from it
##

const
  H5FD_FEAT_HAS_MPI* = 0x00000100

##
##  Defining the H5FD_FEAT_ALLOCATE_EARLY for a VFL driver will force
##  the library to use the H5D_ALLOC_TIME_EARLY on dataset create
##  instead of the default H5D_ALLOC_TIME_LATE
##

const
  H5FD_FEAT_ALLOCATE_EARLY* = 0x00000200

##
##  Defining H5FD_FEAT_ALLOW_FILE_IMAGE for a VFL driver means that
##  the driver is able to use a file image in the fapl as the initial
##  contents of a file.
##

const
  H5FD_FEAT_ALLOW_FILE_IMAGE* = 0x00000400

##
##  Defining H5FD_FEAT_CAN_USE_FILE_IMAGE_CALLBACKS for a VFL driver
##  means that the driver is able to use callbacks to make a copy of the
##  image to store in memory.
##

const
  H5FD_FEAT_CAN_USE_FILE_IMAGE_CALLBACKS* = 0x00000800

##
##  Defining H5FD_FEAT_SUPPORTS_SWMR_IO for a VFL driver means that the
##  driver supports the single-writer/multiple-readers I/O pattern.
##

const
  H5FD_FEAT_SUPPORTS_SWMR_IO* = 0x00001000

##
##  Defining H5FD_FEAT_USE_ALLOC_SIZE for a VFL driver
##  means that the library will just pass the allocation size to the
##  the driver's allocation callback which will eventually handle alignment.
##  This is specifically used for the multi/split driver.
##

const
  H5FD_FEAT_USE_ALLOC_SIZE* = 0x00002000

##
##  Defining H5FD_FEAT_PAGED_AGGR for a VFL driver
##  means that the driver needs special file space mapping for paged aggregation.
##  This is specifically used for the multi/split driver.
##

const
  H5FD_FEAT_PAGED_AGGR* = 0x00004000

##
##  The main datatype for each driver. Public fields common to all drivers
##  are declared here and the driver appends private fields in memory.
##

type
  H5FD_t_prot* = ref object of RootObj
    driver_id*: hid_t          ## driver ID for this file
    fileno*: culong            ##  File 'serial' number
    access_flags*: cuint       ##  File access flags (from create or open)
    feature_flags*: culong     ##  VFL Driver feature Flags
    maxaddr*: haddr_t          ##  For this file, overrides class
    base_addr*: haddr_t        ##  Base address for HDF5 data w/in file
                      ##  Space allocation management fields
    threshold*: hsize_t        ##  Threshold for alignment
    alignment*: hsize_t        ##  Allocation alignment
    paged_aggr*: hbool_t       ##  Paged aggregation for file space is enabled or not

##  Class information for each file driver

type
  H5FD_class_t* = object
    name*: cstring
    maxaddr*: haddr_t
    fc_degree*: H5F_close_degree_t
    terminate*: proc (): herr_t {.cdecl.}
    sb_size*: proc (file: ptr H5FD_t_prot): hsize_t {.cdecl.}
    sb_encode*: proc (file: ptr H5FD_t_prot; name: cstring; ## out
                      p: ptr char): herr_t {.cdecl.} ## out
    sb_decode*: proc (f: ptr H5FD_t_prot; name: cstring; p: ptr char): herr_t {.cdecl.}
    fapl_size*: csize_t
    fapl_get*: proc (file: ptr H5FD_t_prot): pointer {.cdecl.}
    fapl_copy*: proc (fapl: pointer): pointer {.cdecl.}
    fapl_free*: proc (fapl: pointer): herr_t {.cdecl.}
    dxpl_size*: csize_t
    dxpl_copy*: proc (dxpl: pointer): pointer {.cdecl.}
    dxpl_free*: proc (dxpl: pointer): herr_t {.cdecl.}
    open*: proc (name: cstring; flags: cuint; fapl: hid_t; maxaddr: haddr_t): ptr H5FD_t_prot {.
        cdecl.}
    close*: proc (file: ptr H5FD_t_prot): herr_t {.cdecl.}
    cmp*: proc (f1: ptr H5FD_t_prot; f2: ptr H5FD_t_prot): cint {.cdecl.}
    query*: proc (f1: ptr H5FD_t_prot; flags: ptr culong): herr_t {.cdecl.}
    get_type_map*: proc (file: ptr H5FD_t_prot; type_map: ptr H5FD_mem_t): herr_t {.cdecl.}
    alloc*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t; dxpl_id: hid_t; size: hsize_t): haddr_t {.
        cdecl.}
    free*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t; dxpl_id: hid_t; `addr`: haddr_t;
               size: hsize_t): herr_t {.cdecl.}
    get_eoa*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t): haddr_t {.cdecl.}
    set_eoa*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t; `addr`: haddr_t): herr_t {.cdecl.}
    get_eof*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t): haddr_t {.cdecl.}
    get_handle*: proc (file: ptr H5FD_t_prot; fapl: hid_t; file_handle: ptr pointer): herr_t {.
        cdecl.}
    read*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t; dxpl: hid_t; `addr`: haddr_t;
               size: csize_t; buffer: pointer): herr_t {.cdecl.}
    write*: proc (file: ptr H5FD_t_prot; `type`: H5FD_mem_t; dxpl: hid_t; `addr`: haddr_t;
                size: csize_t; buffer: pointer): herr_t {.cdecl.}
    flush*: proc (file: ptr H5FD_t_prot; dxpl_id: hid_t; closing: hbool_t): herr_t {.cdecl.}
    truncate*: proc (file: ptr H5FD_t_prot; dxpl_id: hid_t; closing: hbool_t): herr_t {.cdecl.}
    lock*: proc (file: ptr H5FD_t_prot; rw: hbool_t): herr_t {.cdecl.}
    unlock*: proc (file: ptr H5FD_t_prot): herr_t {.cdecl.}
    fl_map*: array[H5FD_MEM_NTYPES, H5FD_mem_t]


type
  H5FD_t* = ref object of H5FD_t_prot
    cls*: ptr H5FD_class_t      ## constant class info

##  A free list is a singly-linked list of address/size pairs.

type
  H5FD_free_t* = object
    `addr`*: haddr_t
    size*: hsize_t
    next*: ptr H5FD_free_t


##  Define enum for the source of file image callbacks

type
  H5FD_file_image_op_t* {.size: sizeof(cint).} = enum
    H5FD_FILE_IMAGE_OP_NO_OP, H5FD_FILE_IMAGE_OP_PROPERTY_LIST_SET,
    H5FD_FILE_IMAGE_OP_PROPERTY_LIST_COPY, H5FD_FILE_IMAGE_OP_PROPERTY_LIST_GET,
    H5FD_FILE_IMAGE_OP_PROPERTY_LIST_CLOSE, H5FD_FILE_IMAGE_OP_FILE_OPEN,
    H5FD_FILE_IMAGE_OP_FILE_RESIZE, H5FD_FILE_IMAGE_OP_FILE_CLOSE


##  Define structure to hold file image callbacks

type
  H5FD_file_image_callbacks_t* = object
    image_malloc*: proc (size: csize_t; file_image_op: H5FD_file_image_op_t;
                       udata: pointer): pointer {.cdecl.}
    image_memcpy*: proc (dest: pointer; src: pointer; size: csize_t;
                       file_image_op: H5FD_file_image_op_t; udata: pointer): pointer {.
        cdecl.}
    image_realloc*: proc (`ptr`: pointer; size: csize_t;
                        file_image_op: H5FD_file_image_op_t; udata: pointer): pointer {.
        cdecl.}
    image_free*: proc (`ptr`: pointer; file_image_op: H5FD_file_image_op_t;
                     udata: pointer): herr_t {.cdecl.}
    udata_copy*: proc (udata: pointer): pointer {.cdecl.}
    udata_free*: proc (udata: pointer): herr_t {.cdecl.}
    udata*: pointer


##  Function prototypes

proc H5FDregister*(cls: ptr H5FD_class_t): hid_t {.cdecl, importc: "H5FDregister",
    dynlib: libname.}
proc H5FDunregister*(driver_id: hid_t): herr_t {.cdecl, importc: "H5FDunregister",
    dynlib: libname.}
proc H5FDopen*(name: cstring; flags: cuint; fapl_id: hid_t; maxaddr: haddr_t): ptr H5FD_t {.
    cdecl, importc: "H5FDopen", dynlib: libname.}
proc H5FDclose*(file: ptr H5FD_t): herr_t {.cdecl, importc: "H5FDclose", dynlib: libname.}
proc H5FDcmp*(f1: ptr H5FD_t; f2: ptr H5FD_t): cint {.cdecl, importc: "H5FDcmp",
    dynlib: libname.}
proc H5FDquery*(f: ptr H5FD_t; flags: ptr culong): cint {.cdecl, importc: "H5FDquery",
    dynlib: libname.}
proc H5FDalloc*(file: ptr H5FD_t; `type`: H5FD_mem_t; dxpl_id: hid_t; size: hsize_t): haddr_t {.
    cdecl, importc: "H5FDalloc", dynlib: libname.}
proc H5FDfree*(file: ptr H5FD_t; `type`: H5FD_mem_t; dxpl_id: hid_t; `addr`: haddr_t;
              size: hsize_t): herr_t {.cdecl, importc: "H5FDfree", dynlib: libname.}
proc H5FDget_eoa*(file: ptr H5FD_t; `type`: H5FD_mem_t): haddr_t {.cdecl,
    importc: "H5FDget_eoa", dynlib: libname.}
proc H5FDset_eoa*(file: ptr H5FD_t; `type`: H5FD_mem_t; eoa: haddr_t): herr_t {.cdecl,
    importc: "H5FDset_eoa", dynlib: libname.}
proc H5FDget_eof*(file: ptr H5FD_t; `type`: H5FD_mem_t): haddr_t {.cdecl,
    importc: "H5FDget_eof", dynlib: libname.}
proc H5FDget_vfd_handle*(file: ptr H5FD_t; fapl: hid_t; file_handle: ptr pointer): herr_t {.
    cdecl, importc: "H5FDget_vfd_handle", dynlib: libname.}
proc H5FDread*(file: ptr H5FD_t; `type`: H5FD_mem_t; dxpl_id: hid_t; `addr`: haddr_t;
              size: csize_t; buf: pointer): herr_t {.cdecl, importc: "H5FDread",
    dynlib: libname.}
  ## out
proc H5FDwrite*(file: ptr H5FD_t; `type`: H5FD_mem_t; dxpl_id: hid_t; `addr`: haddr_t;
               size: csize_t; buf: pointer): herr_t {.cdecl, importc: "H5FDwrite",
    dynlib: libname.}
proc H5FDflush*(file: ptr H5FD_t; dxpl_id: hid_t; closing: hbool_t): herr_t {.cdecl,
    importc: "H5FDflush", dynlib: libname.}
proc H5FDtruncate*(file: ptr H5FD_t; dxpl_id: hid_t; closing: hbool_t): herr_t {.cdecl,
    importc: "H5FDtruncate", dynlib: libname.}
proc H5FDlock*(file: ptr H5FD_t; rw: hbool_t): herr_t {.cdecl, importc: "H5FDlock",
    dynlib: libname.}
proc H5FDunlock*(file: ptr H5FD_t): herr_t {.cdecl, importc: "H5FDunlock",
                                        dynlib: libname.}
