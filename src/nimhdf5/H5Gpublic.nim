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
##  Created:             H5Gpublic.h
##                       Jul 11 1997
##                       Robb Matzke <matzke@llnl.gov>
## 
##  Purpose:             Public declarations for the H5G package
## 
## -------------------------------------------------------------------------
## 

##  System headers needed by this file

##  Public headers needed by this file

import
  H5public,                   ##  Generic Functions
  H5Lpublic,                  ##  Links
  H5Opublic,                  ##  Object headers
  H5Tpublic,
  H5nimtypes

when not declared(libname):
  const
    libname* = "libhdf5.so"
  

##  Datatypes
## ***************
##  Public Macros
## ***************

## *****************
##  Public Typedefs
## *****************
##  Types of link storage for groups

type
  H5G_storage_type_t* {.size: sizeof(cint).} = enum
    H5G_STORAGE_TYPE_UNKNOWN = - 1, ##  Unknown link storage type
    H5G_STORAGE_TYPE_SYMBOL_TABLE, ##  Links in group are stored with a "symbol table"
                                  ##  (this is sometimes called "old-style" groups)
    H5G_STORAGE_TYPE_COMPACT, ##  Links are stored in object header
    H5G_STORAGE_TYPE_DENSE    ##  Links are stored in fractal heap & indexed with v2 B-tree


##  Information struct for group (for H5Gget_info/H5Gget_info_by_name/H5Gget_info_by_idx)

type
  H5G_info_t* = object
    storage_type*: H5G_storage_type_t ##  Type of storage for links in group
    nlinks*: hsize_t           ##  Number of links in group
    max_corder*: clonglong     ##  Current max. creation order value for group
    mounted*: hbool_t          ##  Whether group has a file mounted on it
  

## ******************
##  Public Variables
## ******************
## *******************
##  Public Prototypes
## *******************

proc H5Gcreate2*(loc_id: hid_t; name: cstring; lcpl_id: hid_t; gcpl_id: hid_t;
                gapl_id: hid_t): hid_t {.cdecl, importc: "H5Gcreate2", dynlib: libname.}
proc H5Gcreate_anon*(loc_id: hid_t; gcpl_id: hid_t; gapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Gcreate_anon", dynlib: libname.}
proc H5Gopen2*(loc_id: hid_t; name: cstring; gapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Gopen2", dynlib: libname.}
proc H5Gget_create_plist*(group_id: hid_t): hid_t {.cdecl,
    importc: "H5Gget_create_plist", dynlib: libname.}
proc H5Gget_info*(loc_id: hid_t; ginfo: ptr H5G_info_t): herr_t {.cdecl,
    importc: "H5Gget_info", dynlib: libname.}
proc H5Gget_info_by_name*(loc_id: hid_t; name: cstring; ginfo: ptr H5G_info_t;
                         lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Gget_info_by_name", dynlib: libname.}
proc H5Gget_info_by_idx*(loc_id: hid_t; group_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; n: hsize_t; ginfo: ptr H5G_info_t;
                        lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Gget_info_by_idx", dynlib: libname.}
proc H5Gclose*(group_id: hid_t): herr_t {.cdecl, importc: "H5Gclose", dynlib: libname.}
proc H5Gflush*(group_id: hid_t): herr_t {.cdecl, importc: "H5Gflush", dynlib: libname.}
proc H5Grefresh*(group_id: hid_t): herr_t {.cdecl, importc: "H5Grefresh",
                                        dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
## 
##  Use of these symbols is deprecated.
## 

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  Link definitions
  const
    H5G_SAME_LOC* = H5L_SAME_LOC
    H5G_LINK_ERROR* = H5L_TYPE_ERROR
    H5G_LINK_HARD* = H5L_TYPE_HARD
    H5G_LINK_SOFT* = H5L_TYPE_SOFT
  type
    # need to define H5G_link_t as a type, not as a const variable, since it
    # is handed to a function as a type
    H5G_link_t* = H5L_type_t
  ##  Macros for types of objects in a group (see H5G_obj_t definition)
  const
    H5G_NTYPES* = 256
    H5G_NLIBTYPES* = 8
    H5G_NUSERTYPES* = (H5G_NTYPES - H5G_NLIBTYPES)
  template H5G_USERTYPE*(X: untyped): untyped =
    (8 + (X))                   ##  User defined types
  
  ##  Typedefs
  ## 
  ##  An object has a certain type. The first few numbers are reserved for use
  ##  internally by HDF5. Users may add their own types with higher values.  The
  ##  values are never stored in the file -- they only exist while an
  ##  application is running.  An object may satisfy the `isa' function for more
  ##  than one type.
  ## 
  type
    H5G_obj_t* {.size: sizeof(cint).} = enum
      H5G_UNKNOWN = - 1,         ##  Unknown object type
      H5G_GROUP,              ##  Object is a group
      H5G_DATASET,            ##  Object is a dataset
      H5G_TYPE,               ##  Object is a named data type
      H5G_LINK,               ##  Object is a symbolic link
      H5G_UDLINK,             ##  Object is a user-defined link
      H5G_RESERVED_5,         ##  Reserved for future use
      H5G_RESERVED_6,         ##  Reserved for future use
      H5G_RESERVED_7          ##  Reserved for future use
  ##  Prototype for H5Giterate() operator
  type
    H5G_iterate_t* = proc (group: hid_t; name: cstring; op_data: pointer): herr_t {.cdecl.}
  ##  Information about an object
  type
    H5G_stat_t* = object
      fileno*: array[2, culong] ## file number
      objno*: array[2, culong]  ## object number
      nlink*: cuint            ## number of hard links to object
      `type`*: H5G_obj_t       ## basic object type
      mtime*: time_t           ## modification time
      linklen*: csize          ## symbolic link value length
      ohdr*: H5O_stat_t        ##  Object header information
    
  ##  Function prototypes
  proc H5Gcreate1*(loc_id: hid_t; name: cstring; size_hint: csize): hid_t {.cdecl,
      importc: "H5Gcreate1", dynlib: libname.}
  proc H5Gopen1*(loc_id: hid_t; name: cstring): hid_t {.cdecl, importc: "H5Gopen1",
      dynlib: libname.}

  when not declared(H5Glink):
    # for some reason these two functions are supposedly already defined?
    proc H5Glink*(cur_loc_id: hid_t; `type`: H5G_link_t; cur_name: cstring; new_name: cstring):
                herr_t {.cdecl, importc: "H5Glink", dynlib: libname.}
    proc H5Glink2*(cur_loc_id: hid_t; cur_name: cstring; `type`: H5G_link_t; new_loc_id: hid_t; new_name: cstring):
                 herr_t {.cdecl, importc: "H5Glink2", dynlib: libname.}
  else:
    echo H5Glink
  proc H5Gmove*(src_loc_id: hid_t; src_name: cstring; dst_name: cstring): herr_t {.
      cdecl, importc: "H5Gmove", dynlib: libname.}
  proc H5Gmove2*(src_loc_id: hid_t; src_name: cstring; dst_loc_id: hid_t;
                dst_name: cstring): herr_t {.cdecl, importc: "H5Gmove2",
      dynlib: libname.}
  proc H5Gunlink*(loc_id: hid_t; name: cstring): herr_t {.cdecl, importc: "H5Gunlink",
      dynlib: libname.}
  proc H5Gget_linkval*(loc_id: hid_t; name: cstring; size: csize; buf: cstring): herr_t {.
      cdecl, importc: "H5Gget_linkval", dynlib: libname.}
    ## out
  proc H5Gset_comment*(loc_id: hid_t; name: cstring; comment: cstring): herr_t {.cdecl,
      importc: "H5Gset_comment", dynlib: libname.}
  proc H5Gget_comment*(loc_id: hid_t; name: cstring; bufsize: csize; buf: cstring): cint {.
      cdecl, importc: "H5Gget_comment", dynlib: libname.}
  proc H5Giterate*(loc_id: hid_t; name: cstring; idx: ptr cint; op: H5G_iterate_t;
                  op_data: pointer): herr_t {.cdecl, importc: "H5Giterate",
      dynlib: libname.}
  proc H5Gget_num_objs*(loc_id: hid_t; num_objs: ptr hsize_t): herr_t {.cdecl,
      importc: "H5Gget_num_objs", dynlib: libname.}
  proc H5Gget_objinfo*(loc_id: hid_t; name: cstring; follow_link: hbool_t; statbuf: ptr H5G_stat_t): herr_t {.
      cdecl, importc: "H5Gget_objinfo", dynlib: libname.}
    ## out
  proc H5Gget_objname_by_idx*(loc_id: hid_t; idx: hsize_t; name: cstring; size: csize): ssize_t {.
      cdecl, importc: "H5Gget_objname_by_idx", dynlib: libname.}
  proc H5Gget_objtype_by_idx*(loc_id: hid_t; idx: hsize_t): H5G_obj_t {.cdecl,
      importc: "H5Gget_objtype_by_idx", dynlib: libname.}
