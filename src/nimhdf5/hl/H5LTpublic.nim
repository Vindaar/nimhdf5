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
when not declared(libname_hl):
  when defined(Windows):
    const
      libname_hl* = "hdf5_hl.dll"
  elif defined(MacOSX):
    const
      libname_hl* = "libhdf5_hl.dylib"
  else:
    const
      libname_hl* = "libhdf5_hl.so"

##  Flag definitions for H5LTopen_file_image()

const
  H5LT_FILE_IMAGE_OPEN_RW* = 0x00000001
  H5LT_FILE_IMAGE_DONT_COPY* = 0x00000002

##  user supplied image buffer. The same image is open with the core driver.

const
  H5LT_FILE_IMAGE_DONT_RELEASE* = 0x00000004

##  deallocate user supplied image buffer. The user application is reponsible
##  for doing so.

const
  H5LT_FILE_IMAGE_ALL* = 0x00000007

type
  H5LT_lang_t* {.size: sizeof(cint).} = enum
    H5LT_LANG_ERR = - 1,         ## this is the first
    H5LT_DDL = 0,               ## for DDL
    H5LT_C = 1,                 ## for C
    H5LT_FORTRAN = 2,           ## for Fortran
    H5LT_NO_LANG = 3


## -------------------------------------------------------------------------
## 
##  Make dataset functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTmake_dataset*(loc_id: hid_t; dset_name: cstring; rank: cint;
                      dims: ptr hsize_t; type_id: hid_t; buffer: pointer): herr_t {.
    cdecl, importc: "H5LTmake_dataset", dynlib: libname_hl.}
proc H5LTmake_dataset_char*(loc_id: hid_t; dset_name: cstring; rank: cint;
                           dims: ptr hsize_t; buffer: cstring): herr_t {.cdecl,
    importc: "H5LTmake_dataset_char", dynlib: libname_hl.}
proc H5LTmake_dataset_short*(loc_id: hid_t; dset_name: cstring; rank: cint;
                            dims: ptr hsize_t; buffer: ptr cshort): herr_t {.cdecl,
    importc: "H5LTmake_dataset_short", dynlib: libname_hl.}
proc H5LTmake_dataset_int*(loc_id: hid_t; dset_name: cstring; rank: cint;
                          dims: ptr hsize_t; buffer: ptr cint): herr_t {.cdecl,
    importc: "H5LTmake_dataset_int", dynlib: libname_hl.}
proc H5LTmake_dataset_long*(loc_id: hid_t; dset_name: cstring; rank: cint;
                           dims: ptr hsize_t; buffer: ptr clong): herr_t {.cdecl,
    importc: "H5LTmake_dataset_long", dynlib: libname_hl.}
proc H5LTmake_dataset_float*(loc_id: hid_t; dset_name: cstring; rank: cint;
                            dims: ptr hsize_t; buffer: ptr cfloat): herr_t {.cdecl,
    importc: "H5LTmake_dataset_float", dynlib: libname_hl.}
proc H5LTmake_dataset_double*(loc_id: hid_t; dset_name: cstring; rank: cint;
                             dims: ptr hsize_t; buffer: ptr cdouble): herr_t {.cdecl,
    importc: "H5LTmake_dataset_double", dynlib: libname_hl.}
proc H5LTmake_dataset_string*(loc_id: hid_t; dset_name: cstring; buf: cstring): herr_t {.
    cdecl, importc: "H5LTmake_dataset_string", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Read dataset functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTread_dataset*(loc_id: hid_t; dset_name: cstring; type_id: hid_t;
                      buffer: pointer): herr_t {.cdecl, importc: "H5LTread_dataset",
    dynlib: libname_hl.}
proc H5LTread_dataset_char*(loc_id: hid_t; dset_name: cstring; buffer: cstring): herr_t {.
    cdecl, importc: "H5LTread_dataset_char", dynlib: libname_hl.}
proc H5LTread_dataset_short*(loc_id: hid_t; dset_name: cstring; buffer: ptr cshort): herr_t {.
    cdecl, importc: "H5LTread_dataset_short", dynlib: libname_hl.}
proc H5LTread_dataset_int*(loc_id: hid_t; dset_name: cstring; buffer: ptr cint): herr_t {.
    cdecl, importc: "H5LTread_dataset_int", dynlib: libname_hl.}
proc H5LTread_dataset_long*(loc_id: hid_t; dset_name: cstring; buffer: ptr clong): herr_t {.
    cdecl, importc: "H5LTread_dataset_long", dynlib: libname_hl.}
proc H5LTread_dataset_float*(loc_id: hid_t; dset_name: cstring; buffer: ptr cfloat): herr_t {.
    cdecl, importc: "H5LTread_dataset_float", dynlib: libname_hl.}
proc H5LTread_dataset_double*(loc_id: hid_t; dset_name: cstring; buffer: ptr cdouble): herr_t {.
    cdecl, importc: "H5LTread_dataset_double", dynlib: libname_hl.}
proc H5LTread_dataset_string*(loc_id: hid_t; dset_name: cstring; buf: cstring): herr_t {.
    cdecl, importc: "H5LTread_dataset_string", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Query dataset functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTget_dataset_ndims*(loc_id: hid_t; dset_name: cstring; rank: ptr cint): herr_t {.
    cdecl, importc: "H5LTget_dataset_ndims", dynlib: libname_hl.}
proc H5LTget_dataset_info*(loc_id: hid_t; dset_name: cstring; dims: ptr hsize_t;
                          type_class: ptr H5T_class_t; type_size: ptr csize): herr_t {.
    cdecl, importc: "H5LTget_dataset_info", dynlib: libname_hl.}
proc H5LTfind_dataset*(loc_id: hid_t; name: cstring): herr_t {.cdecl,
    importc: "H5LTfind_dataset", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Set attribute functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTset_attribute_string*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              attr_data: cstring): herr_t {.cdecl,
    importc: "H5LTset_attribute_string", dynlib: libname_hl.}
proc H5LTset_attribute_char*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            buffer: cstring; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_char", dynlib: libname_hl.}
proc H5LTset_attribute_uchar*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             buffer: ptr cuchar; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_uchar", dynlib: libname_hl.}
proc H5LTset_attribute_short*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             buffer: ptr cshort; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_short", dynlib: libname_hl.}
proc H5LTset_attribute_ushort*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              buffer: ptr cushort; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_ushort", dynlib: libname_hl.}
proc H5LTset_attribute_int*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                           buffer: ptr cint; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_int", dynlib: libname_hl.}
proc H5LTset_attribute_uint*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            buffer: ptr cuint; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_uint", dynlib: libname_hl.}
proc H5LTset_attribute_long*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            buffer: ptr clong; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_long", dynlib: libname_hl.}
proc H5LTset_attribute_long_long*(loc_id: hid_t; obj_name: cstring;
                                 attr_name: cstring; buffer: ptr clonglong;
                                 size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_long_long", dynlib: libname_hl.}
proc H5LTset_attribute_ulong*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             buffer: ptr culong; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_ulong", dynlib: libname_hl.}
proc H5LTset_attribute_float*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             buffer: ptr cfloat; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_float", dynlib: libname_hl.}
proc H5LTset_attribute_double*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              buffer: ptr cdouble; size: csize): herr_t {.cdecl,
    importc: "H5LTset_attribute_double", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Get attribute functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTget_attribute*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                       mem_type_id: hid_t; data: pointer): herr_t {.cdecl,
    importc: "H5LTget_attribute", dynlib: libname_hl.}
proc H5LTget_attribute_string*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              data: cstring): herr_t {.cdecl,
    importc: "H5LTget_attribute_string", dynlib: libname_hl.}
proc H5LTget_attribute_char*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            data: cstring): herr_t {.cdecl,
    importc: "H5LTget_attribute_char", dynlib: libname_hl.}
proc H5LTget_attribute_uchar*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             data: ptr cuchar): herr_t {.cdecl,
    importc: "H5LTget_attribute_uchar", dynlib: libname_hl.}
proc H5LTget_attribute_short*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             data: ptr cshort): herr_t {.cdecl,
    importc: "H5LTget_attribute_short", dynlib: libname_hl.}
proc H5LTget_attribute_ushort*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              data: ptr cushort): herr_t {.cdecl,
    importc: "H5LTget_attribute_ushort", dynlib: libname_hl.}
proc H5LTget_attribute_int*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                           data: ptr cint): herr_t {.cdecl,
    importc: "H5LTget_attribute_int", dynlib: libname_hl.}
proc H5LTget_attribute_uint*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            data: ptr cuint): herr_t {.cdecl,
    importc: "H5LTget_attribute_uint", dynlib: libname_hl.}
proc H5LTget_attribute_long*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            data: ptr clong): herr_t {.cdecl,
    importc: "H5LTget_attribute_long", dynlib: libname_hl.}
proc H5LTget_attribute_long_long*(loc_id: hid_t; obj_name: cstring;
                                 attr_name: cstring; data: ptr clonglong): herr_t {.
    cdecl, importc: "H5LTget_attribute_long_long", dynlib: libname_hl.}
proc H5LTget_attribute_ulong*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             data: ptr culong): herr_t {.cdecl,
    importc: "H5LTget_attribute_ulong", dynlib: libname_hl.}
proc H5LTget_attribute_float*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             data: ptr cfloat): herr_t {.cdecl,
    importc: "H5LTget_attribute_float", dynlib: libname_hl.}
proc H5LTget_attribute_double*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                              data: ptr cdouble): herr_t {.cdecl,
    importc: "H5LTget_attribute_double", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Query attribute functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTget_attribute_ndims*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                             rank: ptr cint): herr_t {.cdecl,
    importc: "H5LTget_attribute_ndims", dynlib: libname_hl.}
proc H5LTget_attribute_info*(loc_id: hid_t; obj_name: cstring; attr_name: cstring;
                            dims: ptr hsize_t; type_class: ptr H5T_class_t;
                            type_size: ptr csize): herr_t {.cdecl,
    importc: "H5LTget_attribute_info", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  General functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTtext_to_dtype*(text: cstring; lang_type: H5LT_lang_t): hid_t {.cdecl,
    importc: "H5LTtext_to_dtype", dynlib: libname_hl.}
proc H5LTdtype_to_text*(dtype: hid_t; str: cstring; lang_type: H5LT_lang_t;
                       len: ptr csize): herr_t {.cdecl, importc: "H5LTdtype_to_text",
    dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Utility functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTfind_attribute*(loc_id: hid_t; name: cstring): herr_t {.cdecl,
    importc: "H5LTfind_attribute", dynlib: libname_hl.}
proc H5LTpath_valid*(loc_id: hid_t; path: cstring; check_object_valid: hbool_t): htri_t {.
    cdecl, importc: "H5LTpath_valid", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  File image operations functions
## 
## -------------------------------------------------------------------------
## 

proc H5LTopen_file_image*(buf_ptr: pointer; buf_size: csize; flags: cuint): hid_t {.
    cdecl, importc: "H5LTopen_file_image", dynlib: libname_hl.}
