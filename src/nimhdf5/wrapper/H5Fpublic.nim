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
##  This file contains public declarations for the H5F module.
##

##  Public header files needed by this file

import
  H5public, H5ACpublic, H5Ipublic, ../H5nimtypes, ../h5libname

##  When this header is included from a private header, don't make calls to H5check()

# when not defined(H5private_H):
#   const
#     H5CHECK* = H5check()
# else:
#   const
#     H5CHECK* = true
# ##  When this header is included from a private HDF5 header, don't make calls to H5open()

# when not defined(H5private_H):
#   const
#     H5OPEN* = H5open()
# else:
#   const
#     H5OPEN* = true
##
##  These are the bits that can be passed to the `flags' argument of
##  H5Fcreate() and H5Fopen(). Use the bit-wise OR operator (|) to combine
##  them as needed.  As a side effect, they call H5check_version() to make sure
##  that the application is compiled with a version of the hdf5 header files
##  which are compatible with the library to which the application is linked.
##  We're assuming that these constants are used rather early in the hdf5
##  session.
##
## (H5check(), H5open(), 0x0000u)
##  #define H5F_ACC_RDONLY	(H5CHECK H5OPEN 0x0000u)	/\*absence of rdwr => rd-only *\/
##  #define H5F_ACC_RDWR	(H5CHECK H5OPEN 0x0001u)	/\*open for read and write    *\/
##  #define H5F_ACC_TRUNC	(H5CHECK H5OPEN 0x0002u)	/\*overwrite existing files   *\/
##  #define H5F_ACC_EXCL	(H5CHECK H5OPEN 0x0004u)	/\*fail if file already exists*\/
##  /\* NOTE: 0x0008u was H5F_ACC_DEBUG, now deprecated *\/
##  #define H5F_ACC_CREAT	(H5CHECK H5OPEN 0x0010u)	/\*create non-existing files  *\/
##  #define H5F_ACC_SWMR_WRITE	(H5CHECK 0x0020u) /\*indicate that this file is
const
  H5F_ACC_RDONLY*     = cuint(0x0000)
  H5F_ACC_RDWR*       = cuint(0x0001)
  H5F_ACC_TRUNC*      = cuint(0x0002)
  H5F_ACC_EXCL*        = cuint(0x0004)
  H5F_ACC_CREAT*      = cuint(0x0010)
  H5F_ACC_SWMR_WRITE* = cuint(0x0020)
##                                                   * open for writing in a
##                                                   * single-writer/multi-reader (SWMR)
##                                                   * scenario.  Note that the
##                                                   * process(es) opening the file
##                                                   * for reading must open the file
##                                                   * with RDONLY access, and use
##                                                   * the special "SWMR_READ" access
##                                                   * flag. *\/
##  #define H5F_ACC_SWMR_READ	(H5CHECK 0x0040u) /\*indicate that this file is
##                                                   * open for reading in a
##                                                   * single-writer/multi-reader (SWMR)
##                                                   * scenario.  Note that the
##                                                   * process(es) opening the file
##                                                   * for SWMR reading must also
##                                                   * open the file with the RDONLY
##                                                   * flag.  *\/
##  Value passed to H5Pset_elink_acc_flags to cause flags to be taken from the
##  parent file.
## #define H5F_ACC_DEFAULT (H5CHECK H5OPEN 0xffffu)	/*ignore setting on lapl     */
##  Flags for H5Fget_obj_count() & H5Fget_obj_ids() calls

const
  H5F_OBJ_FILE* = (0x00000001)  ##  File objects
  H5F_OBJ_DATASET* = (0x00000002) ##  Dataset objects
  H5F_OBJ_GROUP* = (0x00000004) ##  Group objects
  H5F_OBJ_DATATYPE* = (0x00000008) ##  Named datatype objects
  H5F_OBJ_ATTR* = (0x00000010)  ##  Attribute objects
  H5F_OBJ_ALL* = (H5F_OBJ_FILE or H5F_OBJ_DATASET or H5F_OBJ_GROUP or
      H5F_OBJ_DATATYPE or H5F_OBJ_ATTR)
  H5F_OBJ_LOCAL* = (0x00000020) ##  Restrict search to objects opened through current file ID

##  (as opposed to objects opened through any file ID accessing this file)

# const
#   H5F_FAMILY_DEFAULT* = cast[hsize_t](0)

when defined(H5_HAVE_PARALLEL):
  ##
  ##  Use this constant string as the MPI_Info key to set H5Fmpio debug flags.
  ##  To turn on H5Fmpio debug flags, set the MPI_Info value with this key to
  ##  have the value of a string consisting of the characters that turn on the
  ##  desired flags.
  ##
  const
    H5F_MPIO_DEBUG_KEY* = "H5F_mpio_debug_key"
##  The difference between a single file and a set of mounted files

type
  H5F_scope_t* {.size: sizeof(cint).} = enum
    H5F_SCOPE_LOCAL = 0,        ## specified file handle only
    H5F_SCOPE_GLOBAL = 1


##  Unlimited file size for H5Pset_external()

const
  H5F_UNLIMITED* = ((hsize_t)(- 1))

##  How does file close behave?
##  H5F_CLOSE_DEFAULT - Use the degree pre-defined by underlining VFL
##  H5F_CLOSE_WEAK    - file closes only after all opened objects are closed
##  H5F_CLOSE_SEMI    - if no opened objects, file is close; otherwise, file
## 		       close fails
##  H5F_CLOSE_STRONG  - if there are opened objects, close them first, then
## 		       close file
##

type
  H5F_close_degree_t* {.size: sizeof(cint).} = enum
    H5F_CLOSE_DEFAULT = 0, H5F_CLOSE_WEAK = 1, H5F_CLOSE_SEMI = 2, H5F_CLOSE_STRONG = 3


##  Current "global" information about file

type
  INNER_C_STRUCT_1010883923* = object
    version*: cuint            ##  Superblock version #
    super_size*: hsize_t       ##  Superblock size
    super_ext_size*: hsize_t   ##  Superblock extension size

  INNER_C_STRUCT_1750163597* = object
    version*: cuint            ##  Version # of file free space management
    meta_size*: hsize_t        ##  Free space manager metadata size
    tot_space*: hsize_t        ##  Amount of free space in the file

  INNER_C_STRUCT_1791471122* = object
    version*: cuint            ##  Version # of shared object header info
    hdr_size*: hsize_t         ##  Shared object header message header size
    msgs_info*: H5_ih_info_t   ##  Shared object header message index & heap size

  H5F_info2_t* = object
    super*: INNER_C_STRUCT_1010883923
    free*: INNER_C_STRUCT_1750163597
    sohm*: INNER_C_STRUCT_1791471122


##
##  Types of allocation requests. The values larger than H5FD_MEM_DEFAULT
##  should not change other than adding new types to the end. These numbers
##  might appear in files.
##
##  Note: please change the log VFD flavors array if you change this
##  enumeration.
##

type
  H5F_mem_t* {.size: sizeof(cint).} = enum
    H5FD_MEM_NOLIST = - 1,       ##  Data should not appear in the free list.
                       ##  Must be negative.
                       ##
    H5FD_MEM_DEFAULT = 0,       ##  Value not yet set.  Can also be the
                       ##  datatype set in a larger allocation
                       ##  that will be suballocated by the library.
                       ##  Must be zero.
                       ##
    H5FD_MEM_SUPER = 1,         ##  Superblock data
    H5FD_MEM_BTREE = 2,         ##  B-tree data
    H5FD_MEM_DRAW = 3,          ##  Raw data (content of datasets, etc.)
    H5FD_MEM_GHEAP = 4,         ##  Global heap data
    H5FD_MEM_LHEAP = 5,         ##  Local heap data
    H5FD_MEM_OHDR = 6,          ##  Object header data
    H5FD_MEM_NTYPES           ##  Sentinel value - must be last


##  Free space section information

type
  H5F_sect_info_t* = object
    `addr`*: haddr_t           ##  Address of free space section
    size*: hsize_t             ##  Size of free space section


##  Library's file format versions

type
  H5F_libver_t* {.size: sizeof(cint).} = enum
    H5F_LIBVER_EARLIEST,      ##  Use the earliest possible format for storing objects
    H5F_LIBVER_LATEST         ##  Use the latest possible format available for storing objects


##  File space handling strategy

type
  H5F_fspace_strategy_t* {.size: sizeof(cint).} = enum
    H5F_FSPACE_STRATEGY_FSM_AGGR = 0, ##  Mechanisms: free-space managers, aggregators, and virtual file drivers
                                   ##  This is the library default when not set
    H5F_FSPACE_STRATEGY_PAGE = 1, ##  Mechanisms: free-space managers with embedded paged aggregation and virtual file drivers
    H5F_FSPACE_STRATEGY_AGGR = 2, ##  Mechanisms: aggregators and virtual file drivers
    H5F_FSPACE_STRATEGY_NONE = 3, ##  Mechanisms: virtual file drivers
    H5F_FSPACE_STRATEGY_NTYPES ##  must be last


##  Deprecated: File space handling strategy for release 1.10.0
##  They are mapped to H5F_fspace_strategy_t as defined above from release 1.10.1 onwards

type
  H5F_file_space_type_t* {.size: sizeof(cint).} = enum
    H5F_FILE_SPACE_DEFAULT = 0, ##  Default (or current) free space strategy setting
    H5F_FILE_SPACE_ALL_PERSIST = 1, ##  Persistent free space managers, aggregators, virtual file driver
    H5F_FILE_SPACE_ALL = 2, ##  Non-persistent free space managers, aggregators, virtual file driver
                         ##  This is the library default
    H5F_FILE_SPACE_AGGR_VFD = 3, ##  Aggregators, Virtual file driver
    H5F_FILE_SPACE_VFD = 4,     ##  Virtual file driver
    H5F_FILE_SPACE_NTYPES     ##  must be last


##  Data structure to report the collection of read retries for metadata items with checksum
##  Used by public routine H5Fget_metadata_read_retry_info()

const
  H5F_NUM_METADATA_READ_RETRY_TYPES* = 21

type
  H5F_retry_info_t* = object
    nbins*: cuint
    retries*: array[H5F_NUM_METADATA_READ_RETRY_TYPES, ptr uint32_t]


##  Callback for H5Pset_object_flush_cb() in a file access property list

type
  H5F_flush_cb_t* = proc (object_id: hid_t; udata: pointer): herr_t {.cdecl.}

##  Functions in H5F.c

proc H5Fis_hdf5*(filename: cstring): htri_t {.cdecl, importc: "H5Fis_hdf5",
    dynlib: libname.}
proc H5Fcreate*(filename: cstring; flags: cuint; create_plist: hid_t;
               access_plist: hid_t): hid_t {.cdecl, importc: "H5Fcreate",
    dynlib: libname.}
proc H5Fopen*(filename: cstring; flags: cuint; access_plist: hid_t): hid_t {.cdecl,
    importc: "H5Fopen", dynlib: libname.}
proc H5Freopen*(file_id: hid_t): hid_t {.cdecl, importc: "H5Freopen", dynlib: libname.}
proc H5Fflush*(object_id: hid_t; scope: H5F_scope_t): herr_t {.cdecl,
    importc: "H5Fflush", dynlib: libname.}
proc H5Fclose*(file_id: hid_t): herr_t {.cdecl, importc: "H5Fclose", dynlib: libname.}
proc H5Fget_create_plist*(file_id: hid_t): hid_t {.cdecl,
    importc: "H5Fget_create_plist", dynlib: libname.}
proc H5Fget_access_plist*(file_id: hid_t): hid_t {.cdecl,
    importc: "H5Fget_access_plist", dynlib: libname.}
proc H5Fget_intent*(file_id: hid_t; intent: ptr cuint): herr_t {.cdecl,
    importc: "H5Fget_intent", dynlib: libname.}
proc H5Fget_obj_count*(file_id: hid_t; types: cuint): ssize_t {.cdecl,
    importc: "H5Fget_obj_count", dynlib: libname.}
proc H5Fget_obj_ids*(file_id: hid_t; types: cuint; max_objs: csize;
                    obj_id_list: ptr hid_t): ssize_t {.cdecl,
    importc: "H5Fget_obj_ids", dynlib: libname.}
proc H5Fget_vfd_handle*(file_id: hid_t; fapl: hid_t; file_handle: ptr pointer): herr_t {.
    cdecl, importc: "H5Fget_vfd_handle", dynlib: libname.}
proc H5Fmount*(loc: hid_t; name: cstring; child: hid_t; plist: hid_t): herr_t {.cdecl,
    importc: "H5Fmount", dynlib: libname.}
proc H5Funmount*(loc: hid_t; name: cstring): herr_t {.cdecl, importc: "H5Funmount",
    dynlib: libname.}
proc H5Fget_freespace*(file_id: hid_t): hssize_t {.cdecl,
    importc: "H5Fget_freespace", dynlib: libname.}
proc H5Fget_filesize*(file_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Fget_filesize", dynlib: libname.}
proc H5Fget_file_image*(file_id: hid_t; buf_ptr: pointer; buf_len: csize): ssize_t {.
    cdecl, importc: "H5Fget_file_image", dynlib: libname.}
proc H5Fget_mdc_config*(file_id: hid_t; config_ptr: ptr H5AC_cache_config_t): herr_t {.
    cdecl, importc: "H5Fget_mdc_config", dynlib: libname.}
proc H5Fset_mdc_config*(file_id: hid_t; config_ptr: ptr H5AC_cache_config_t): herr_t {.
    cdecl, importc: "H5Fset_mdc_config", dynlib: libname.}
proc H5Fget_mdc_hit_rate*(file_id: hid_t; hit_rate_ptr: ptr cdouble): herr_t {.cdecl,
    importc: "H5Fget_mdc_hit_rate", dynlib: libname.}
proc H5Fget_mdc_size*(file_id: hid_t; max_size_ptr: ptr csize;
                     min_clean_size_ptr: ptr csize; cur_size_ptr: ptr csize;
                     cur_num_entries_ptr: ptr cint): herr_t {.cdecl,
    importc: "H5Fget_mdc_size", dynlib: libname.}
proc H5Freset_mdc_hit_rate_stats*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Freset_mdc_hit_rate_stats", dynlib: libname.}
proc H5Fget_name*(obj_id: hid_t; name: cstring; size: csize): ssize_t {.cdecl,
    importc: "H5Fget_name", dynlib: libname.}
proc H5Fget_info2*(obj_id: hid_t; finfo: ptr H5F_info2_t): herr_t {.cdecl,
    importc: "H5Fget_info2", dynlib: libname.}
proc H5Fget_metadata_read_retry_info*(file_id: hid_t; info: ptr H5F_retry_info_t): herr_t {.
    cdecl, importc: "H5Fget_metadata_read_retry_info", dynlib: libname.}
proc H5Fstart_swmr_write*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Fstart_swmr_write", dynlib: libname.}
proc H5Fget_free_sections*(file_id: hid_t; `type`: H5F_mem_t; nsects: csize; sect_info: ptr H5F_sect_info_t): ssize_t {.
    cdecl, importc: "H5Fget_free_sections", dynlib: libname.}
  ## out
proc H5Fclear_elink_file_cache*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Fclear_elink_file_cache", dynlib: libname.}
proc H5Fset_latest_format*(file_id: hid_t; latest_format: hbool_t): herr_t {.cdecl,
    importc: "H5Fset_latest_format", dynlib: libname.}
proc H5Fstart_mdc_logging*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Fstart_mdc_logging", dynlib: libname.}
proc H5Fstop_mdc_logging*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Fstop_mdc_logging", dynlib: libname.}
proc H5Fget_mdc_logging_status*(file_id: hid_t; is_enabled: ptr hbool_t;
                               is_currently_logging: ptr hbool_t): herr_t {.cdecl,
    importc: "H5Fget_mdc_logging_status", dynlib: libname.}
  ## OUT
  ## OUT
proc H5Fformat_convert*(fid: hid_t): herr_t {.cdecl, importc: "H5Fformat_convert",
    dynlib: libname.}
proc H5Freset_page_buffering_stats*(file_id: hid_t): herr_t {.cdecl,
    importc: "H5Freset_page_buffering_stats", dynlib: libname.}
proc H5Fget_page_buffering_stats*(file_id: hid_t; accesses: array[2, cuint];
                                 hits: array[2, cuint]; misses: array[2, cuint];
                                 evictions: array[2, cuint];
                                 bypasses: array[2, cuint]): herr_t {.cdecl,
    importc: "H5Fget_page_buffering_stats", dynlib: libname.}
proc H5Fget_mdc_image_info*(file_id: hid_t; image_addr: ptr haddr_t;
                           image_size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Fget_mdc_image_info", dynlib: libname.}
when defined(H5_HAVE_PARALLEL):
  proc H5Fset_mpi_atomicity*(file_id: hid_t; flag: hbool_t): herr_t {.cdecl,
      importc: "H5Fset_mpi_atomicity", dynlib: libname.}
  proc H5Fget_mpi_atomicity*(file_id: hid_t; flag: ptr hbool_t): herr_t {.cdecl,
      importc: "H5Fget_mpi_atomicity", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ## #define H5F_ACC_DEBUG	(H5CHECK H5OPEN 0x0000u)	/*print debug info (deprecated)*/
  ##  Typedefs
  ##  Current "global" information about file
  type
    INNER_C_STRUCT_890420368* = object
      hdr_size*: hsize_t       ##  Shared object header message header size
      msgs_info*: H5_ih_info_t ##  Shared object header message index & heap size

  type
    H5F_info1_t* = object
      super_ext_size*: hsize_t ##  Superblock extension size
      sohm*: INNER_C_STRUCT_890420368

  ##  Function prototypes
  proc H5Fget_info1*(obj_id: hid_t; finfo: ptr H5F_info1_t): herr_t {.cdecl,
      importc: "H5Fget_info1", dynlib: libname.}
