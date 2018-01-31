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
##  Create/Open/Close functions
## -------------------------------------------------------------------------
## 
##  NOTE: H5PTcreate is replacing H5PTcreate_fl for better name due to the
##    removal of H5PTcreate_vl.  H5PTcreate_fl may be retired in 1.8.19.

proc H5PTcreate*(loc_id: hid_t; dset_name: cstring; dtype_id: hid_t;
                chunk_size: hsize_t; plist_id: hid_t): hid_t {.cdecl,
    importc: "H5PTcreate", dynlib: libname_hl.}
proc H5PTopen*(loc_id: hid_t; dset_name: cstring): hid_t {.cdecl, importc: "H5PTopen",
    dynlib: libname_hl.}
proc H5PTclose*(table_id: hid_t): herr_t {.cdecl, importc: "H5PTclose", dynlib: libname_hl.}
##  This function may be removed from the packet table in release 1.8.19.

proc H5PTcreate_fl*(loc_id: hid_t; dset_name: cstring; dtype_id: hid_t;
                   chunk_size: hsize_t; compression: cint): hid_t {.cdecl,
    importc: "H5PTcreate_fl", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##  Write functions
## -------------------------------------------------------------------------
## 

proc H5PTappend*(table_id: hid_t; nrecords: csize; data: pointer): herr_t {.cdecl,
    importc: "H5PTappend", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##  Read functions
## -------------------------------------------------------------------------
## 

proc H5PTget_next*(table_id: hid_t; nrecords: csize; data: pointer): herr_t {.cdecl,
    importc: "H5PTget_next", dynlib: libname_hl.}
proc H5PTread_packets*(table_id: hid_t; start: hsize_t; nrecords: csize; data: pointer): herr_t {.
    cdecl, importc: "H5PTread_packets", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##  Inquiry functions
## -------------------------------------------------------------------------
## 

proc H5PTget_num_packets*(table_id: hid_t; nrecords: ptr hsize_t): herr_t {.cdecl,
    importc: "H5PTget_num_packets", dynlib: libname_hl.}
proc H5PTis_valid*(table_id: hid_t): herr_t {.cdecl, importc: "H5PTis_valid",
    dynlib: libname_hl.}
proc H5PTis_varlen*(table_id: hid_t): herr_t {.cdecl, importc: "H5PTis_varlen",
    dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Accessor functions
## 
## -------------------------------------------------------------------------
## 

proc H5PTget_dataset*(table_id: hid_t): hid_t {.cdecl, importc: "H5PTget_dataset",
    dynlib: libname_hl.}
proc H5PTget_type*(table_id: hid_t): hid_t {.cdecl, importc: "H5PTget_type",
    dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Packet Table "current index" functions
## 
## -------------------------------------------------------------------------
## 

proc H5PTcreate_index*(table_id: hid_t): herr_t {.cdecl, importc: "H5PTcreate_index",
    dynlib: libname_hl.}
proc H5PTset_index*(table_id: hid_t; pt_index: hsize_t): herr_t {.cdecl,
    importc: "H5PTset_index", dynlib: libname_hl.}
proc H5PTget_index*(table_id: hid_t; pt_index: ptr hsize_t): herr_t {.cdecl,
    importc: "H5PTget_index", dynlib: libname_hl.}
## -------------------------------------------------------------------------
## 
##  Memory Management functions
## 
## -------------------------------------------------------------------------
## 

proc H5PTfree_vlen_buff*(table_id: hid_t; bufflen: csize; buff: pointer): herr_t {.
    cdecl, importc: "H5PTfree_vlen_buff", dynlib: libname_hl.}
