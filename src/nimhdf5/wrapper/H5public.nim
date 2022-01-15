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

import ../h5libname

##
##  This file contains public declarations for the HDF5 module.
##

##  Include files for public use...
##
##  Since H5pubconf.h is a generated header file, it is messy to try
##  to put a #ifndef _H5pubconf_H ... #endif guard in it.
##  HDF5 has set an internal rule that it is being included here.
##  Source files should NOT include H5pubconf.h directly but include
##  it via H5public.h.  The #ifndef _H5public_H guard above would
##  prevent repeated include.
##

import ../H5nimtypes
## define types used by all modules?
# type
#   herr_t* = cint
#   htri_t* = cint
#   hbool_t = bool
# type
#   hsize_t* = culonglong
#   hssize_t* = clonglong

#import
#  H5pubconf

## from configure
##  API Version macro wrapper definitions

#import
#  H5version

# when defined(H5_HAVE_FEATURES_H):
# when defined(H5_HAVE_SYS_TYPES_H):
# when defined(H5_STDC_HEADERS):
# when not defined(__cplusplus):
#   when defined(H5_HAVE_STDINT_H):
# else:
#   when defined(H5_HAVE_STDINT_H_CXX):
# when defined(H5_HAVE_INTTYPES_H):
# when defined(H5_HAVE_STDDEF_H):
# when defined(H5_HAVE_PARALLEL):
#   when not defined(MPI_FILE_NULL): ## MPIO may be defined in mpi.h already
##  Include the Windows API adapter header early

#import
#  H5api_adpt

##  Macros for enabling/disabling particular GCC warnings
##  (see the following web-sites for more info:
##       http://www.dbp-consulting.com/tutorials/SuppressingGCCWarnings.html
##       http://gcc.gnu.org/onlinedocs/gcc/Diagnostic-Pragmas.html#Diagnostic-Pragmas
##
##  These pragmas are only implemented usefully in gcc 4.6+
##  #if ((__GNUC__ * 100) + __GNUC_MINOR__) >= 406
##      #define H5_GCC_DIAG_STR(s) #s
##      #define H5_GCC_DIAG_JOINSTR(x,y) H5_GCC_DIAG_STR(x ## y)
##      #define H5_GCC_DIAG_DO_PRAGMA(x) _Pragma (#x)
##      #define H5_GCC_DIAG_PRAGMA(x) H5_GCC_DIAG_DO_PRAGMA(GCC diagnostic x)
##      #define H5_GCC_DIAG_OFF(x) H5_GCC_DIAG_PRAGMA(push) H5_GCC_DIAG_PRAGMA(ignored H5_GCC_DIAG_JOINSTR(-W,x))
##      #define H5_GCC_DIAG_ON(x) H5_GCC_DIAG_PRAGMA(pop)
##  #else
##      #define H5_GCC_DIAG_OFF(x)
##      #define H5_GCC_DIAG_ON(x)
##  #endif
##  Version numbers

const
  H5_VERS_MAJOR* = 1
  H5_VERS_MINOR* = 10
  H5_VERS_RELEASE* = 1
  H5_VERS_SUBRELEASE* = ""

##  Empty string for real releases.

const
  H5_VERS_INFO* = "HDF5 library version: 1.10.1"

template H5check*(): untyped =
  H5check_version(H5_VERS_MAJOR, H5_VERS_MINOR, H5_VERS_RELEASE)

##  macros for comparing the version

template H5_VERSION_GE*(Maj, Min, Rel: untyped): untyped =
  (((H5_VERS_MAJOR == Maj) and (H5_VERS_MINOR == Min) and (H5_VERS_RELEASE >= Rel)) or
      ((H5_VERS_MAJOR == Maj) and (H5_VERS_MINOR > Min)) or (H5_VERS_MAJOR > Maj))

template H5_VERSION_LE*(Maj, Min, Rel: untyped): untyped =
  (((H5_VERS_MAJOR == Maj) and (H5_VERS_MINOR == Min) and (H5_VERS_RELEASE <= Rel)) or
      ((H5_VERS_MAJOR == Maj) and (H5_VERS_MINOR < Min)) or (H5_VERS_MAJOR < Maj))

##
##  Status return values.  Failed integer functions in HDF5 result almost
##  always in a negative value (unsigned failing functions sometimes return
##  zero for failure) while successfull return is non-negative (often zero).
##  The negative failure value is most commonly -1, but don't bet on it.  The
##  proper way to detect failure is something like:
##
##  	if((dset = H5Dopen2(file, name)) < 0)
## 	    fprintf(stderr, "unable to open the requested dataset\n");
##

##
##  Boolean type.  Successful return values are zero (false) or positive
##  (true). The typical true value is 1 but don't bet on it.  Boolean
##  functions cannot fail.  Functions that return `htri_t' however return zero
##  (false), positive (true), or negative (failure). The proper way to test
##  for truth from a htri_t function is:
##
##  	if ((retval = H5Tcommitted(type))>0) {
## 	    printf("data type is committed\n");
## 	} else if (!retval) {
##  	    printf("data type is not committed\n");
## 	} else {
##  	    printf("error determining whether data type is committed\n");
## 	}
##
##  #ifdef H5_HAVE_STDBOOL_H
##    #include <stdbool.h>
##  #else /\* H5_HAVE_STDBOOL_H *\/
##    #ifndef __cplusplus
##      #if defined(H5_SIZEOF_BOOL) && (H5_SIZEOF_BOOL != 0)
##        #define bool    _Bool
##      #else
##        #define bool    unsigned int
##      #endif
##      #define true    1
##      #define false   0
##    #endif /\* __cplusplus *\/
##  #endif /\* H5_HAVE_STDBOOL_H *\/


##  Define the ssize_t type if it not is defined

const H5_SIZEOF_SSIZE_T = sizeof(csize_t)
when H5_SIZEOF_SSIZE_T == 0:
  ##  Undefine this size, we will re-define it in one of the sections below
  when H5_SIZEOF_SIZE_T == H5_SIZEOF_INT:
    type
      ssize_t* = cint
    const
      H5_SIZEOF_SSIZE_T* = H5_SIZEOF_INT
  elif H5_SIZEOF_SIZE_T == H5_SIZEOF_LONG:
    type
      ssize_t* = clong
    const
      H5_SIZEOF_SSIZE_T* = H5_SIZEOF_LONG
  elif H5_SIZEOF_SIZE_T == H5_SIZEOF_LONG_LONG:
    type
      ssize_t* = clonglong
    const
      H5_SIZEOF_SSIZE_T* = H5_SIZEOF_LONG_LONG
else:
  type
    ssize_t* = csize_t
#   else:
##
##  The sizes of file objects have their own types defined here, use a 64-bit
##  type.
##
##  #if H5_SIZEOF_LONG_LONG >= 8
##  H5_GCC_DIAG_OFF(long-long)

# type
#   hsize_t* = culonglong
#   hssize_t* = clonglong

##  H5_GCC_DIAG_ON(long-long)
##  #       define H5_SIZEOF_HSIZE_T H5_SIZEOF_LONG_LONG
##  #       define H5_SIZEOF_HSSIZE_T H5_SIZEOF_LONG_LONG
##  #else
##  #   error "nothing appropriate for hsize_t"
##  #endif

#const
#  HSIZE_UNDEF* = ((hsize_t)(hssize_t)(- 1))

##
##  File addresses have their own types.
##

const H5_SIZEOF_INT* = sizeof(cint)
const H5_SIZEOF_LONG* = sizeof(clong)
const H5_SIZEOF_LONG_LONG* = sizeof(clonglong)

when H5_SIZEOF_INT >= 8:
  type
    haddr_t* = cuint
  const
    HADDR_UNDEF* = cast[haddr_t](-1.cint)
    H5_SIZEOF_HADDR_T* = H5_SIZEOF_INT
  when defined(H5_HAVE_PARALLEL):
    const
      HADDR_AS_MPI_TYPE* = MPI_UNSIGNED
elif H5_SIZEOF_LONG >= 8:
  type
    haddr_t* = culong
  const
    HADDR_UNDEF* = cast[haddr_t](-1.clong)
    H5_SIZEOF_HADDR_T* = H5_SIZEOF_LONG
  when defined(H5_HAVE_PARALLEL):
    const
      HADDR_AS_MPI_TYPE* = MPI_UNSIGNED_LONG
elif H5_SIZEOF_LONG_LONG >= 8:
  type
    haddr_t* = culonglong
  const
    HADDR_UNDEF* = cast[haddr_t](-1.clonglong)
    H5_SIZEOF_HADDR_T* = H5_SIZEOF_LONG_LONG
  when defined(H5_HAVE_PARALLEL):
    const
      HADDR_AS_MPI_TYPE* = MPI_LONG_LONG_INT
## else:
##  #if H5_SIZEOF_HADDR_T == H5_SIZEOF_INT
##  #   define H5_PRINTF_HADDR_FMT  "%u"
##  #elif H5_SIZEOF_HADDR_T == H5_SIZEOF_LONG
##  #   define H5_PRINTF_HADDR_FMT  "%lu"
##  #elif H5_SIZEOF_HADDR_T == H5_SIZEOF_LONG_LONG
##  #   define H5_PRINTF_HADDR_FMT  "%" H5_PRINTF_LL_WIDTH "u"
##  #else
##  #   error "nothing appropriate for H5_PRINTF_HADDR_FMT"
##  #endif

const
  HADDR_MAX* = (HADDR_UNDEF - 1)

##  uint32_t type is used for creation order field for messages.  It may be
##  defined in Posix.1g, otherwise it is defined here.
##

const H5_SIZEOF_UINT32_T* = sizeof(cuint)
const H5_SIZEOF_SHORT* = sizeof(cshort)
when H5_SIZEOF_UINT32_T >= 4:
  # this is empty in the original H5 code.
  type
    uint32_t* = cuint # since cuint maps to uint32
elif H5_SIZEOF_SHORT >= 4:
  type
    uint32_t* = cshort
elif H5_SIZEOF_INT >= 4:
  type
    uint32_t* = cuint
elif H5_SIZEOF_LONG >= 4:
  type
    uint32_t* = culong
else:
  {.error: "No matching type for uint32_t".}
# else:
# ##  int64_t type is used for creation order field for links.  It may be
# ##  defined in Posix.1g, otherwise it is defined here.
# ##

# when H5_SIZEOF_INT64_T >= 8:
# elif H5_SIZEOF_INT >= 8:
#   type
#     int64_t* = cint
#   const
#     H5_SIZEOF_INT64_T* = H5_SIZEOF_INT
# elif H5_SIZEOF_LONG >= 8:
#   type
#     int64_t* = clong
#   const
#     H5_SIZEOF_INT64_T* = H5_SIZEOF_LONG
# elif H5_SIZEOF_LONG_LONG >= 8:
#   type
#     int64_t* = clonglong
#   const
#     H5_SIZEOF_INT64_T* = H5_SIZEOF_LONG_LONG
# else:
# ##  uint64_t type is used for fields for H5O_info_t.  It may be
# ##  defined in Posix.1g, otherwise it is defined here.
# ##

# when H5_SIZEOF_UINT64_T >= 8:
# elif H5_SIZEOF_INT >= 8:
#   type
#     uint64_t* = cuint
#   const
#     H5_SIZEOF_UINT64_T* = H5_SIZEOF_INT
# elif H5_SIZEOF_LONG >= 8:
#   type
#     uint64_t* = culong
#   const
#     H5_SIZEOF_UINT64_T* = H5_SIZEOF_LONG
# elif H5_SIZEOF_LONG_LONG >= 8:
#   type
#     uint64_t* = culonglong
#   const
#     H5_SIZEOF_UINT64_T* = H5_SIZEOF_LONG_LONG
# else:
##  Common iteration orders

type
  H5_iter_order_t* {.size: sizeof(cint).} = enum
    H5_ITER_UNKNOWN = - 1,       ##  Unknown order
    H5_ITER_INC,              ##  Increasing order
    H5_ITER_DEC,              ##  Decreasing order
    H5_ITER_NATIVE,           ##  No particular order, whatever is fastest
    H5_ITER_N                 ##  Number of iteration orders


##  Iteration callback values
##  (Actually, any postive value will cause the iterator to stop and pass back
##       that positive value to the function that called the iterator)
##

const
  H5_ITER_ERROR* = (- 1)
  H5_ITER_CONT* = (0)
  H5_ITER_STOP* = (1)

##
##  The types of indices on links in groups/attributes on objects.
##  Primarily used for "<do> <foo> by index" routines and for iterating over
##  links in groups/attributes on objects.
##

type
  H5_index_t* {.size: sizeof(cint).} = enum
    H5_INDEX_UNKNOWN = - 1,      ##  Unknown index type
    H5_INDEX_NAME,            ##  Index on names
    H5_INDEX_CRT_ORDER,       ##  Index on creation order
    H5_INDEX_N                ##  Number of indices defined


##
##  Storage info struct used by H5O_info_t and H5F_info_t
##

type
  H5_ih_info_t* = object
    index_size*: hsize_t       ##  btree and/or list
    heap_size*: hsize_t


##  Functions in H5.c

proc H5open*(): herr_t {.cdecl, importc: "H5open", dynlib: libname.}
proc H5close*(): herr_t {.cdecl, importc: "H5close", dynlib: libname.}
proc H5dont_atexit*(): herr_t {.cdecl, importc: "H5dont_atexit", dynlib: libname.}
proc H5garbage_collect*(): herr_t {.cdecl, importc: "H5garbage_collect",
                                 dynlib: libname.}
proc H5set_free_list_limits*(reg_global_lim: cint; reg_list_lim: cint;
                            arr_global_lim: cint; arr_list_lim: cint;
                            blk_global_lim: cint; blk_list_lim: cint): herr_t {.
    cdecl, importc: "H5set_free_list_limits", dynlib: libname.}
proc H5get_libversion*(majnum: ptr cuint; minnum: ptr cuint; relnum: ptr cuint): herr_t {.
    cdecl, importc: "H5get_libversion", dynlib: libname.}
proc H5check_version*(majnum: cuint; minnum: cuint; relnum: cuint): herr_t {.cdecl,
    importc: "H5check_version", dynlib: libname.}
proc H5is_library_threadsafe*(is_ts: ptr hbool_t): herr_t {.cdecl,
    importc: "H5is_library_threadsafe", dynlib: libname.}
proc H5free_memory*(mem: pointer): herr_t {.cdecl, importc: "H5free_memory",
                                        dynlib: libname.}
proc H5allocate_memory*(size: csize_t; clear: hbool_t): pointer {.cdecl,
    importc: "H5allocate_memory", dynlib: libname.}
proc H5resize_memory*(mem: pointer; size: csize_t): pointer {.cdecl,
    importc: "H5resize_memory", dynlib: libname.}
