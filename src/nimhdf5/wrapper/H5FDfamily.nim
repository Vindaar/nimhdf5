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

import ../H5nimtypes, ../h5libname


##
##  Programmer:  Robb Matzke <matzke@llnl.gov>
##               Monday, August  4, 1999
##
##  Purpose:	The public header file for the family driver.
##

proc H5FD_family_init*(): hid_t {.cdecl, importc: "H5FD_family_init", dynlib: libname.}
proc H5Pset_fapl_family*(fapl_id: hid_t; memb_size: hsize_t; memb_fapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Pset_fapl_family", dynlib: libname.}
proc H5Pget_fapl_family*(fapl_id: hid_t; memb_size: ptr hsize_t; ## out
                        memb_fapl_id: ptr hid_t): herr_t {.cdecl,
    importc: "H5Pget_fapl_family", dynlib: libname.}
  ## out


let
  H5FD_FAMILY* = (H5FD_family_init())
