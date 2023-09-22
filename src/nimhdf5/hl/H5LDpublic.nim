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

proc H5LDget_dset_dims*(did: hid_t; cur_dims: ptr hsize_t): herr_t {.cdecl,
    importc: "H5LDget_dset_dims", dynlib: libname_hl.}
proc H5LDget_dset_type_size*(did: hid_t; fields: cstring): csize_t {.cdecl,
    importc: "H5LDget_dset_type_size", dynlib: libname_hl.}
proc H5LDget_dset_elmts*(did: hid_t; prev_dims: ptr hsize_t; cur_dims: ptr hsize_t;
                        fields: cstring; buf: pointer): herr_t {.cdecl,
    importc: "H5LDget_dset_elmts", dynlib: libname_hl.}
