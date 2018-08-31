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

import
  H5public,
  H5FDpublic,
  ../H5nimtypes, ../h5libname



##
##  Programmer:  Robb Matzke <matzke@llnl.gov>
##               Monday, August  2, 1999
##
##  Purpose:	The public header file for the "multi" driver.
##


proc H5FD_multi_init*(): hid_t {.cdecl, importc: "H5FD_multi_init", dynlib: libname.}
proc H5Pset_fapl_multi*(fapl_id: hid_t; memb_map: ptr H5FD_mem_t;
                       memb_fapl: ptr hid_t; memb_name: cstringArray;
                       memb_addr: ptr haddr_t; relax: hbool_t): herr_t {.cdecl,
    importc: "H5Pset_fapl_multi", dynlib: libname.}
proc H5Pget_fapl_multi*(fapl_id: hid_t; memb_map: ptr H5FD_mem_t; ## out
                       memb_fapl: ptr hid_t; ## out
                       memb_name: cstringArray; ## out
                       memb_addr: ptr haddr_t; ## out
                       relax: ptr hbool_t): herr_t {.cdecl,
    importc: "H5Pget_fapl_multi", dynlib: libname.}
  ## out
proc H5Pset_fapl_split*(fapl: hid_t; meta_ext: cstring; meta_plist_id: hid_t;
                       raw_ext: cstring; raw_plist_id: hid_t): herr_t {.cdecl,
    importc: "H5Pset_fapl_split", dynlib: libname.}

let
  H5FD_MULTI* = (H5FD_multi_init())
