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
##  This file contains function prototypes for each exported function in
##  the H5I module.
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
##  Library type values.  Start with `1' instead of `0' because it makes the
##  tracing output look better when hid_t values are large numbers.  Change the
##  TYPE_BITS in H5I.c if the MAXID gets larger than 32 (an assertion will
##  fail otherwise).
## 
##  When adding types here, add a section to the 'misc19' test in test/tmisc.c
##  to verify that the H5I{inc|dec|get}_ref() routines work correctly with in.
## 
## 

type
  H5I_type_t* {.size: sizeof(cint).} = enum
    H5I_UNINIT = (- 2),          ## uninitialized type
    H5I_BADID = (- 1),           ## invalid Type
    H5I_FILE = 1,               ## type ID for File objects
    H5I_GROUP,                ## type ID for Group objects
    H5I_DATATYPE,             ## type ID for Datatype objects
    H5I_DATASPACE,            ## type ID for Dataspace objects
    H5I_DATASET,              ## type ID for Dataset objects
    H5I_ATTR,                 ## type ID for Attribute objects
    H5I_REFERENCE,            ## type ID for Reference objects
    H5I_VFL,                  ## type ID for virtual file layer
    H5I_GENPROP_CLS,          ## type ID for generic property list classes
    H5I_GENPROP_LST,          ## type ID for generic property lists
    H5I_ERROR_CLASS,          ## type ID for error classes
    H5I_ERROR_MSG,            ## type ID for error messages
    H5I_ERROR_STACK,          ## type ID for error stacks
    H5I_NTYPES                ## number of library types, MUST BE LAST!


##  Type of atoms to return to users

# type
#   hid_t* = clonglong
#   time_t* = clong
#   hbool_t* = bool

const H5_SIZEOF_INT64_T = sizeof(clonglong)
const
  H5_SIZEOF_HID_T* = H5_SIZEOF_INT64_T

##  An invalid object ID. This is also negative for error return.

const
  H5I_INVALID_HID* = (- 1)

## 
##  Function for freeing objects. This function will be called with an object
##  ID type number and a pointer to the object. The function should free the
##  object and return non-negative to indicate that the object
##  can be removed from the ID type. If the function returns negative
##  (failure) then the object will remain in the ID type.
## 

type
  H5I_free_t* = proc (a2: pointer): herr_t {.cdecl.}

##  Type of the function to compare objects & keys

type
  H5I_search_func_t* = proc (obj: pointer; id: hid_t; key: pointer): cint {.cdecl.}

##  Public API functions

proc H5Iregister*(`type`: H5I_type_t; `object`: pointer): hid_t {.cdecl,
    importc: "H5Iregister", dynlib: libname.}
proc H5Iobject_verify*(id: hid_t; id_type: H5I_type_t): pointer {.cdecl,
    importc: "H5Iobject_verify", dynlib: libname.}
proc H5Iremove_verify*(id: hid_t; id_type: H5I_type_t): pointer {.cdecl,
    importc: "H5Iremove_verify", dynlib: libname.}
proc H5Iget_type*(id: hid_t): H5I_type_t {.cdecl, importc: "H5Iget_type",
                                       dynlib: libname.}
proc H5Iget_file_id*(id: hid_t): hid_t {.cdecl, importc: "H5Iget_file_id",
                                     dynlib: libname.}
proc H5Iget_name*(id: hid_t; name: cstring; ## out
                 size: csize): ssize_t {.cdecl, importc: "H5Iget_name",
                                      dynlib: libname.}
proc H5Iinc_ref*(id: hid_t): cint {.cdecl, importc: "H5Iinc_ref", dynlib: libname.}
proc H5Idec_ref*(id: hid_t): cint {.cdecl, importc: "H5Idec_ref", dynlib: libname.}
proc H5Iget_ref*(id: hid_t): cint {.cdecl, importc: "H5Iget_ref", dynlib: libname.}
proc H5Iregister_type*(hash_size: csize; reserved: cuint; free_func: H5I_free_t): H5I_type_t {.
    cdecl, importc: "H5Iregister_type", dynlib: libname.}
proc H5Iclear_type*(`type`: H5I_type_t; force: hbool_t): herr_t {.cdecl,
    importc: "H5Iclear_type", dynlib: libname.}
proc H5Idestroy_type*(`type`: H5I_type_t): herr_t {.cdecl,
    importc: "H5Idestroy_type", dynlib: libname.}
proc H5Iinc_type_ref*(`type`: H5I_type_t): cint {.cdecl, importc: "H5Iinc_type_ref",
    dynlib: libname.}
proc H5Idec_type_ref*(`type`: H5I_type_t): cint {.cdecl, importc: "H5Idec_type_ref",
    dynlib: libname.}
proc H5Iget_type_ref*(`type`: H5I_type_t): cint {.cdecl, importc: "H5Iget_type_ref",
    dynlib: libname.}
proc H5Isearch*(`type`: H5I_type_t; `func`: H5I_search_func_t; key: pointer): pointer {.
    cdecl, importc: "H5Isearch", dynlib: libname.}
proc H5Inmembers*(`type`: H5I_type_t; num_members: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Inmembers", dynlib: libname.}
proc H5Itype_exists*(`type`: H5I_type_t): htri_t {.cdecl, importc: "H5Itype_exists",
    dynlib: libname.}
proc H5Iis_valid*(id: hid_t): htri_t {.cdecl, importc: "H5Iis_valid", dynlib: libname.}
