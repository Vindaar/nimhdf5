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
  const
    libname_hl* = "libhdf5_hl.so"

proc H5IMmake_image_8bit*(loc_id: hid_t; dset_name: cstring; width: hsize_t;
                         height: hsize_t; buffer: ptr cuchar): herr_t {.cdecl,
    importc: "H5IMmake_image_8bit", dynlib: libname_hl.}
proc H5IMmake_image_24bit*(loc_id: hid_t; dset_name: cstring; width: hsize_t;
                          height: hsize_t; interlace: cstring; buffer: ptr cuchar): herr_t {.
    cdecl, importc: "H5IMmake_image_24bit", dynlib: libname_hl.}
proc H5IMget_image_info*(loc_id: hid_t; dset_name: cstring; width: ptr hsize_t;
                        height: ptr hsize_t; planes: ptr hsize_t; interlace: cstring;
                        npals: ptr hssize_t): herr_t {.cdecl,
    importc: "H5IMget_image_info", dynlib: libname_hl.}
proc H5IMread_image*(loc_id: hid_t; dset_name: cstring; buffer: ptr cuchar): herr_t {.
    cdecl, importc: "H5IMread_image", dynlib: libname_hl.}
proc H5IMmake_palette*(loc_id: hid_t; pal_name: cstring; pal_dims: ptr hsize_t;
                      pal_data: ptr cuchar): herr_t {.cdecl,
    importc: "H5IMmake_palette", dynlib: libname_hl.}
proc H5IMlink_palette*(loc_id: hid_t; image_name: cstring; pal_name: cstring): herr_t {.
    cdecl, importc: "H5IMlink_palette", dynlib: libname_hl.}
proc H5IMunlink_palette*(loc_id: hid_t; image_name: cstring; pal_name: cstring): herr_t {.
    cdecl, importc: "H5IMunlink_palette", dynlib: libname_hl.}
proc H5IMget_npalettes*(loc_id: hid_t; image_name: cstring; npals: ptr hssize_t): herr_t {.
    cdecl, importc: "H5IMget_npalettes", dynlib: libname_hl.}
proc H5IMget_palette_info*(loc_id: hid_t; image_name: cstring; pal_number: cint;
                          pal_dims: ptr hsize_t): herr_t {.cdecl,
    importc: "H5IMget_palette_info", dynlib: libname_hl.}
proc H5IMget_palette*(loc_id: hid_t; image_name: cstring; pal_number: cint;
                     pal_data: ptr cuchar): herr_t {.cdecl,
    importc: "H5IMget_palette", dynlib: libname_hl.}
proc H5IMis_image*(loc_id: hid_t; dset_name: cstring): herr_t {.cdecl,
    importc: "H5IMis_image", dynlib: libname_hl.}
proc H5IMis_palette*(loc_id: hid_t; dset_name: cstring): herr_t {.cdecl,
    importc: "H5IMis_palette", dynlib: libname_hl.}
