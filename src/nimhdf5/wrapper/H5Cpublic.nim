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
##  Created:	H5Cpublic.h
##               June 4, 2005
##               John Mainzer
##
##  Purpose:     Public include file for cache functions.
##
##  Modifications:
##
## -------------------------------------------------------------------------
##

##  Public headers needed by this file

type
  H5C_cache_incr_mode* {.size: sizeof(cint).} = enum
    H5C_incr_off, H5C_incr_threshold


type
  H5C_cache_flash_incr_mode* {.size: sizeof(cint).} = enum
    H5C_flash_incr_off, H5C_flash_incr_add_space


type
  H5C_cache_decr_mode* {.size: sizeof(cint).} = enum
    H5C_decr_off, H5C_decr_threshold, H5C_decr_age_out,
    H5C_decr_age_out_with_threshold
