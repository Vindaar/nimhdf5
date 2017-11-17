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

## -------------------------------------------------------------------------
## 
##  Created:             H5MMproto.h
##                       Jul 10 1997
##                       Robb Matzke <matzke@llnl.gov>
## 
##  Purpose:             Public declarations for the H5MM (memory management)
##                       package.
## 
##  Modifications:
## 
## -------------------------------------------------------------------------
## 

##  Public headers needed by this file

import
  H5public

when not declared(libname):
  const
    libname* = "libhdf5.so"  

##  These typedefs are currently used for VL datatype allocation/freeing

type
  H5MM_allocate_t* = proc (size: csize; alloc_info: pointer): pointer {.cdecl.}
  H5MM_free_t* = proc (mem: pointer; free_info: pointer) {.cdecl.}
