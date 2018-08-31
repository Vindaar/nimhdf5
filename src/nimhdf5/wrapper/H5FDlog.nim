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
##  Programmer:  Quincey Koziol <koziol@ncsa.uiuc.edu>
##               Monday, April 17, 2000
##
##  Purpose:	The public header file for the log driver.
##

import ../H5nimtypes, ../h5libname



##  Flags for H5Pset_fapl_log()
##  Flags for tracking 'meta' operations (truncate)

const
  H5FD_LOG_TRUNCATE* = 0x00000001
  H5FD_LOG_META_IO* = (H5FD_LOG_TRUNCATE)

##  Flags for tracking where reads/writes/seeks occur

const
  H5FD_LOG_LOC_READ* = 0x00000002
  H5FD_LOG_LOC_WRITE* = 0x00000004
  H5FD_LOG_LOC_SEEK* = 0x00000008
  H5FD_LOG_LOC_IO* = (H5FD_LOG_LOC_READ or H5FD_LOG_LOC_WRITE or H5FD_LOG_LOC_SEEK)

##  Flags for tracking number of times each byte is read/written

const
  H5FD_LOG_FILE_READ* = 0x00000010
  H5FD_LOG_FILE_WRITE* = 0x00000020
  H5FD_LOG_FILE_IO* = (H5FD_LOG_FILE_READ or H5FD_LOG_FILE_WRITE)

##  Flag for tracking "flavor" (type) of information stored at each byte

const
  H5FD_LOG_FLAVOR* = 0x00000040

##  Flags for tracking total number of reads/writes/seeks/truncates

const
  H5FD_LOG_NUM_READ* = 0x00000080
  H5FD_LOG_NUM_WRITE* = 0x00000100
  H5FD_LOG_NUM_SEEK* = 0x00000200
  H5FD_LOG_NUM_TRUNCATE* = 0x00000400
  H5FD_LOG_NUM_IO* = (H5FD_LOG_NUM_READ or H5FD_LOG_NUM_WRITE or H5FD_LOG_NUM_SEEK or
      H5FD_LOG_NUM_TRUNCATE)

##  Flags for tracking time spent in open/stat/read/write/seek/truncate/close

const
  H5FD_LOG_TIME_OPEN* = 0x00000800
  H5FD_LOG_TIME_STAT* = 0x00001000
  H5FD_LOG_TIME_READ* = 0x00002000
  H5FD_LOG_TIME_WRITE* = 0x00004000
  H5FD_LOG_TIME_SEEK* = 0x00008000
  H5FD_LOG_TIME_TRUNCATE* = 0x00010000
  H5FD_LOG_TIME_CLOSE* = 0x00020000
  H5FD_LOG_TIME_IO* = (H5FD_LOG_TIME_OPEN or H5FD_LOG_TIME_STAT or
      H5FD_LOG_TIME_READ or H5FD_LOG_TIME_WRITE or H5FD_LOG_TIME_SEEK or
      H5FD_LOG_TIME_TRUNCATE or H5FD_LOG_TIME_CLOSE)

##  Flags for tracking allocation/release of space in file

const
  H5FD_LOG_ALLOC* = 0x00040000
  H5FD_LOG_FREE* = 0x00080000
  H5FD_LOG_ALL* = (H5FD_LOG_FREE or H5FD_LOG_ALLOC or H5FD_LOG_TIME_IO or
      H5FD_LOG_NUM_IO or H5FD_LOG_FLAVOR or H5FD_LOG_FILE_IO or H5FD_LOG_LOC_IO or
      H5FD_LOG_META_IO)

proc H5FD_log_init*(): hid_t {.cdecl, importc: "H5FD_log_init", dynlib: libname.}
proc H5Pset_fapl_log*(fapl_id: hid_t; logfile: cstring; flags: culonglong;
                     buf_size: csize): herr_t {.cdecl, importc: "H5Pset_fapl_log",
    dynlib: libname.}

let
  H5FD_LOG* = (H5FD_log_init())
