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
##  Create functions
##
## -------------------------------------------------------------------------
##

proc H5TBmake_table*(table_title: cstring; loc_id: hid_t; dset_name: cstring;
                    nfields: hsize_t; nrecords: hsize_t; type_size: csize_t;
                    field_names: ptr cstring; field_offset: ptr csize_t;
                    field_types: ptr hid_t; chunk_size: hsize_t; fill_data: pointer;
                    compress: cint; buf: pointer): herr_t {.cdecl,
    importc: "H5TBmake_table", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##
##  Write functions
##
## -------------------------------------------------------------------------
##

proc H5TBappend_records*(loc_id: hid_t; dset_name: cstring; nrecords: hsize_t;
                        type_size: csize_t; field_offset: ptr csize_t;
                        dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBappend_records", dynlib: libname_hl.}
proc H5TBwrite_records*(loc_id: hid_t; dset_name: cstring; start: hsize_t;
                       nrecords: hsize_t; type_size: csize_t; field_offset: ptr csize_t;
                       dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBwrite_records", dynlib: libname_hl.}
proc H5TBwrite_fields_name*(loc_id: hid_t; dset_name: cstring; field_names: cstring;
                           start: hsize_t; nrecords: hsize_t; type_size: csize_t;
                           field_offset: ptr csize_t; dst_sizes: ptr csize_t; buf: pointer): herr_t {.
    cdecl, importc: "H5TBwrite_fields_name", dynlib: libname_hl.}
proc H5TBwrite_fields_index*(loc_id: hid_t; dset_name: cstring; nfields: hsize_t;
                            field_index: ptr cint; start: hsize_t; nrecords: hsize_t;
                            type_size: csize_t; field_offset: ptr csize_t;
                            dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBwrite_fields_index", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##
##  Read functions
##
## -------------------------------------------------------------------------
##

proc H5TBread_table*(loc_id: hid_t; dset_name: cstring; dst_size: csize_t;
                    dst_offset: ptr csize_t; dst_sizes: ptr csize_t; dst_buf: pointer): herr_t {.
    cdecl, importc: "H5TBread_table", dynlib: libname_hl.}
proc H5TBread_fields_name*(loc_id: hid_t; dset_name: cstring; field_names: cstring;
                          start: hsize_t; nrecords: hsize_t; type_size: csize_t;
                          field_offset: ptr csize_t; dst_sizes: ptr csize_t; buf: pointer): herr_t {.
    cdecl, importc: "H5TBread_fields_name", dynlib: libname_hl.}
proc H5TBread_fields_index*(loc_id: hid_t; dset_name: cstring; nfields: hsize_t;
                           field_index: ptr cint; start: hsize_t; nrecords: hsize_t;
                           type_size: csize_t; field_offset: ptr csize_t;
                           dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBread_fields_index", dynlib: libname_hl.}
proc H5TBread_records*(loc_id: hid_t; dset_name: cstring; start: hsize_t;
                      nrecords: hsize_t; type_size: csize_t; dst_offset: ptr csize_t;
                      dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBread_records", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##
##  Inquiry functions
##
## -------------------------------------------------------------------------
##

proc H5TBget_table_info*(loc_id: hid_t; dset_name: cstring; nfields: ptr hsize_t;
                        nrecords: ptr hsize_t): herr_t {.cdecl,
    importc: "H5TBget_table_info", dynlib: libname_hl.}
proc H5TBget_field_info*(loc_id: hid_t; dset_name: cstring; field_names: ptr cstring;
                        field_sizes: ptr csize_t; field_offsets: ptr csize_t;
                        type_size: ptr csize_t): herr_t {.cdecl,
    importc: "H5TBget_field_info", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##
##  Manipulation functions
##
## -------------------------------------------------------------------------
##

proc H5TBdelete_record*(loc_id: hid_t; dset_name: cstring; start: hsize_t;
                       nrecords: hsize_t): herr_t {.cdecl,
    importc: "H5TBdelete_record", dynlib: libname_hl.}
proc H5TBinsert_record*(loc_id: hid_t; dset_name: cstring; start: hsize_t;
                       nrecords: hsize_t; dst_size: csize_t_t; dst_offset: ptr csize_t_t;
                       dst_sizes: ptr csize_t; buf: pointer): herr_t {.cdecl,
    importc: "H5TBinsert_record", dynlib: libname_hl.}
proc H5TBadd_records_from*(loc_id: hid_t; dset_name1: cstring; start1: hsize_t;
                          nrecords: hsize_t; dset_name2: cstring; start2: hsize_t): herr_t {.
    cdecl, importc: "H5TBadd_records_from", dynlib: libname_hl.}
proc H5TBcombine_tables*(loc_id1: hid_t; dset_name1: cstring; loc_id2: hid_t;
                        dset_name2: cstring; dset_name3: cstring): herr_t {.cdecl,
    importc: "H5TBcombine_tables", dynlib: libname_hl.}
proc H5TBinsert_field*(loc_id: hid_t; dset_name: cstring; field_name: cstring;
                      field_type: hid_t; position: hsize_t; fill_data: pointer;
                      buf: pointer): herr_t {.cdecl, importc: "H5TBinsert_field",
    dynlib: libname_hl.}
proc H5TBdelete_field*(loc_id: hid_t; dset_name: cstring; field_name: cstring): herr_t {.
    cdecl, importc: "H5TBdelete_field", dynlib: libname_hl.}
## -------------------------------------------------------------------------
##
##  Table attribute functions
##
## -------------------------------------------------------------------------
##

proc H5TBAget_title*(loc_id: hid_t; table_title: cstring): herr_t {.cdecl,
    importc: "H5TBAget_title", dynlib: libname_hl.}
proc H5TBAget_fill*(loc_id: hid_t; dset_name: cstring; dset_id: hid_t;
                   dst_buf: ptr cuchar): htri_t {.cdecl, importc: "H5TBAget_fill",
    dynlib: libname_hl.}
