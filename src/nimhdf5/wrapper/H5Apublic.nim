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

##
##  This file contains public declarations for the H5A module.
##

##  Public headers needed by this file
import
  H5public,
  H5Opublic,                  ##  Object Headers
  H5Tpublic,
  ../H5nimtypes, ../h5libname


##  Datatypes
##  Information struct for attribute (for H5Aget_info/H5Aget_info_by_idx)

type
  H5A_info_t* = object
    corder_valid*: hbool_t     ##  Indicate if creation order is valid
    corder*: H5O_msg_crt_idx_t ##  Creation order
    cset*: H5T_cset_t          ##  Character set of attribute name
    data_size*: hsize_t        ##  Size of raw data


##  Typedef for H5Aiterate2() callbacks

type
  H5A_operator2_t* = proc (location_id: hid_t; ## in
                        attr_name: cstring; ## in
                        ainfo: ptr H5A_info_t; ## in
                        op_data: pointer): herr_t {.cdecl.} ## in,out

##  Public function prototypes

proc H5Acreate2*(loc_id: hid_t; attr_name: cstring; type_id: hid_t; space_id: hid_t;
                acpl_id: hid_t; aapl_id: hid_t): hid_t {.cdecl, importc: "H5Acreate2",
    dynlib: libname.}
proc H5Acreate_by_name*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                       type_id: hid_t; space_id: hid_t; acpl_id: hid_t;
                       aapl_id: hid_t; lapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Acreate_by_name", dynlib: libname.}
proc H5Aopen*(obj_id: hid_t; attr_name: cstring; aapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Aopen", dynlib: libname.}
proc H5Aopen_by_name*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                     aapl_id: hid_t; lapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Aopen_by_name", dynlib: libname.}
proc H5Aopen_by_idx*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                    order: H5_iter_order_t; n: hsize_t; aapl_id: hid_t; lapl_id: hid_t): hid_t {.
    cdecl, importc: "H5Aopen_by_idx", dynlib: libname.}
proc H5Awrite*(attr_id: hid_t; type_id: hid_t; buf: pointer): herr_t {.cdecl,
    importc: "H5Awrite", dynlib: libname.}
proc H5Aread*(attr_id: hid_t; type_id: hid_t; buf: pointer): herr_t {.cdecl,
    importc: "H5Aread", dynlib: libname.}
proc H5Aclose*(attr_id: hid_t): herr_t {.cdecl, importc: "H5Aclose", dynlib: libname.}
proc H5Aget_space*(attr_id: hid_t): hid_t {.cdecl, importc: "H5Aget_space",
                                        dynlib: libname.}
proc H5Aget_type*(attr_id: hid_t): hid_t {.cdecl, importc: "H5Aget_type",
                                       dynlib: libname.}
proc H5Aget_create_plist*(attr_id: hid_t): hid_t {.cdecl,
    importc: "H5Aget_create_plist", dynlib: libname.}
proc H5Aget_name*(attr_id: hid_t; buf_size: csize_t; buf: cstring): ssize_t {.cdecl,
    importc: "H5Aget_name", dynlib: libname.}
proc H5Aget_name_by_idx*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; n: hsize_t; name: cstring; ## out
                        size: csize_t; lapl_id: hid_t): ssize_t {.cdecl,
    importc: "H5Aget_name_by_idx", dynlib: libname.}
proc H5Aget_storage_size*(attr_id: hid_t): hsize_t {.cdecl,
    importc: "H5Aget_storage_size", dynlib: libname.}
proc H5Aget_info*(attr_id: hid_t; ainfo: ptr H5A_info_t): herr_t {.cdecl,
    importc: "H5Aget_info", dynlib: libname.}
  ## out
proc H5Aget_info_by_name*(loc_id: hid_t; obj_name: cstring; attr_name: cstring; ainfo: ptr H5A_info_t; ## out
                         lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Aget_info_by_name", dynlib: libname.}
proc H5Aget_info_by_idx*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; n: hsize_t; ainfo: ptr H5A_info_t; ## out
                        lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Aget_info_by_idx", dynlib: libname.}
proc H5Arename*(loc_id: hid_t; old_name: cstring; new_name: cstring): herr_t {.cdecl,
    importc: "H5Arename", dynlib: libname.}
proc H5Arename_by_name*(loc_id: hid_t; obj_name: cstring; old_attr_name: cstring;
                       new_attr_name: cstring; lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Arename_by_name", dynlib: libname.}
proc H5Aiterate2*(loc_id: hid_t; idx_type: H5_index_t; order: H5_iter_order_t;
                 idx: ptr hsize_t; op: H5A_operator2_t; op_data: pointer): herr_t {.
    cdecl, importc: "H5Aiterate2", dynlib: libname.}
proc H5Aiterate_by_name*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                        order: H5_iter_order_t; idx: ptr hsize_t;
                        op: H5A_operator2_t; op_data: pointer; lapd_id: hid_t): herr_t {.
    cdecl, importc: "H5Aiterate_by_name", dynlib: libname.}
proc H5Adelete*(loc_id: hid_t; name: cstring): herr_t {.cdecl, importc: "H5Adelete",
    dynlib: libname.}
proc H5Adelete_by_name*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                       lapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Adelete_by_name", dynlib: libname.}
proc H5Adelete_by_idx*(loc_id: hid_t; obj_name: cstring; idx_type: H5_index_t;
                      order: H5_iter_order_t; n: hsize_t; lapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Adelete_by_idx", dynlib: libname.}
proc H5Aexists*(obj_id: hid_t; attr_name: cstring): htri_t {.cdecl,
    importc: "H5Aexists", dynlib: libname.}
proc H5Aexists_by_name*(obj_id: hid_t; obj_name: cstring; attr_name: cstring;
                       lapl_id: hid_t): htri_t {.cdecl,
    importc: "H5Aexists_by_name", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  Typedefs
  ##  Typedef for H5Aiterate1() callbacks
  type
    H5A_operator1_t* = proc (location_id: hid_t; ## in
                          attr_name: cstring; ## in
                          operator_data: pointer): herr_t {.cdecl.} ## in,out
  ##  Function prototypes
  proc H5Acreate1*(loc_id: hid_t; name: cstring; type_id: hid_t; space_id: hid_t;
                  acpl_id: hid_t): hid_t {.cdecl, importc: "H5Acreate1",
                                        dynlib: libname.}
  proc H5Aopen_name*(loc_id: hid_t; name: cstring): hid_t {.cdecl,
      importc: "H5Aopen_name", dynlib: libname.}
  proc H5Aopen_idx*(loc_id: hid_t; idx: cuint): hid_t {.cdecl, importc: "H5Aopen_idx",
      dynlib: libname.}
  proc H5Aget_num_attrs*(loc_id: hid_t): cint {.cdecl, importc: "H5Aget_num_attrs",
      dynlib: libname.}
  proc H5Aiterate1*(loc_id: hid_t; attr_num: ptr cuint; op: H5A_operator1_t;
                   op_data: pointer): herr_t {.cdecl, importc: "H5Aiterate1",
      dynlib: libname.}
