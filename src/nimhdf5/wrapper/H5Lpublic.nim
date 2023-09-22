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

## -------------------------------------------------------------------------
##
##  Created:             H5Lpublic.h
##                       Dec 1 2005
##                       James Laird
##
##  Purpose:             Public declarations for the H5L package (links)
##
## -------------------------------------------------------------------------
##

##  Public headers needed by this file

import
  H5public,                   ##  Generic Functions
  H5Tpublic,
  ../H5nimtypes, ../h5libname


##  Datatypes
## ***************
##  Public Macros
## ***************
##  Maximum length of a link's name
##  (encoded in a 32-bit unsigned integer)

const
  # this cast will fail on v0.20.2 on a system in which a definition of
  # `uint32_t` in `H5public.nim` ends up being different than 4 byte
  H5L_MAX_LINK_NAME_LEN* = cast[uint32_t](-1'i32) ##  (4GB - 1)

##  Macro to indicate operation occurs on same location

const
  H5L_SAME_LOC* = 0

##  Current version of the H5L_class_t struct

const
  H5L_LINK_CLASS_T_VERS* = 0

## *****************
##  Public Typedefs
## *****************
##  Link class types.
##  Values less than 64 are reserved for the HDF5 library's internal use.
##  Values 64 to 255 are for "user-defined" link class types; these types are
##  defined by HDF5 but their behavior can be overridden by users.
##  Users who want to create new classes of links should contact the HDF5
##  development team at hdfhelp@ncsa.uiuc.edu .
##  These values can never change because they appear in HDF5 files.
##

type ##  NOTE S.Schmidt: originally the following line was written as
    ##      H5L_TYPE_ERROR = (-1) instead. Causes c2nim to crash
  H5L_type_t* {.size: sizeof(cint).} = enum
    H5L_TYPE_ERROR = -1,      ##  Invalid link type id
    H5L_TYPE_HARD = 0,          ##  Hard link id
    H5L_TYPE_SOFT = 1,          ##  Soft link id
    H5L_TYPE_EXTERNAL = 64,     ##  External link id
    H5L_TYPE_MAX = 255


const
  H5L_TYPE_BUILTIN_MAX* = H5L_TYPE_SOFT
  H5L_TYPE_UD_MIN* = H5L_TYPE_EXTERNAL

##  Information struct for link (for H5Lget_info/H5Lget_info_by_idx)

type
  INNER_C_UNION_3734014316* {.union.} = object
    address*: haddr_t          ##  Address hard link points to
    val_size*: csize_t           ##  Size of a soft link or UD link value

  H5L_info_t* = object
    `type`*: H5L_type_t        ##  Type of link
    corder_valid*: hbool_t     ##  Indicate if creation order is valid
    corder*: uint64           ##  Creation order
    cset*: H5T_cset_t          ##  Character set of link name
    u*: INNER_C_UNION_3734014316


##  The H5L_class_t struct can be used to override the behavior of a
##  "user-defined" link class. Users should populate the struct with callback
##  functions defined below.
##
##  Callback prototypes for user-defined links
##  Link creation callback

type
  H5L_create_func_t* = proc (link_name: cstring; loc_group: hid_t; lnkdata: pointer;
                          lnkdata_size: csize_t; lcpl_id: hid_t): herr_t {.cdecl.}

##  Callback for when the link is moved

type
  H5L_move_func_t* = proc (new_name: cstring; new_loc: hid_t; lnkdata: pointer;
                        lnkdata_size: csize_t): herr_t {.cdecl.}

##  Callback for when the link is copied

type
  H5L_copy_func_t* = proc (new_name: cstring; new_loc: hid_t; lnkdata: pointer;
                        lnkdata_size: csize_t): herr_t {.cdecl.}

##  Callback during link traversal

type
  H5L_traverse_func_t* = proc (link_name: cstring; cur_group: hid_t; lnkdata: pointer;
                            lnkdata_size: csize_t; lapl_id: hid_t): hid_t {.cdecl.}

##  Callback for when the link is deleted

type
  H5L_delete_func_t* = proc (link_name: cstring; file: hid_t; lnkdata: pointer;
                          lnkdata_size: csize_t): herr_t {.cdecl.}

##  Callback for querying the link
##  Returns the size of the buffer needed

type
  H5L_query_func_t* = proc (link_name: cstring; lnkdata: pointer; lnkdata_size: csize_t; buf: pointer; ## out
                         buf_size: csize_t): ssize_t {.cdecl.}

##  User-defined link types

type
  H5L_class_t* = object
    version*: cint             ##  Version number of this struct
    id*: H5L_type_t            ##  Link type ID
    comment*: cstring          ##  Comment for debugging
    create_func*: H5L_create_func_t ##  Callback during link creation
    move_func*: H5L_move_func_t ##  Callback after moving link
    copy_func*: H5L_copy_func_t ##  Callback after copying link
    trav_func*: H5L_traverse_func_t ##  Callback during link traversal
    del_func*: H5L_delete_func_t ##  Callback for link deletion
    query_func*: H5L_query_func_t ##  Callback for queries


##  Prototype for H5Literate/H5Literate_by_name() operator

type
  H5L_iterate_t* = proc (group: hid_t; name: cstring; info: ptr H5L_info_t;
                      op_data: pointer): herr_t {.cdecl.}

##  Callback for external link traversal

type
  H5L_elink_traverse_t* = proc (parent_file_name: cstring;
                             parent_group_name: cstring; child_file_name: cstring;
                             child_object_name: cstring; acc_flags: ptr cuint;
                             fapl_id: hid_t; op_data: pointer): herr_t {.cdecl.}

## ******************
##  Public Variables
## ******************
## *******************
##  Public Prototypes
## *******************

proc H5Lmove*(src_loc: hid_t; src_name: cstring; dst_loc: hid_t; dst_name: cstring;
             lcpl_id: hid_t; lapl_id: hid_t): herr_t {.cdecl, importc: "H5Lmove",
    dynlib: libname.}
proc H5Lcopy*(src_loc: hid_t; src_name: cstring; dst_loc: hid_t; dst_name: cstring;
             lcpl_id: hid_t; lapl_id: hid_t): herr_t {.cdecl, importc: "H5Lcopy",
    dynlib: libname.}
proc H5Lcreate_hard*(cur_loc: hid_t; cur_name: cstring; dst_loc: hid_t;
                    dst_name: cstring; lcpl_id: hid_t; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Lcreate_hard", dynlib: libname.}
proc H5Lcreate_soft*(link_target: cstring; link_loc_id: hid_t; link_name: cstring;
                    lcpl_id: hid_t; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Lcreate_soft", dynlib: libname.}
proc H5Ldelete*(loc_id: hid_t; name: cstring; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Ldelete", dynlib: libname.}
proc H5Ldelete_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                      order: H5_iter_order_t; n: hsize_t; lapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Ldelete_by_idx", dynlib: libname.}
proc H5Lget_val*(loc_id: hid_t; name: cstring; buf: pointer; ## out
                size: csize_t; lapl_id: hid_t): herr_t {.cdecl, importc: "H5Lget_val",
    dynlib: libname.}
proc H5Lget_val_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                       order: H5_iter_order_t; n: hsize_t; buf: pointer; ## out
                       size: csize_t; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Lget_val_by_idx", dynlib: libname.}
proc H5Lexists*(loc_id: hid_t; name: cstring; lapl_id: hid_t): htri_t {.cdecl,
    importc: "H5Lexists", dynlib: libname.}
proc H5Lget_info*(loc_id: hid_t; name: cstring; linfo: ptr H5L_info_t; ## out
                 lapl_id: hid_t): herr_t {.cdecl, importc: "H5Lget_info",
                                        dynlib: libname.}
proc H5Lget_info_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; n: hsize_t; linfo: ptr H5L_info_t; ## out
                        lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Lget_info_by_idx", dynlib: libname.}
proc H5Lget_name_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; n: hsize_t; name: cstring; ## out
                        size: csize_t; lapl_id: hid_t): ssize_t {.cdecl,
    importc: "H5Lget_name_by_idx", dynlib: libname.}
proc H5Literate*(grp_id: hid_t; idx_type: H5_index_t; order: H5_iter_order_t;
                idx: ptr hsize_t; op: H5L_iterate_t; op_data: pointer): herr_t {.cdecl,
    importc: "H5Literate", dynlib: libname.}
proc H5Literate_by_name*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; idx: ptr hsize_t; op: H5L_iterate_t;
                        op_data: pointer; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Literate_by_name", dynlib: libname.}
proc H5Lvisit*(grp_id: hid_t; idx_type: H5_index_t; order: H5_iter_order_t;
              op: H5L_iterate_t; op_data: pointer): herr_t {.cdecl,
    importc: "H5Lvisit", dynlib: libname.}
proc H5Lvisit_by_name*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                      order: H5_iter_order_t; op: H5L_iterate_t; op_data: pointer;
                      lapl_id: hid_t): herr_t {.cdecl, importc: "H5Lvisit_by_name",
    dynlib: libname.}
##  UD link functions

proc H5Lcreate_ud*(link_loc_id: hid_t; link_name: cstring; link_type: H5L_type_t;
                  udata: pointer; udata_size: csize_t; lcpl_id: hid_t; lapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Lcreate_ud", dynlib: libname.}
proc H5Lregister*(cls: ptr H5L_class_t): herr_t {.cdecl, importc: "H5Lregister",
    dynlib: libname.}
proc H5Lunregister*(id: H5L_type_t): herr_t {.cdecl, importc: "H5Lunregister",
    dynlib: libname.}
proc H5Lis_registered*(id: H5L_type_t): htri_t {.cdecl, importc: "H5Lis_registered",
    dynlib: libname.}
##  External link functions

proc H5Lunpack_elink_val*(ext_linkval: pointer; ## in
                         link_size: csize_t; flags: ptr cuint; filename: cstringArray; ## out
                         obj_path: cstringArray): herr_t {.cdecl,
    importc: "H5Lunpack_elink_val", dynlib: libname.}
  ## out
proc H5Lcreate_external*(file_name: cstring; obj_name: cstring; link_loc_id: hid_t;
                        link_name: cstring; lcpl_id: hid_t; lapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Lcreate_external", dynlib: libname.}
