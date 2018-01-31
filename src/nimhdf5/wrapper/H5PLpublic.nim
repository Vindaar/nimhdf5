##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
##  Copyright by The HDF Group.                                               *
##  All rights reserved.                                                      *
##                                                                            *
##  This file is part of HDF5. The full HDF5 copyright notice, including      *
##  terms governing use, modification, and redistribution, is contained in    *
##  the COPYING file, which can be found at the root of the source code       *
##  distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.  *
##  If you do not have access to either file, you may request a copy from     *
##  help@hdfgroup.org.                                                        *
##  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

{.deadCodeElim: on.}

##  Programmer:  Raymond Lu <songyulu@hdfgroup.org>
##               13 February 2013
## 

##  Public headers needed by this file

import
  H5public,
  ../H5nimtypes

when not declared(libname):
  when defined(Windows):
    const
      libname* = "hdf5.dll"
  elif defined(MacOSX):
    const
      libname* = "libhdf5.dylib"
  else:
    const
      libname* = "libhdf5.so"

##  Generic Functions
## *****************
##  Public Typedefs
## *****************
##  Plugin type used by the plugin library

type
  H5PL_type_t* {.size: sizeof(cint).} = enum
    H5PL_TYPE_ERROR = - 1,       ## error
    H5PL_TYPE_FILTER = 0,       ## filter
    H5PL_TYPE_NONE = 1


##  Common dynamic plugin type flags used by the set/get_loading_state functions

const
  H5PL_FILTER_PLUGIN* = 0x00000001
  H5PL_ALL_PLUGIN* = 0x0000FFFF

##  plugin state

proc H5PLset_loading_state*(plugin_type: cuint): herr_t {.cdecl,
    importc: "H5PLset_loading_state", dynlib: libname.}
proc H5PLget_loading_state*(plugin_type: ptr cuint): herr_t {.cdecl,
    importc: "H5PLget_loading_state", dynlib: libname.}
  ## out
proc H5PLappend*(plugin_path: cstring): herr_t {.cdecl, importc: "H5PLappend",
    dynlib: libname.}
proc H5PLprepend*(plugin_path: cstring): herr_t {.cdecl, importc: "H5PLprepend",
    dynlib: libname.}
proc H5PLreplace*(plugin_path: cstring; index: cuint): herr_t {.cdecl,
    importc: "H5PLreplace", dynlib: libname.}
proc H5PLinsert*(plugin_path: cstring; index: cuint): herr_t {.cdecl,
    importc: "H5PLinsert", dynlib: libname.}
proc H5PLremove*(index: cuint): herr_t {.cdecl, importc: "H5PLremove", dynlib: libname.}
proc H5PLget*(index: cuint; pathname: cstring; ## out
             size: csize): ssize_t {.cdecl, importc: "H5PLget", dynlib: libname.}
proc H5PLsize*(listsize: ptr cuint): herr_t {.cdecl, importc: "H5PLsize",
    dynlib: libname.}
  ## out
