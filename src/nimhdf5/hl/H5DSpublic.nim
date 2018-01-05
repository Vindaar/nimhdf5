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

const
  DIMENSION_SCALE_CLASS* = "DIMENSION_SCALE"
  DIMENSION_LIST* = "DIMENSION_LIST"
  REFERENCE_LIST* = "REFERENCE_LIST"
  DIMENSION_LABELS* = "DIMENSION_LABELS"

type
  H5DS_iterate_t* = proc (dset: hid_t; dim: cuint; scale: hid_t; visitor_data: pointer): herr_t {.
      cdecl.}

proc H5DSattach_scale*(did: hid_t; dsid: hid_t; idx: cuint): herr_t {.cdecl,
    importc: "H5DSattach_scale", dynlib: libname_hl.}
proc H5DSdetach_scale*(did: hid_t; dsid: hid_t; idx: cuint): herr_t {.cdecl,
    importc: "H5DSdetach_scale", dynlib: libname_hl.}
proc H5DSset_scale*(dsid: hid_t; dimname: cstring): herr_t {.cdecl,
    importc: "H5DSset_scale", dynlib: libname_hl.}
proc H5DSget_num_scales*(did: hid_t; dim: cuint): cint {.cdecl,
    importc: "H5DSget_num_scales", dynlib: libname_hl.}
proc H5DSset_label*(did: hid_t; idx: cuint; label: cstring): herr_t {.cdecl,
    importc: "H5DSset_label", dynlib: libname_hl.}
proc H5DSget_label*(did: hid_t; idx: cuint; label: cstring; size: csize): ssize_t {.cdecl,
    importc: "H5DSget_label", dynlib: libname_hl.}
proc H5DSget_scale_name*(did: hid_t; name: cstring; size: csize): ssize_t {.cdecl,
    importc: "H5DSget_scale_name", dynlib: libname_hl.}
proc H5DSis_scale*(did: hid_t): htri_t {.cdecl, importc: "H5DSis_scale",
                                     dynlib: libname_hl.}
proc H5DSiterate_scales*(did: hid_t; dim: cuint; idx: ptr cint; visitor: H5DS_iterate_t;
                        visitor_data: pointer): herr_t {.cdecl,
    importc: "H5DSiterate_scales", dynlib: libname_hl.}
proc H5DSis_attached*(did: hid_t; dsid: hid_t; idx: cuint): htri_t {.cdecl,
    importc: "H5DSis_attached", dynlib: libname_hl.}
