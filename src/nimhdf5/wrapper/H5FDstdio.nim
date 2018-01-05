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
## 
##  Programmer:  Robb Matzke <matzke@llnl.gov>
##               Monday, August  2, 1999
## 
##  Purpose:	The public header file for the sec2 driver.
## 

{.deadCodeElim: on.}

import
  H5Ipublic,
  ../H5nimtypes

when not declared(libname):
  const
    libname* = "libhdf5.so"  


proc H5FD_stdio_init*(): hid_t {.cdecl, importc: "H5FD_stdio_init", dynlib: libname.}
proc H5Pset_fapl_stdio*(fapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Pset_fapl_stdio", dynlib: libname.}

let
  H5FD_STDIO* = (H5FD_stdio_init())
