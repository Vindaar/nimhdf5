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


## -------------------------------------------------------------------------
##
##  "Optimized dataset" routines.
##
## -------------------------------------------------------------------------
##

proc H5DOwrite_chunk*(dset_id: hid_t; dxpl_id: hid_t; filters: uint32_t;
                     offset: ptr hsize_t; data_size: csize_t; buf: pointer): herr_t {.
    cdecl, importc: "H5DOwrite_chunk", dynlib: libname_hl.}
proc H5DOappend*(dset_id: hid_t; dxpl_id: hid_t; axis: cuint; extension: csize_t;
                memtype: hid_t; buf: pointer): herr_t {.cdecl, importc: "H5DOappend",
    dynlib: libname_hl.}
