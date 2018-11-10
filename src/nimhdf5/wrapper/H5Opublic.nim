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

## -------------------------------------------------------------------------
##
##  Created:             H5Opublic.h
##                       Aug  5 1997
##                       Robb Matzke <matzke@llnl.gov>
##
##  Purpose:             Public declarations for the H5O (object header)
##                       package.
##
## -------------------------------------------------------------------------
##

##  Public headers needed by this file

import
  H5public,                   ##  Generic Functions
  H5Ipublic,                  ##  IDs
  H5Lpublic,
  ../H5nimtypes, ../h5libname


##  Links
## ***************
##  Public Macros
## ***************
##  Flags for object copy (H5Ocopy)

const
  H5O_COPY_SHALLOW_HIERARCHY_FLAG* = (0x00000001) ##  Copy only immediate members
  H5O_COPY_EXPAND_SOFT_LINK_FLAG* = (0x00000002) ##  Expand soft links into new objects
  H5O_COPY_EXPAND_EXT_LINK_FLAG* = (0x00000004) ##  Expand external links into new objects
  H5O_COPY_EXPAND_REFERENCE_FLAG* = (0x00000008) ##  Copy objects that are pointed by references
  H5O_COPY_WITHOUT_ATTR_FLAG* = (0x00000010) ##  Copy object without copying attributes
  H5O_COPY_PRESERVE_NULL_FLAG* = (0x00000020) ##  Copy NULL messages (empty space)
  H5O_COPY_MERGE_COMMITTED_DTYPE_FLAG* = (0x00000040) ##  Merge committed datatypes in dest file
  H5O_COPY_ALL* = (0x0000007F)  ##  All object copying flags (for internal checking)

##  Flags for shared message indexes.
##  Pass these flags in using the mesg_type_flags parameter in
##  H5P_set_shared_mesg_index.
##  (Developers: These flags correspond to object header message type IDs,
##  but we need to assign each kind of message to a different bit so that
##  one index can hold multiple types.)
##

const
  H5O_SHMESG_NONE_FLAG* = 0x00000000
  H5O_SHMESG_SDSPACE_FLAG* = (1'u shl 0x00000001) ##  Simple Dataspace Message.
  H5O_SHMESG_DTYPE_FLAG* = (1'u shl 0x00000003) ##  Datatype Message.
  H5O_SHMESG_FILL_FLAG* = (1'u shl 0x00000005) ##  Fill Value Message.
  H5O_SHMESG_PLINE_FLAG* = (1'u shl 0x0000000B) ##  Filter pipeline message.
  H5O_SHMESG_ATTR_FLAG* = (1'u shl 0x0000000C) ##  Attribute Message.
  H5O_SHMESG_ALL_FLAG* = (H5O_SHMESG_SDSPACE_FLAG or H5O_SHMESG_DTYPE_FLAG or
      H5O_SHMESG_FILL_FLAG or H5O_SHMESG_PLINE_FLAG or H5O_SHMESG_ATTR_FLAG)

##  Object header status flag definitions

const
  H5O_HDR_CHUNK0_SIZE* = 0x00000003
  H5O_HDR_ATTR_CRT_ORDER_TRACKED* = 0x00000004
  H5O_HDR_ATTR_CRT_ORDER_INDEXED* = 0x00000008
  H5O_HDR_ATTR_STORE_PHASE_CHANGE* = 0x00000010
  H5O_HDR_STORE_TIMES* = 0x00000020
  H5O_HDR_ALL_FLAGS* = (H5O_HDR_CHUNK0_SIZE or H5O_HDR_ATTR_CRT_ORDER_TRACKED or
      H5O_HDR_ATTR_CRT_ORDER_INDEXED or H5O_HDR_ATTR_STORE_PHASE_CHANGE or
      H5O_HDR_STORE_TIMES)

##  Maximum shared message values.  Number of indexes is 8 to allow room to add
##  new types of messages.
##

const
  H5O_SHMESG_MAX_NINDEXES* = 8
  H5O_SHMESG_MAX_LIST_SIZE* = 5000

## *****************
##  Public Typedefs
## *****************
##  Types of objects in file

type
  H5O_type_t* {.size: sizeof(cint).} = enum
    H5O_TYPE_UNKNOWN = - 1,      ##  Unknown object type
    H5O_TYPE_GROUP,           ##  Object is a group
    H5O_TYPE_DATASET,         ##  Object is a dataset
    H5O_TYPE_NAMED_DATATYPE,  ##  Object is a named data type
    H5O_TYPE_NTYPES           ##  Number of different object types (must be last!)


##  Information struct for object header metadata (for H5Oget_info/H5Oget_info_by_name/H5Oget_info_by_idx)

type
  INNER_C_STRUCT_56328739* = object
    total*: hsize_t            ##  Total space for storing object header in file
    meta*: hsize_t             ##  Space within header for object header metadata information
    mesg*: hsize_t             ##  Space within header for actual message information
    free*: hsize_t             ##  Free space within object header

  INNER_C_STRUCT_444884638* = object
    present*: uint64           ##  Flags to indicate presence of message type in header
    shared*: uint64            ##  Flags to indicate message type is shared in header

  H5O_hdr_info_t* = object
    version*: cuint            ##  Version number of header format in file
    nmesgs*: cuint             ##  Number of object header messages
    nchunks*: cuint            ##  Number of object header chunks
    flags*: cuint              ##  Object header status flags
    space*: INNER_C_STRUCT_56328739
    mesg*: INNER_C_STRUCT_444884638


##  Information struct for object (for H5Oget_info/H5Oget_info_by_name/H5Oget_info_by_idx)

type
  INNER_C_STRUCT_1943491610* = object
    obj*: H5_ih_info_t         ##  v1/v2 B-tree & local/fractal heap for groups, B-tree for chunked datasets
    attr*: H5_ih_info_t        ##  v2 B-tree & heap for attributes

  H5O_info_t* = object
    fileno*: culong            ##  File number that object is located in
    `addr`*: haddr_t           ##  Object address in file
    `type`*: H5O_type_t        ##  Basic object type (group, dataset, etc.)
    rc*: cuint                 ##  Reference count of object
    atime*: time_t             ##  Access time
    mtime*: time_t             ##  Modification time
    ctime*: time_t             ##  Change time
    btime*: time_t             ##  Birth time
    num_attrs*: hsize_t        ##  # of attributes attached to object
    hdr*: H5O_hdr_info_t       ##  Object header information
                       ##  Extra metadata storage for obj & attributes
    meta_size*: INNER_C_STRUCT_1943491610


##  Typedef for message creation indexes

type
  H5O_msg_crt_idx_t* = uint32_t

##  Prototype for H5Ovisit/H5Ovisit_by_name() operator

type
  H5O_iterate_t* = proc (obj: hid_t; name: cstring; info: ptr H5O_info_t; op_data: pointer): herr_t {.
      cdecl.}
  H5O_mcdt_search_ret_t* {.size: sizeof(cint).} = enum
    H5O_MCDT_SEARCH_ERROR = - 1, ##  Abort H5Ocopy
    H5O_MCDT_SEARCH_CONT,     ##  Continue the global search of all committed datatypes in the destination file
    H5O_MCDT_SEARCH_STOP      ##  Stop the search, but continue copying.  The committed datatype will be copied but not merged.


##  Callback to invoke when completing the search for a matching committed datatype from the committed dtype list

type
  H5O_mcdt_search_cb_t* = proc (op_data: pointer): H5O_mcdt_search_ret_t {.cdecl.}

## ******************
##  Public Variables
## ******************

## *******************
##  Public Prototypes
## *******************

proc H5Oopen*(loc_id: hid_t; name: cstring; lapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Oopen", dynlib: libname.}
proc H5Oopen_by_addr*(loc_id: hid_t; `addr`: haddr_t): hid_t {.cdecl,
    importc: "H5Oopen_by_addr", dynlib: libname.}
proc H5Oopen_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                    order: H5_iter_order_t; n: hsize_t; lapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Oopen_by_idx", dynlib: libname.}
proc H5Oexists_by_name*(loc_id: hid_t; name: cstring; lapl_id: hid_t): htri_t {.cdecl,
    importc: "H5Oexists_by_name", dynlib: libname.}

when defined(H5_FUTURE):
  proc H5Oget_info*(loc_id: hid_t; oinfo: ptr H5O_info_t): herr_t {.cdecl,
      importc: "H5Oget_info2", dynlib: libname.}
  proc H5Oget_info_by_name*(loc_id: hid_t; name: cstring; oinfo: ptr H5O_info_t;
                           lapl_id: hid_t): herr_t {.cdecl,
      importc: "H5Oget_info_by_name2", dynlib: libname.}
  proc H5Oget_info_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                          order: H5_iter_order_t; n: hsize_t; oinfo: ptr H5O_info_t;
                          lapl_id: hid_t): herr_t {.cdecl,
      importc: "H5Oget_info_by_idx2", dynlib: libname.}
else:
  proc H5Oget_info*(loc_id: hid_t; oinfo: ptr H5O_info_t): herr_t {.cdecl,
      importc: "H5Oget_info", dynlib: libname.}
  proc H5Oget_info_by_name*(loc_id: hid_t; name: cstring; oinfo: ptr H5O_info_t;
                           lapl_id: hid_t): herr_t {.cdecl,
      importc: "H5Oget_info_by_name", dynlib: libname.}
  proc H5Oget_info_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                          order: H5_iter_order_t; n: hsize_t; oinfo: ptr H5O_info_t;
                          lapl_id: hid_t): herr_t {.cdecl,
      importc: "H5Oget_info_by_idx", dynlib: libname.}
proc H5Olink*(obj_id: hid_t; new_loc_id: hid_t; new_name: cstring; lcpl_id: hid_t;
             lapl_id: hid_t): herr_t {.cdecl, importc: "H5Olink", dynlib: libname.}
proc H5Oincr_refcount*(object_id: hid_t): herr_t {.cdecl,
    importc: "H5Oincr_refcount", dynlib: libname.}
proc H5Odecr_refcount*(object_id: hid_t): herr_t {.cdecl,
    importc: "H5Odecr_refcount", dynlib: libname.}
proc H5Ocopy*(src_loc_id: hid_t; src_name: cstring; dst_loc_id: hid_t;
             dst_name: cstring; ocpypl_id: hid_t; lcpl_id: hid_t): herr_t {.cdecl,
    importc: "H5Ocopy", dynlib: libname.}
proc H5Oset_comment*(obj_id: hid_t; comment: cstring): herr_t {.cdecl,
    importc: "H5Oset_comment", dynlib: libname.}
proc H5Oset_comment_by_name*(loc_id: hid_t; name: cstring; comment: cstring;
                            lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Oset_comment_by_name", dynlib: libname.}
proc H5Oget_comment*(obj_id: hid_t; comment: cstring; bufsize: csize): ssize_t {.cdecl,
    importc: "H5Oget_comment", dynlib: libname.}
proc H5Oget_comment_by_name*(loc_id: hid_t; name: cstring; comment: cstring;
                            bufsize: csize; lapl_id: hid_t): ssize_t {.cdecl,
    importc: "H5Oget_comment_by_name", dynlib: libname.}
when defined(H5_FUTURE):
  proc H5Ovisit*(obj_id: hid_t; idx_type: H5_index_t; order: H5_iter_order_t;
                 op: H5O_iterate_t; op_data: pointer): herr_t {.cdecl,
      importc: "H5Ovisit2", dynlib: libname.}
  proc H5Ovisit_by_name*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; op: H5O_iterate_t; op_data: pointer;
                        lapl_id: hid_t): herr_t {.cdecl, importc: "H5Ovisit_by_name2",
      dynlib: libname.}
else:
  proc H5Ovisit*(obj_id: hid_t; idx_type: H5_index_t; order: H5_iter_order_t;
                 op: H5O_iterate_t; op_data: pointer): herr_t {.cdecl,
      importc: "H5Ovisit", dynlib: libname.}
  proc H5Ovisit_by_name*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; op: H5O_iterate_t; op_data: pointer;
                        lapl_id: hid_t): herr_t {.cdecl, importc: "H5Ovisit_by_name",
      dynlib: libname.}

proc H5Oclose*(object_id: hid_t): herr_t {.cdecl, importc: "H5Oclose", dynlib: libname.}
proc H5Oflush*(obj_id: hid_t): herr_t {.cdecl, importc: "H5Oflush", dynlib: libname.}
proc H5Orefresh*(oid: hid_t): herr_t {.cdecl, importc: "H5Orefresh", dynlib: libname.}
proc H5Odisable_mdc_flushes*(object_id: hid_t): herr_t {.cdecl,
    importc: "H5Odisable_mdc_flushes", dynlib: libname.}
proc H5Oenable_mdc_flushes*(object_id: hid_t): herr_t {.cdecl,
    importc: "H5Oenable_mdc_flushes", dynlib: libname.}
proc H5Oare_mdc_flushes_disabled*(object_id: hid_t; are_disabled: ptr hbool_t): herr_t {.
    cdecl, importc: "H5Oare_mdc_flushes_disabled", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  Typedefs
  ##  A struct that's part of the H5G_stat_t structure (deprecated)
  type
    H5O_stat_t* = object
      size*: hsize_t           ##  Total size of object header in file
      free*: hsize_t           ##  Free space within object header
      nmesgs*: cuint           ##  Number of object header messages
      nchunks*: cuint          ##  Number of object header chunks

  ##  Function prototypes
