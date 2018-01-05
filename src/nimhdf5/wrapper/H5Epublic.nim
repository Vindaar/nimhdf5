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
##  This file contains public declarations for the H5E module.
## 

##  Public headers needed by this file

import
  H5public, H5Ipublic, ../H5nimtypes

when not declared(libname):  
  const
    libname*: string = "libhdf5.so"


# before we can import any of the variables, from the already shared library
# we need to make sure that they are defined. The library needs to be
# initialized. Thus we include
include H5niminitialize
  

##  Value for the default error stack

const
  H5E_DEFAULT* = 0

##  Different kinds of error information

type
  H5E_type_t* {.size: sizeof(cint).} = enum
    H5E_MAJOR, H5E_MINOR


##  Information about an error; element of error stack

type
  H5E_error2_t* = object
    cls_id*: hid_t             ## class ID
    maj_num*: hid_t            ## major error ID
    min_num*: hid_t            ## minor error number
    line*: cuint               ## line in file where error occurs
    func_name*: cstring        ## function in which error occurred
    file_name*: cstring        ## file in which error occurred
    desc*: cstring             ## optional supplied description
  

##  When this header is included from a private header, don't make calls to H5open()

# when not defined(H5private_H):
#   const
#     H5OPEN* = H5open()
# else:
#   const
#     H5OPEN* = true
##  HDF5 error class

var H5E_ERR_CLS_g* {.importc: "H5E_ERR_CLS_g", dynlib: libname.}: hid_t

let
  H5E_ERR_CLS* = H5E_ERR_CLS_g


##  Include the automatically generated public header information
##  (This includes the list of major and minor error codes for the library)

# import
#   H5Epubgen

## 
##  One often needs to temporarily disable automatic error reporting when
##  trying something that's likely or expected to fail.  The code to try can
##  be nested between calls to H5Eget_auto() and H5Eset_auto(), but it's
##  easier just to use this macro like:
##  	H5E_BEGIN_TRY {
## 	    ...stuff here that's likely to fail...
##       } H5E_END_TRY;
## 
##  Warning: don't break, return, or longjmp() from the body of the loop or
## 	    the error reporting won't be properly restored!
## 
##  These two macros still use the old API functions for backward compatibility
##  purpose.
## 
##  #ifndef H5_NO_DEPRECATED_SYMBOLS
##  #define H5E_BEGIN_TRY {							      \
##      unsigned H5E_saved_is_v2;					              \
##      union {								      \
##          H5E_auto1_t efunc1;						      \
##          H5E_auto2_t efunc2;					              \
##      } H5E_saved;							      \
##      void *H5E_saved_edata;						      \
##  								    	      \
##      (void)H5Eauto_is_v2(H5E_DEFAULT, &H5E_saved_is_v2);		              \
##      if(H5E_saved_is_v2) {						      \
##          (void)H5Eget_auto2(H5E_DEFAULT, &H5E_saved.efunc2, &H5E_saved_edata); \
##          (void)H5Eset_auto2(H5E_DEFAULT, NULL, NULL);		              \
##      } else {								      \
##          (void)H5Eget_auto1(&H5E_saved.efunc1, &H5E_saved_edata);		      \
##          (void)H5Eset_auto1(NULL, NULL);					      \
##      }
##  #define H5E_END_TRY							      \
##      if(H5E_saved_is_v2)							      \
##          (void)H5Eset_auto2(H5E_DEFAULT, H5E_saved.efunc2, H5E_saved_edata);   \
##      else								      \
##          (void)H5Eset_auto1(H5E_saved.efunc1, H5E_saved_edata);		      \
##  }
##  #else /\* H5_NO_DEPRECATED_SYMBOLS *\/
##  #define H5E_BEGIN_TRY {							      \
##      H5E_auto_t saved_efunc;						      \
##      void *H5E_saved_edata;						      \
##  								    	      \
##      (void)H5Eget_auto(H5E_DEFAULT, &saved_efunc, &H5E_saved_edata);	      \
##      (void)H5Eset_auto(H5E_DEFAULT, NULL, NULL);
##  #define H5E_END_TRY							      \
##      (void)H5Eset_auto(H5E_DEFAULT, saved_efunc, H5E_saved_edata);	      \
##  }
##  #endif /\* H5_NO_DEPRECATED_SYMBOLS *\/
## 
##  Public API Convenience Macros for Error reporting - Documented
## 
##  Use the Standard C __FILE__ & __LINE__ macros instead of typing them in

template H5Epush_sim*(`func`, cls, maj, min, str: untyped): untyped =
  let (file, line) = instantiationInfo()
  H5Epush2(H5E_DEFAULT, file, `func`, line, cls, maj, min, str)

## 
##  Public API Convenience Macros for Error reporting - Undocumented
## 
##  Use the Standard C __FILE__ & __LINE__ macros instead of typing them in
##   And return after pushing error onto stack

template H5Epush_ret*(`func`, cls, maj, min, str, ret: untyped): void =
  let (file, line) = instantiationInfo()  
  H5Epush2(H5E_DEFAULT, file, `func`, line, cls, maj, min, str)
  return ret

##  Use the Standard C __FILE__ & __LINE__ macros instead of typing them in
##  And goto a label after pushing error onto stack.
## 

template H5Epush_goto*(`func`, cls, maj, min, str, label: untyped): void =
  let (file, line) = instantiationInfo()  
  H5Epush2(H5E_DEFAULT, file, `func`, line, cls, maj, min, str)
  break label

##  Error stack traversal direction

type
  H5E_direction_t* {.size: sizeof(cint).} = enum
    H5E_WALK_UPWARD = 0,        ## begin deep, end at API function
    H5E_WALK_DOWNWARD = 1


##  Error stack traversal callback function pointers

type
  H5E_walk2_t* = proc (n: cuint; err_desc: ptr H5E_error2_t; client_data: pointer): herr_t {.
      cdecl.}
  H5E_auto2_t* = proc (estack: hid_t; client_data: pointer): herr_t {.cdecl.}

##  Public API functions

proc H5Eregister_class*(cls_name: cstring; lib_name: cstring; version: cstring): hid_t {.cdecl, importc: "H5Eregister_class", dynlib: "libhdf5.so".}
proc H5Eunregister_class*(class_id: hid_t): herr_t {.cdecl,
    importc: "H5Eunregister_class", dynlib: libname.}
proc H5Eclose_msg*(err_id: hid_t): herr_t {.cdecl, importc: "H5Eclose_msg",
                                        dynlib: libname.}
proc H5Ecreate_msg*(cls: hid_t; msg_type: H5E_type_t; msg: cstring): hid_t {.cdecl,
    importc: "H5Ecreate_msg", dynlib: libname.}
proc H5Ecreate_stack*(): hid_t {.cdecl, importc: "H5Ecreate_stack", dynlib: libname.}
proc H5Eget_current_stack*(): hid_t {.cdecl, importc: "H5Eget_current_stack",
                                   dynlib: libname.}
proc H5Eclose_stack*(stack_id: hid_t): herr_t {.cdecl, importc: "H5Eclose_stack",
    dynlib: libname.}
proc H5Eget_class_name*(class_id: hid_t; name: cstring; size: csize): ssize_t {.cdecl,
    importc: "H5Eget_class_name", dynlib: libname.}
proc H5Eset_current_stack*(err_stack_id: hid_t): herr_t {.cdecl,
    importc: "H5Eset_current_stack", dynlib: libname.}
proc H5Epush2*(err_stack: hid_t; file: cstring; `func`: cstring; line: cuint;
              cls_id: hid_t; maj_id: hid_t; min_id: hid_t; msg: cstring): herr_t {.
    varargs, cdecl, importc: "H5Epush2", dynlib: libname.}
proc H5Epop*(err_stack: hid_t; count: csize): herr_t {.cdecl, importc: "H5Epop",
    dynlib: libname.}
proc H5Eprint2*(err_stack: hid_t; stream: ptr FILE): herr_t {.cdecl,
    importc: "H5Eprint2", dynlib: libname.}
proc H5Ewalk2*(err_stack: hid_t; direction: H5E_direction_t; `func`: H5E_walk2_t;
              client_data: pointer): herr_t {.cdecl, importc: "H5Ewalk2",
    dynlib: libname.}
proc H5Eget_auto2*(estack_id: hid_t; `func`: ptr H5E_auto2_t; client_data: ptr pointer): herr_t {.
    cdecl, importc: "H5Eget_auto2", dynlib: libname.}
proc H5Eset_auto2*(estack_id: hid_t; `func`: H5E_auto2_t; client_data: pointer): herr_t {.
    cdecl, importc: "H5Eset_auto2", dynlib: libname.}
proc H5Eclear2*(err_stack: hid_t): herr_t {.cdecl, importc: "H5Eclear2",
                                        dynlib: libname.}
proc H5Eauto_is_v2*(err_stack: hid_t; is_stack: ptr cuint): herr_t {.cdecl,
    importc: "H5Eauto_is_v2", dynlib: libname.}
proc H5Eget_msg*(msg_id: hid_t; `type`: ptr H5E_type_t; msg: cstring; size: csize): ssize_t {.
    cdecl, importc: "H5Eget_msg", dynlib: libname.}
proc H5Eget_num*(error_stack_id: hid_t): ssize_t {.cdecl, importc: "H5Eget_num",
    dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
## 
##  Use of these symbols is deprecated.
## 

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Typedefs
  ##  Alias major & minor error types to hid_t's, for compatibility with new
  ##       error API in v1.8
  ## 
  type
    H5E_major_t* = hid_t
    H5E_minor_t* = hid_t
  ##  Information about an error element of error stack.
  type
    H5E_error1_t* = object
      maj_num*: H5E_major_t    ## major error number
      min_num*: H5E_minor_t    ## minor error number
      func_name*: cstring      ## function in which error occurred
      file_name*: cstring      ## file in which error occurred
      line*: cuint             ## line in file where error occurs
      desc*: cstring           ## optional supplied description
    
  ##  Error stack traversal callback function pointers
  type
    H5E_walk1_t* = proc (n: cint; err_desc: ptr H5E_error1_t; client_data: pointer): herr_t {.
        cdecl.}
    H5E_auto1_t* = proc (client_data: pointer): herr_t {.cdecl.}
  ##  Function prototypes
  proc H5Eclear1*(): herr_t {.cdecl, importc: "H5Eclear1", dynlib: libname.}
  proc H5Eget_auto1*(`func`: ptr H5E_auto1_t; client_data: ptr pointer): herr_t {.cdecl,
      importc: "H5Eget_auto1", dynlib: libname.}
  proc H5Epush1*(file: cstring; `func`: cstring; line: cuint; maj: H5E_major_t;
                min: H5E_minor_t; str: cstring): herr_t {.cdecl, importc: "H5Epush1",
      dynlib: libname.}
  proc H5Eprint1*(stream: ptr FILE): herr_t {.cdecl, importc: "H5Eprint1",
      dynlib: libname.}
  proc H5Eset_auto1*(`func`: H5E_auto1_t; client_data: pointer): herr_t {.cdecl,
      importc: "H5Eset_auto1", dynlib: libname.}
  proc H5Ewalk1*(direction: H5E_direction_t; `func`: H5E_walk1_t;
                client_data: pointer): herr_t {.cdecl, importc: "H5Ewalk1",
      dynlib: libname.}
  proc H5Eget_major*(maj: H5E_major_t): cstring {.cdecl, importc: "H5Eget_major",
      dynlib: libname.}
  proc H5Eget_minor*(min: H5E_minor_t): cstring {.cdecl, importc: "H5Eget_minor",
      dynlib: libname.}
