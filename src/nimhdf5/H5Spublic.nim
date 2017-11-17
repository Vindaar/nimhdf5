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
##  This file contains public declarations for the H5S module.
## 

##  Public headers needed by this file

import
  H5public, H5Ipublic, H5nimtypes

when not declared(libname):
  const
    libname* = "libhdf5.so"  

##  Define atomic datatypes

const
  # define HSIZE_UNDEF similar to C code as:
  # #define HSIZE_UNDEF             ((hsize_t)(hssize_t)(-1))
  HSIZE_UNDEF = hsize_t(-1)
  H5S_ALL* = hid_t(0)
  H5S_UNLIMITED* = HSIZE_UNDEF

##  Define user-level maximum number of dimensions

const
  H5S_MAX_RANK* = 32

##  Different types of dataspaces

type
  H5S_class_t* {.size: sizeof(cint).} = enum
    H5S_NO_CLASS = - 1,          ## error
    H5S_SCALAR = 0,             ## scalar variable
    H5S_SIMPLE = 1,             ## simple data space
    H5S_NULL = 2


##  Different ways of combining selections

type
  H5S_seloper_t* {.size: sizeof(cint).} = enum
    H5S_SELECT_NOOP = - 1,       ##  error
    H5S_SELECT_SET = 0,         ##  Select "set" operation
    H5S_SELECT_OR,            ##  Binary "or" operation for hyperslabs
                  ##  (add new selection to existing selection)
                  ##  Original region:  AAAAAAAAAA
                  ##  New region:             BBBBBBBBBB
                  ##  A or B:           CCCCCCCCCCCCCCCC
                  ## 
    H5S_SELECT_AND,           ##  Binary "and" operation for hyperslabs
                   ##  (only leave overlapped regions in selection)
                   ##  Original region:  AAAAAAAAAA
                   ##  New region:             BBBBBBBBBB
                   ##  A and B:                CCCC
                   ## 
    H5S_SELECT_XOR,           ##  Binary "xor" operation for hyperslabs
                   ##  (only leave non-overlapped regions in selection)
                   ##  Original region:  AAAAAAAAAA
                   ##  New region:             BBBBBBBBBB
                   ##  A xor B:          CCCCCC    CCCCCC
                   ## 
    H5S_SELECT_NOTB, ##  Binary "not" operation for hyperslabs
                    ##  (only leave non-overlapped regions in original selection)
                    ##  Original region:  AAAAAAAAAA
                    ##  New region:             BBBBBBBBBB
                    ##  A not B:          CCCCCC
                    ## 
    H5S_SELECT_NOTA, ##  Binary "not" operation for hyperslabs
                    ##  (only leave non-overlapped regions in new selection)
                    ##  Original region:  AAAAAAAAAA
                    ##  New region:             BBBBBBBBBB
                    ##  B not A:                    CCCCCC
                    ## 
    H5S_SELECT_APPEND,        ##  Append elements to end of point selection
    H5S_SELECT_PREPEND,       ##  Prepend elements to beginning of point selection
    H5S_SELECT_INVALID        ##  Invalid upper bound on selection operations


##  Enumerated type for the type of selection

type
  H5S_sel_type* {.size: sizeof(cint).} = enum
    H5S_SEL_ERROR = - 1,         ##  Error
    H5S_SEL_NONE = 0,           ##  Nothing selected
    H5S_SEL_POINTS = 1,         ##  Sequence of points selected
    H5S_SEL_HYPERSLABS = 2,     ##  "New-style" hyperslab selection defined
    H5S_SEL_ALL = 3,            ##  Entire extent selected
    H5S_SEL_N                 ## THIS MUST BE LAST


##  Functions in H5S.c

proc H5Screate*(`type`: H5S_class_t): hid_t {.cdecl, importc: "H5Screate",
    dynlib: libname.}
proc H5Screate_simple*(rank: cint; dims: ptr hsize_t; maxdims: ptr hsize_t): hid_t {.
    cdecl, importc: "H5Screate_simple", dynlib: libname.}
proc H5Sset_extent_simple*(space_id: hid_t; rank: cint; dims: ptr hsize_t;
                          max: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Sset_extent_simple", dynlib: libname.}
proc H5Scopy*(space_id: hid_t): hid_t {.cdecl, importc: "H5Scopy", dynlib: libname.}
proc H5Sclose*(space_id: hid_t): herr_t {.cdecl, importc: "H5Sclose", dynlib: libname.}
proc H5Sencode*(obj_id: hid_t; buf: pointer; nalloc: ptr csize): herr_t {.cdecl,
    importc: "H5Sencode", dynlib: libname.}
proc H5Sdecode*(buf: pointer): hid_t {.cdecl, importc: "H5Sdecode", dynlib: libname.}
proc H5Sget_simple_extent_npoints*(space_id: hid_t): hssize_t {.cdecl,
    importc: "H5Sget_simple_extent_npoints", dynlib: libname.}
proc H5Sget_simple_extent_ndims*(space_id: hid_t): cint {.cdecl,
    importc: "H5Sget_simple_extent_ndims", dynlib: libname.}
proc H5Sget_simple_extent_dims*(space_id: hid_t; dims: ptr hsize_t;
                               maxdims: ptr hsize_t): cint {.cdecl,
    importc: "H5Sget_simple_extent_dims", dynlib: libname.}
proc H5Sis_simple*(space_id: hid_t): htri_t {.cdecl, importc: "H5Sis_simple",
    dynlib: libname.}
proc H5Sget_select_npoints*(spaceid: hid_t): hssize_t {.cdecl,
    importc: "H5Sget_select_npoints", dynlib: libname.}
proc H5Sselect_hyperslab*(space_id: hid_t; op: H5S_seloper_t; start: ptr hsize_t;
                          stride: ptr hsize_t; count: ptr hsize_t; `block`: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Sselect_hyperslab", dynlib: libname.}
##  #define NEW_HYPERSLAB_API
##  Note that these haven't been working for a while and were never
##       publicly released - QAK

when defined(NEW_HYPERSLAB_API):
  proc H5Scombine_hyperslab*(space_id: hid_t; op: H5S_seloper_t; start: ptr hsize_t;
                            stride: ptr hsize_t; count: ptr hsize_t;
                            `block`: ptr hsize_t): hid_t {.cdecl,
      importc: "H5Scombine_hyperslab", dynlib: libname.}
  proc H5Sselect_select*(space1_id: hid_t; op: H5S_seloper_t; space2_id: hid_t): herr_t {.
      cdecl, importc: "H5Sselect_select", dynlib: libname.}
  proc H5Scombine_select*(space1_id: hid_t; op: H5S_seloper_t; space2_id: hid_t): hid_t {.
      cdecl, importc: "H5Scombine_select", dynlib: libname.}
proc H5Sselect_elements*(space_id: hid_t; op: H5S_seloper_t; num_elem: csize;
                        coord: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Sselect_elements", dynlib: libname.}
proc H5Sget_simple_extent_type*(space_id: hid_t): H5S_class_t {.cdecl,
    importc: "H5Sget_simple_extent_type", dynlib: libname.}
proc H5Sset_extent_none*(space_id: hid_t): herr_t {.cdecl,
    importc: "H5Sset_extent_none", dynlib: libname.}
proc H5Sextent_copy*(dst_id: hid_t; src_id: hid_t): herr_t {.cdecl,
    importc: "H5Sextent_copy", dynlib: libname.}
proc H5Sextent_equal*(sid1: hid_t; sid2: hid_t): htri_t {.cdecl,
    importc: "H5Sextent_equal", dynlib: libname.}
proc H5Sselect_all*(spaceid: hid_t): herr_t {.cdecl, importc: "H5Sselect_all",
    dynlib: libname.}
proc H5Sselect_none*(spaceid: hid_t): herr_t {.cdecl, importc: "H5Sselect_none",
    dynlib: libname.}
proc H5Soffset_simple*(space_id: hid_t; offset: ptr hssize_t): herr_t {.cdecl,
    importc: "H5Soffset_simple", dynlib: libname.}
proc H5Sselect_valid*(spaceid: hid_t): htri_t {.cdecl, importc: "H5Sselect_valid",
    dynlib: libname.}
proc H5Sis_regular_hyperslab*(spaceid: hid_t): htri_t {.cdecl,
    importc: "H5Sis_regular_hyperslab", dynlib: libname.}
proc H5Sget_regular_hyperslab*(spaceid: hid_t; start: ptr hsize_t;
                              stride: ptr hsize_t; count: ptr hsize_t;
                              `block`: ptr hsize_t): htri_t {.cdecl,
    importc: "H5Sget_regular_hyperslab", dynlib: libname.}
proc H5Sget_select_hyper_nblocks*(spaceid: hid_t): hssize_t {.cdecl,
    importc: "H5Sget_select_hyper_nblocks", dynlib: libname.}
proc H5Sget_select_elem_npoints*(spaceid: hid_t): hssize_t {.cdecl,
    importc: "H5Sget_select_elem_npoints", dynlib: libname.}
proc H5Sget_select_hyper_blocklist*(spaceid: hid_t; startblock: hsize_t;
                                   numblocks: hsize_t; buf: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Sget_select_hyper_blocklist", dynlib: libname.}
  ## numblocks
proc H5Sget_select_elem_pointlist*(spaceid: hid_t; startpoint: hsize_t;
                                  numpoints: hsize_t; buf: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Sget_select_elem_pointlist", dynlib: libname.}
  ## numpoints
proc H5Sget_select_bounds*(spaceid: hid_t; start: ptr hsize_t; `end`: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Sget_select_bounds", dynlib: libname.}
proc H5Sget_select_type*(spaceid: hid_t): H5S_sel_type {.cdecl,
    importc: "H5Sget_select_type", dynlib: libname.}
