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
##  This file contains public declarations for the H5R module.
##

##  Public headers needed by this file

import
  H5public,
  H5Gpublic,
  H5Opublic,
  ../H5nimtypes, ../h5libname


##
##  Reference types allowed.
##

type
  H5R_type_t* {.size: sizeof(cint).} = enum
    H5R_BADTYPE = - 1,           ## invalid Reference Type
    H5R_OBJECT,               ## Object reference
    H5R_DATASET_REGION,       ## Dataset Region Reference
    H5R_MAXTYPE               ## highest type (Invalid as true type)


##  Note! Be careful with the sizes of the references because they should really
##  depend on the run-time values in the file.  Unfortunately, the arrays need
##  to be defined at compile-time, so we have to go with the worst case sizes for
##  them.  -QAK
##

const
  H5R_OBJ_REF_BUF_SIZE* = sizeof((haddr_t))

##  Object reference structure for user's code

type
  hobj_ref_t* = haddr_t

##  Needs to be large enough to store largest haddr_t in a worst case machine (ie. 8 bytes currently)

const
  H5R_DSET_REG_REF_BUF_SIZE* = (sizeof((haddr_t)) + 4)

##  4 is used instead of sizeof(int) to permit portability between
##    the Crays and other machines (the heap ID is always encoded as an int32 anyway)
##
##  Dataset Region reference structure for user's code

type
  hdset_reg_ref_t* = array[H5R_DSET_REG_REF_BUF_SIZE, char]

##  Buffer to store heap ID and index
##  Needs to be large enough to store largest haddr_t in a worst case machine (ie. 8 bytes currently) plus an int
##  Publicly visible data structures

##  Functions in H5R.c

proc H5Rcreate*(`ref`: pointer; loc_id: hid_t; name: cstring; ref_type: H5R_type_t;
               space_id: hid_t): herr_t {.cdecl, importc: "H5Rcreate", dynlib: libname.}
proc H5Rdereference2*(obj_id: hid_t; oapl_id: hid_t; ref_type: H5R_type_t;
                     `ref`: pointer): hid_t {.cdecl, importc: "H5Rdereference2",
    dynlib: libname.}
proc H5Rget_region*(dataset: hid_t; ref_type: H5R_type_t; `ref`: pointer): hid_t {.
    cdecl, importc: "H5Rget_region", dynlib: libname.}
proc H5Rget_obj_type2*(id: hid_t; ref_type: H5R_type_t; `ref`: pointer;
                      obj_type: ptr H5O_type_t): herr_t {.cdecl,
    importc: "H5Rget_obj_type2", dynlib: libname.}
proc H5Rget_name*(loc_id: hid_t; ref_type: H5R_type_t; `ref`: pointer; name: cstring; ## out
                 size: csize_t): ssize_t {.cdecl, importc: "H5Rget_name",
                                      dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  Typedefs
  ##  Function prototypes
  proc H5Rget_obj_type1*(id: hid_t; ref_type: H5R_type_t; `ref`: pointer): H5G_obj_t {.
      cdecl, importc: "H5Rget_obj_type1", dynlib: libname.}
  proc H5Rdereference1*(obj_id: hid_t; ref_type: H5R_type_t; `ref`: pointer): hid_t {.
      cdecl, importc: "H5Rdereference1", dynlib: libname.}
