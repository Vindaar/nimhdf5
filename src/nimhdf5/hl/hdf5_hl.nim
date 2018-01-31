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
##  This is the main public HDF5 High Level include file.  Put further
##  information in a particular header file and include that here, don't
##  fill this file with lots of gunk...
## 

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

include
  ../nim-hdf5,                       ##  hdf5 main library
  H5DOpublic,                 ##  dataset optimization
  H5DSpublic,                 ##  dimension scales
  H5LTpublic,                 ##  lite
  H5IMpublic,                 ##  image
  H5TBpublic,                 ##  table
  H5PTpublic,                 ##  packet table
  H5LDpublic

##  lite dataset
