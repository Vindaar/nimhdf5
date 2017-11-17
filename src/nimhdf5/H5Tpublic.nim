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
##  This file contains public declarations for the H5T module.
## 

##  Public headers needed by this file

import
  H5public, H5Ipublic, H5nimtypes

when not declared(libname):
  const
    libname* = "libhdf5.so"


# before we can import any of the variables, from the already shared library
# we need to make sure that they are defined. The library needs to be
# initialized. Thus we include
include H5niminitialize


template HOFFSET*(S, M: untyped): untyped =
  (offsetof(S, M))

##  These are the various classes of datatypes
##  If this goes over 16 types (0-15), the file format will need to change)

type
  H5T_class_t* {.size: sizeof(cint).} = enum
    H5T_NO_CLASS = - 1,          ## error
    H5T_INTEGER = 0,            ## integer types
    H5T_FLOAT = 1,              ## floating-point types
    H5T_TIME = 2,               ## date and time types
    H5T_STRING = 3,             ## character string types
    H5T_BITFIELD = 4,           ## bit field types
    H5T_OPAQUE = 5,             ## opaque types
    H5T_COMPOUND = 6,           ## compound types
    H5T_REFERENCE = 7,          ## reference types
    H5T_ENUM = 8,               ## enumeration types
    H5T_VLEN = 9,               ## Variable-Length types
    H5T_ARRAY = 10,             ## Array types
    H5T_NCLASSES              ## this must be last


##  Byte orders

type
  H5T_order_t* {.size: sizeof(cint).} = enum
    H5T_ORDER_ERROR = - 1,       ## error
    H5T_ORDER_LE = 0,           ## little endian
    H5T_ORDER_BE = 1,           ## bit endian
    H5T_ORDER_VAX = 2,          ## VAX mixed endian
    H5T_ORDER_MIXED = 3,        ## Compound type with mixed member orders
    H5T_ORDER_NONE = 4


##  Types of integer sign schemes

type
  H5T_sign_t* {.size: sizeof(cint).} = enum
    H5T_SGN_ERROR = - 1,         ## error
    H5T_SGN_NONE = 0,           ## this is an unsigned type
    H5T_SGN_2 = 1,              ## two's complement
    H5T_NSGN = 2


##  Floating-point normalization schemes

type
  H5T_norm_t* {.size: sizeof(cint).} = enum
    H5T_NORM_ERROR = - 1,        ## error
    H5T_NORM_IMPLIED = 0,       ## msb of mantissa isn't stored, always 1
    H5T_NORM_MSBSET = 1,        ## msb of mantissa is always 1
    H5T_NORM_NONE = 2


## 
##  Character set to use for text strings.  Do not change these values since
##  they appear in HDF5 files!
## 

type
  H5T_cset_t* {.size: sizeof(cint).} = enum
    H5T_CSET_ERROR = - 1,        ## error
    H5T_CSET_ASCII = 0,         ## US ASCII
    H5T_CSET_UTF8 = 1,          ## UTF-8 Unicode encoding
    H5T_CSET_RESERVED_2 = 2,    ## reserved for later use
    H5T_CSET_RESERVED_3 = 3,    ## reserved for later use
    H5T_CSET_RESERVED_4 = 4,    ## reserved for later use
    H5T_CSET_RESERVED_5 = 5,    ## reserved for later use
    H5T_CSET_RESERVED_6 = 6,    ## reserved for later use
    H5T_CSET_RESERVED_7 = 7,    ## reserved for later use
    H5T_CSET_RESERVED_8 = 8,    ## reserved for later use
    H5T_CSET_RESERVED_9 = 9,    ## reserved for later use
    H5T_CSET_RESERVED_10 = 10,  ## reserved for later use
    H5T_CSET_RESERVED_11 = 11,  ## reserved for later use
    H5T_CSET_RESERVED_12 = 12,  ## reserved for later use
    H5T_CSET_RESERVED_13 = 13,  ## reserved for later use
    H5T_CSET_RESERVED_14 = 14,  ## reserved for later use
    H5T_CSET_RESERVED_15 = 15


const
  H5T_NCSET* = H5T_CSET_RESERVED_2

## 
##  Type of padding to use in character strings.  Do not change these values
##  since they appear in HDF5 files!
## 

type
  H5T_str_t* {.size: sizeof(cint).} = enum
    H5T_STR_ERROR = - 1,         ## error
    H5T_STR_NULLTERM = 0,       ## null terminate like in C
    H5T_STR_NULLPAD = 1,        ## pad with nulls
    H5T_STR_SPACEPAD = 2,       ## pad with spaces like in Fortran
    H5T_STR_RESERVED_3 = 3,     ## reserved for later use
    H5T_STR_RESERVED_4 = 4,     ## reserved for later use
    H5T_STR_RESERVED_5 = 5,     ## reserved for later use
    H5T_STR_RESERVED_6 = 6,     ## reserved for later use
    H5T_STR_RESERVED_7 = 7,     ## reserved for later use
    H5T_STR_RESERVED_8 = 8,     ## reserved for later use
    H5T_STR_RESERVED_9 = 9,     ## reserved for later use
    H5T_STR_RESERVED_10 = 10,   ## reserved for later use
    H5T_STR_RESERVED_11 = 11,   ## reserved for later use
    H5T_STR_RESERVED_12 = 12,   ## reserved for later use
    H5T_STR_RESERVED_13 = 13,   ## reserved for later use
    H5T_STR_RESERVED_14 = 14,   ## reserved for later use
    H5T_STR_RESERVED_15 = 15


const
  H5T_NSTR* = H5T_STR_RESERVED_3

##  Type of padding to use in other atomic types

type
  H5T_pad_t* {.size: sizeof(cint).} = enum
    H5T_PAD_ERROR = - 1,         ## error
    H5T_PAD_ZERO = 0,           ## always set to zero
    H5T_PAD_ONE = 1,            ## always set to one
    H5T_PAD_BACKGROUND = 2,     ## set to background value
    H5T_NPAD = 3


##  Commands sent to conversion functions

type
  H5T_cmd_t* {.size: sizeof(cint).} = enum
    H5T_CONV_INIT = 0,          ## query and/or initialize private data
    H5T_CONV_CONV = 1,          ## convert data from source to dest datatype
    H5T_CONV_FREE = 2


##  How is the `bkg' buffer used by the conversion function?

type
  H5T_bkg_t* {.size: sizeof(cint).} = enum
    H5T_BKG_NO = 0,             ## background buffer is not needed, send NULL
    H5T_BKG_TEMP = 1,           ## bkg buffer used as temp storage only
    H5T_BKG_YES = 2


##  Type conversion client data

type
  H5T_cdata_t* = object
    command*: H5T_cmd_t        ## what should the conversion function do?
    need_bkg*: H5T_bkg_t       ## is the background buffer needed?
    recalc*: hbool_t           ## recalculate private data
    priv*: pointer             ## private data
  

##  Conversion function persistence

type
  H5T_pers_t* {.size: sizeof(cint).} = enum
    H5T_PERS_DONTCARE = - 1,     ## wild card
    H5T_PERS_HARD = 0,          ## hard conversion function
    H5T_PERS_SOFT = 1


##  The order to retrieve atomic native datatype

type
  H5T_direction_t* {.size: sizeof(cint).} = enum
    H5T_DIR_DEFAULT = 0,        ## default direction is inscendent
    H5T_DIR_ASCEND = 1,         ## in inscendent order
    H5T_DIR_DESCEND = 2


##  The exception type passed into the conversion callback function

type
  H5T_conv_except_t* {.size: sizeof(cint).} = enum
    H5T_CONV_EXCEPT_RANGE_HI = 0, ## source value is greater than destination's range
    H5T_CONV_EXCEPT_RANGE_LOW = 1, ## source value is less than destination's range
    H5T_CONV_EXCEPT_PRECISION = 2, ## source value loses precision in destination
    H5T_CONV_EXCEPT_TRUNCATE = 3, ## source value is truncated in destination
    H5T_CONV_EXCEPT_PINF = 4,   ## source value is positive infinity(floating number)
    H5T_CONV_EXCEPT_NINF = 5,   ## source value is negative infinity(floating number)
    H5T_CONV_EXCEPT_NAN = 6


##  The return value from conversion callback function H5T_conv_except_func_t

type
  H5T_conv_ret_t* {.size: sizeof(cint).} = enum
    H5T_CONV_ABORT = - 1,        ## abort conversion
    H5T_CONV_UNHANDLED = 0,     ## callback function failed to handle the exception
    H5T_CONV_HANDLED = 1


##  Variable Length Datatype struct in memory
##  (This is only used for VL sequences, not VL strings, which are stored in char *'s)

type
  hvl_t* = object
    len*: csize                ##  Length of VL data (in base type units)
    p*: pointer                ##  Pointer to VL data
  

##  Variable Length String information

const
  H5T_VARIABLE* = ((csize)(- 1)) ##  Indicate that a string is variable length (null-terminated in C, instead of fixed length)

##  Opaque information

const
  H5T_OPAQUE_TAG_MAX* = 256

##  This could be raised without too much difficulty

##  All datatype conversion functions are...

type
  H5T_conv_t* = proc (src_id: hid_t; dst_id: hid_t; cdata: ptr H5T_cdata_t; nelmts: csize;
                   buf_stride: csize; bkg_stride: csize; buf: pointer; bkg: pointer;
                   dset_xfer_plist: hid_t): herr_t {.cdecl.}

##  Exception handler.  If an exception like overflow happenes during conversion,
##  this function is called if it's registered through H5Pset_type_conv_cb.
## 

type
  H5T_conv_except_func_t* = proc (except_type: H5T_conv_except_t; src_id: hid_t;
                               dst_id: hid_t; src_buf: pointer; dst_buf: pointer;
                               user_data: pointer): H5T_conv_ret_t {.cdecl.}

##  When this header is included from a private header, don't make calls to H5open()

# when not defined(H5private_H):
#   const
#     H5OPEN* = H5open()
# else:
#   const
#     H5OPEN* = true
## 
##  The IEEE floating point types in various byte orders.
##

var H5T_IEEE_F32BE_g* {.importc: "H5T_IEEE_F32BE_g", dynlib: libname.}: hid_t

var H5T_IEEE_F32LE_g* {.importc: "H5T_IEEE_F32LE_g", dynlib: libname.}: hid_t

var H5T_IEEE_F64BE_g* {.importc: "H5T_IEEE_F64BE_g", dynlib: libname.}: hid_t

var H5T_IEEE_F64LE_g* {.importc: "H5T_IEEE_F64LE_g", dynlib: libname.}: hid_t

let
  H5T_IEEE_F32BE* = H5T_IEEE_F32BE_g
  H5T_IEEE_F32LE* = H5T_IEEE_F32LE_g
  H5T_IEEE_F64BE* = H5T_IEEE_F64BE_g
  H5T_IEEE_F64LE* = H5T_IEEE_F64LE_g


## 
##  These are "standard" types.  For instance, signed (2's complement) and
##  unsigned integers of various sizes and byte orders.
## 

var H5T_STD_I8BE_g* {.importc: "H5T_STD_I8BE_g", dynlib: libname.}: hid_t

var H5T_STD_I8LE_g* {.importc: "H5T_STD_I8LE_g", dynlib: libname.}: hid_t

var H5T_STD_I16BE_g* {.importc: "H5T_STD_I16BE_g", dynlib: libname.}: hid_t

var H5T_STD_I16LE_g* {.importc: "H5T_STD_I16LE_g", dynlib: libname.}: hid_t

var H5T_STD_I32BE_g* {.importc: "H5T_STD_I32BE_g", dynlib: libname.}: hid_t

var H5T_STD_I32LE_g* {.importc: "H5T_STD_I32LE_g", dynlib: libname.}: hid_t

var H5T_STD_I64BE_g* {.importc: "H5T_STD_I64BE_g", dynlib: libname.}: hid_t

var H5T_STD_I64LE_g* {.importc: "H5T_STD_I64LE_g", dynlib: libname.}: hid_t

var H5T_STD_U8BE_g* {.importc: "H5T_STD_U8BE_g", dynlib: libname.}: hid_t

var H5T_STD_U8LE_g* {.importc: "H5T_STD_U8LE_g", dynlib: libname.}: hid_t

var H5T_STD_U16BE_g* {.importc: "H5T_STD_U16BE_g", dynlib: libname.}: hid_t

var H5T_STD_U16LE_g* {.importc: "H5T_STD_U16LE_g", dynlib: libname.}: hid_t

var H5T_STD_U32BE_g* {.importc: "H5T_STD_U32BE_g", dynlib: libname.}: hid_t

var H5T_STD_U32LE_g* {.importc: "H5T_STD_U32LE_g", dynlib: libname.}: hid_t

var H5T_STD_U64BE_g* {.importc: "H5T_STD_U64BE_g", dynlib: libname.}: hid_t

var H5T_STD_U64LE_g* {.importc: "H5T_STD_U64LE_g", dynlib: libname.}: hid_t

var H5T_STD_B8BE_g* {.importc: "H5T_STD_B8BE_g", dynlib: libname.}: hid_t

var H5T_STD_B8LE_g* {.importc: "H5T_STD_B8LE_g", dynlib: libname.}: hid_t

var H5T_STD_B16BE_g* {.importc: "H5T_STD_B16BE_g", dynlib: libname.}: hid_t

var H5T_STD_B16LE_g* {.importc: "H5T_STD_B16LE_g", dynlib: libname.}: hid_t

var H5T_STD_B32BE_g* {.importc: "H5T_STD_B32BE_g", dynlib: libname.}: hid_t

var H5T_STD_B32LE_g* {.importc: "H5T_STD_B32LE_g", dynlib: libname.}: hid_t

var H5T_STD_B64BE_g* {.importc: "H5T_STD_B64BE_g", dynlib: libname.}: hid_t

var H5T_STD_B64LE_g* {.importc: "H5T_STD_B64LE_g", dynlib: libname.}: hid_t

var H5T_STD_REF_OBJ_g* {.importc: "H5T_STD_REF_OBJ_g", dynlib: libname.}: hid_t

var H5T_STD_REF_DSETREG_g* {.importc: "H5T_STD_REF_DSETREG_g", dynlib: libname.}: hid_t

let
  H5T_STD_I8BE* = H5T_STD_I8BE_g
  H5T_STD_I8LE* = H5T_STD_I8LE_g
  H5T_STD_I16BE* = H5T_STD_I16BE_g
  H5T_STD_I16LE* = H5T_STD_I16LE_g
  H5T_STD_I32BE* = H5T_STD_I32BE_g
  H5T_STD_I32LE* = H5T_STD_I32LE_g
  H5T_STD_I64BE* = H5T_STD_I64BE_g
  H5T_STD_I64LE* = H5T_STD_I64LE_g
  H5T_STD_U8BE* = H5T_STD_U8BE_g
  H5T_STD_U8LE* = H5T_STD_U8LE_g
  H5T_STD_U16BE* = H5T_STD_U16BE_g
  H5T_STD_U16LE* = H5T_STD_U16LE_g
  H5T_STD_U32BE* = H5T_STD_U32BE_g
  H5T_STD_U32LE* = H5T_STD_U32LE_g
  H5T_STD_U64BE* = H5T_STD_U64BE_g
  H5T_STD_U64LE* = H5T_STD_U64LE_g
  H5T_STD_B8BE* = H5T_STD_B8BE_g
  H5T_STD_B8LE* = H5T_STD_B8LE_g
  H5T_STD_B16BE* = H5T_STD_B16BE_g
  H5T_STD_B16LE* = H5T_STD_B16LE_g
  H5T_STD_B32BE* = H5T_STD_B32BE_g
  H5T_STD_B32LE* = H5T_STD_B32LE_g
  H5T_STD_B64BE* = H5T_STD_B64BE_g
  H5T_STD_B64LE* = H5T_STD_B64LE_g
  H5T_STD_REF_OBJ* = H5T_STD_REF_OBJ_g
  H5T_STD_REF_DSETREG* = H5T_STD_REF_DSETREG_g


## 
##  Types which are particular to Unix.
## 

var H5T_UNIX_D32BE_g* {.importc: "H5T_UNIX_D32BE_g", dynlib: libname.}: hid_t

var H5T_UNIX_D32LE_g* {.importc: "H5T_UNIX_D32LE_g", dynlib: libname.}: hid_t

var H5T_UNIX_D64BE_g* {.importc: "H5T_UNIX_D64BE_g", dynlib: libname.}: hid_t

var H5T_UNIX_D64LE_g* {.importc: "H5T_UNIX_D64LE_g", dynlib: libname.}: hid_t

let
  H5T_UNIX_D32BE* = H5T_UNIX_D32BE_g
  H5T_UNIX_D32LE* = H5T_UNIX_D32LE_g
  H5T_UNIX_D64BE* = H5T_UNIX_D64BE_g
  H5T_UNIX_D64LE* = H5T_UNIX_D64LE_g


## 
##  Types particular to the C language.  String types use `bytes' instead
##  of `bits' as their size.
## 

var H5T_C_S1_g* {.importc: "H5T_C_S1_g", dynlib: libname.}: hid_t

let
  H5T_C_S1* = H5T_C_S1_g


## 
##  Types particular to Fortran.
## 

var H5T_FORTRAN_S1_g* {.importc: "H5T_FORTRAN_S1_g", dynlib: libname.}: hid_t

let
  H5T_FORTRAN_S1* = H5T_FORTRAN_S1_g

## 
##  These types are for Intel CPU's.  They are little endian with IEEE
##  floating point.
## 

let
  H5T_INTEL_I8* = H5T_STD_I8LE
  H5T_INTEL_I16* = H5T_STD_I16LE
  H5T_INTEL_I32* = H5T_STD_I32LE
  H5T_INTEL_I64* = H5T_STD_I64LE
  H5T_INTEL_U8* = H5T_STD_U8LE
  H5T_INTEL_U16* = H5T_STD_U16LE
  H5T_INTEL_U32* = H5T_STD_U32LE
  H5T_INTEL_U64* = H5T_STD_U64LE
  H5T_INTEL_B8* = H5T_STD_B8LE
  H5T_INTEL_B16* = H5T_STD_B16LE
  H5T_INTEL_B32* = H5T_STD_B32LE
  H5T_INTEL_B64* = H5T_STD_B64LE
  H5T_INTEL_F32* = H5T_IEEE_F32LE
  H5T_INTEL_F64* = H5T_IEEE_F64LE

## 
##  These types are for DEC Alpha CPU's.  They are little endian with IEEE
##  floating point.
## 

let
  H5T_ALPHA_I8* = H5T_STD_I8LE
  H5T_ALPHA_I16* = H5T_STD_I16LE
  H5T_ALPHA_I32* = H5T_STD_I32LE
  H5T_ALPHA_I64* = H5T_STD_I64LE
  H5T_ALPHA_U8* = H5T_STD_U8LE
  H5T_ALPHA_U16* = H5T_STD_U16LE
  H5T_ALPHA_U32* = H5T_STD_U32LE
  H5T_ALPHA_U64* = H5T_STD_U64LE
  H5T_ALPHA_B8* = H5T_STD_B8LE
  H5T_ALPHA_B16* = H5T_STD_B16LE
  H5T_ALPHA_B32* = H5T_STD_B32LE
  H5T_ALPHA_B64* = H5T_STD_B64LE
  H5T_ALPHA_F32* = H5T_IEEE_F32LE
  H5T_ALPHA_F64* = H5T_IEEE_F64LE

## 
##  These types are for MIPS cpu's commonly used in SGI systems. They are big
##  endian with IEEE floating point.
## 

let
  H5T_MIPS_I8* = H5T_STD_I8BE
  H5T_MIPS_I16* = H5T_STD_I16BE
  H5T_MIPS_I32* = H5T_STD_I32BE
  H5T_MIPS_I64* = H5T_STD_I64BE
  H5T_MIPS_U8* = H5T_STD_U8BE
  H5T_MIPS_U16* = H5T_STD_U16BE
  H5T_MIPS_U32* = H5T_STD_U32BE
  H5T_MIPS_U64* = H5T_STD_U64BE
  H5T_MIPS_B8* = H5T_STD_B8BE
  H5T_MIPS_B16* = H5T_STD_B16BE
  H5T_MIPS_B32* = H5T_STD_B32BE
  H5T_MIPS_B64* = H5T_STD_B64BE
  H5T_MIPS_F32* = H5T_IEEE_F32BE
  H5T_MIPS_F64* = H5T_IEEE_F64BE

## 
##  The VAX floating point types (i.e. in VAX byte order)
## 

var H5T_VAX_F32_g* {.importc: "H5T_VAX_F32_g", dynlib: libname.}: hid_t

var H5T_VAX_F64_g* {.importc: "H5T_VAX_F64_g", dynlib: libname.}: hid_t

let
  H5T_VAX_F32* = H5T_VAX_F32_g
  H5T_VAX_F64* = H5T_VAX_F64_g


## 
##  The predefined native types. These are the types detected by H5detect and
##  they violate the naming scheme a little.  Instead of a class name,
##  precision and byte order as the last component, they have a C-like type
##  name.  If the type begins with `U' then it is the unsigned version of the
##  integer type; other integer types are signed.  The type LLONG corresponds
##  to C's `long long' and LDOUBLE is `long double' (these types might be the
##  same as `LONG' and `DOUBLE' respectively).
## 

var H5T_NATIVE_SCHAR_g* {.importc: "H5T_NATIVE_SCHAR_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UCHAR_g* {.importc: "H5T_NATIVE_UCHAR_g", dynlib: libname.}: hid_t

var H5T_NATIVE_SHORT_g* {.importc: "H5T_NATIVE_SHORT_g", dynlib: libname.}: hid_t

var H5T_NATIVE_USHORT_g* {.importc: "H5T_NATIVE_USHORT_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_g* {.importc: "H5T_NATIVE_INT_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_g* {.importc: "H5T_NATIVE_UINT_g", dynlib: libname.}: hid_t

var H5T_NATIVE_LONG_g* {.importc: "H5T_NATIVE_LONG_g", dynlib: libname.}: hid_t

var H5T_NATIVE_ULONG_g* {.importc: "H5T_NATIVE_ULONG_g", dynlib: libname.}: hid_t

var H5T_NATIVE_LLONG_g* {.importc: "H5T_NATIVE_LLONG_g", dynlib: libname.}: hid_t

var H5T_NATIVE_ULLONG_g* {.importc: "H5T_NATIVE_ULLONG_g", dynlib: libname.}: hid_t

var H5T_NATIVE_FLOAT_g* {.importc: "H5T_NATIVE_FLOAT_g", dynlib: libname.}: hid_t

var H5T_NATIVE_DOUBLE_g* {.importc: "H5T_NATIVE_DOUBLE_g", dynlib: libname.}: hid_t


const H5_SIZEOF_LONG_DOUBLE = sizeof(clongdouble)
when H5_SIZEOF_LONG_DOUBLE != 0:
  var H5T_NATIVE_LDOUBLE_g* {.importc: "H5T_NATIVE_LDOUBLE_g", dynlib: libname.}: hid_t
var H5T_NATIVE_B8_g* {.importc: "H5T_NATIVE_B8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_B16_g* {.importc: "H5T_NATIVE_B16_g", dynlib: libname.}: hid_t

var H5T_NATIVE_B32_g* {.importc: "H5T_NATIVE_B32_g", dynlib: libname.}: hid_t

var H5T_NATIVE_B64_g* {.importc: "H5T_NATIVE_B64_g", dynlib: libname.}: hid_t

var H5T_NATIVE_OPAQUE_g* {.importc: "H5T_NATIVE_OPAQUE_g", dynlib: libname.}: hid_t

var H5T_NATIVE_HADDR_g* {.importc: "H5T_NATIVE_HADDR_g", dynlib: libname.}: hid_t

var H5T_NATIVE_HSIZE_g* {.importc: "H5T_NATIVE_HSIZE_g", dynlib: libname.}: hid_t

var H5T_NATIVE_HSSIZE_g* {.importc: "H5T_NATIVE_HSSIZE_g", dynlib: libname.}: hid_t

var H5T_NATIVE_HERR_g* {.importc: "H5T_NATIVE_HERR_g", dynlib: libname.}: hid_t

var H5T_NATIVE_HBOOL_g* {.importc: "H5T_NATIVE_HBOOL_g", dynlib: libname.}: hid_t

let
  H5T_NATIVE_SCHAR* = H5T_NATIVE_SCHAR_g
  H5T_NATIVE_CHAR* = H5T_NATIVE_SCHAR
  H5T_NATIVE_UCHAR* = H5T_NATIVE_UCHAR_g
  H5T_NATIVE_SHORT* = H5T_NATIVE_SHORT_g
  H5T_NATIVE_USHORT* = H5T_NATIVE_USHORT_g
  H5T_NATIVE_INT* = H5T_NATIVE_INT_g
  H5T_NATIVE_UINT* = H5T_NATIVE_UINT_g
  H5T_NATIVE_LONG* = H5T_NATIVE_LONG_g
  H5T_NATIVE_ULONG* = H5T_NATIVE_ULONG_g
  H5T_NATIVE_LLONG* = H5T_NATIVE_LLONG_g
  H5T_NATIVE_ULLONG* = H5T_NATIVE_ULLONG_g
  H5T_NATIVE_FLOAT* = H5T_NATIVE_FLOAT_g
  H5T_NATIVE_DOUBLE* = H5T_NATIVE_DOUBLE_g

when H5_SIZEOF_LONG_DOUBLE != 0:
  let
    H5T_NATIVE_LDOUBLE* = H5T_NATIVE_LDOUBLE_g
let
  H5T_NATIVE_B8* = H5T_NATIVE_B8_g
  H5T_NATIVE_B16* = H5T_NATIVE_B16_g
  H5T_NATIVE_B32* = H5T_NATIVE_B32_g
  H5T_NATIVE_B64* = H5T_NATIVE_B64_g
  H5T_NATIVE_OPAQUE* = H5T_NATIVE_OPAQUE_g
  H5T_NATIVE_HADDR* = H5T_NATIVE_HADDR_g
  H5T_NATIVE_HSIZE* = H5T_NATIVE_HSIZE_g
  H5T_NATIVE_HSSIZE* = H5T_NATIVE_HSSIZE_g
  H5T_NATIVE_HERR* = H5T_NATIVE_HERR_g
  H5T_NATIVE_HBOOL* = H5T_NATIVE_HBOOL_g



##  C9x integer types

var H5T_NATIVE_INT8_g* {.importc: "H5T_NATIVE_INT8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT8_g* {.importc: "H5T_NATIVE_UINT8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_LEAST8_g* {.importc: "H5T_NATIVE_INT_LEAST8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_LEAST8_g* {.importc: "H5T_NATIVE_UINT_LEAST8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_FAST8_g* {.importc: "H5T_NATIVE_INT_FAST8_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_FAST8_g* {.importc: "H5T_NATIVE_UINT_FAST8_g", dynlib: libname.}: hid_t

let
  H5T_NATIVE_INT8* = H5T_NATIVE_INT8_g
  H5T_NATIVE_UINT8* = H5T_NATIVE_UINT8_g
  H5T_NATIVE_INT_LEAST8* = H5T_NATIVE_INT_LEAST8_g
  H5T_NATIVE_UINT_LEAST8* = H5T_NATIVE_UINT_LEAST8_g
  H5T_NATIVE_INT_FAST8* = H5T_NATIVE_INT_FAST8_g
  H5T_NATIVE_UINT_FAST8* = H5T_NATIVE_UINT_FAST8_g

var H5T_NATIVE_INT16_g* {.importc: "H5T_NATIVE_INT16_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT16_g* {.importc: "H5T_NATIVE_UINT16_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_LEAST16_g* {.importc: "H5T_NATIVE_INT_LEAST16_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_LEAST16_g* {.importc: "H5T_NATIVE_UINT_LEAST16_g",
                               dynlib: libname.}: hid_t

var H5T_NATIVE_INT_FAST16_g* {.importc: "H5T_NATIVE_INT_FAST16_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_FAST16_g* {.importc: "H5T_NATIVE_UINT_FAST16_g", dynlib: libname.}: hid_t

let 
  H5T_NATIVE_INT16* = H5T_NATIVE_INT16_g
  H5T_NATIVE_UINT16* = H5T_NATIVE_UINT16_g
  H5T_NATIVE_INT_LEAST16* = H5T_NATIVE_INT_LEAST16_g
  H5T_NATIVE_UINT_LEAST16* = H5T_NATIVE_UINT_LEAST16_g
  H5T_NATIVE_INT_FAST16* = H5T_NATIVE_INT_FAST16_g
  H5T_NATIVE_UINT_FAST16* = H5T_NATIVE_UINT_FAST16_g

var H5T_NATIVE_INT32_g* {.importc: "H5T_NATIVE_INT32_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT32_g* {.importc: "H5T_NATIVE_UINT32_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_LEAST32_g* {.importc: "H5T_NATIVE_INT_LEAST32_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_LEAST32_g* {.importc: "H5T_NATIVE_UINT_LEAST32_g",
                               dynlib: libname.}: hid_t

var H5T_NATIVE_INT_FAST32_g* {.importc: "H5T_NATIVE_INT_FAST32_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_FAST32_g* {.importc: "H5T_NATIVE_UINT_FAST32_g", dynlib: libname.}: hid_t

let 
  H5T_NATIVE_INT32* = H5T_NATIVE_INT32_g
  H5T_NATIVE_UINT32* = H5T_NATIVE_UINT32_g
  H5T_NATIVE_INT_LEAST32* = H5T_NATIVE_INT_LEAST32_g
  H5T_NATIVE_UINT_LEAST32* = H5T_NATIVE_UINT_LEAST32_g
  H5T_NATIVE_INT_FAST32* = H5T_NATIVE_INT_FAST32_g
  H5T_NATIVE_UINT_FAST32* = H5T_NATIVE_UINT_FAST32_g

var H5T_NATIVE_INT64_g* {.importc: "H5T_NATIVE_INT64_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT64_g* {.importc: "H5T_NATIVE_UINT64_g", dynlib: libname.}: hid_t

var H5T_NATIVE_INT_LEAST64_g* {.importc: "H5T_NATIVE_INT_LEAST64_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_LEAST64_g* {.importc: "H5T_NATIVE_UINT_LEAST64_g",
                               dynlib: libname.}: hid_t

var H5T_NATIVE_INT_FAST64_g* {.importc: "H5T_NATIVE_INT_FAST64_g", dynlib: libname.}: hid_t

var H5T_NATIVE_UINT_FAST64_g* {.importc: "H5T_NATIVE_UINT_FAST64_g", dynlib: libname.}: hid_t

let
  H5T_NATIVE_INT64* = H5T_NATIVE_INT64_g
  H5T_NATIVE_UINT64* = H5T_NATIVE_UINT64_g
  H5T_NATIVE_INT_LEAST64* = H5T_NATIVE_INT_LEAST64_g
  H5T_NATIVE_UINT_LEAST64* = H5T_NATIVE_UINT_LEAST64_g
  H5T_NATIVE_INT_FAST64* = H5T_NATIVE_INT_FAST64_g
  H5T_NATIVE_UINT_FAST64* = H5T_NATIVE_UINT_FAST64_g

##  Operations defined on all datatypes

proc H5Tcreate*(`type`: H5T_class_t; size: csize): hid_t {.cdecl, importc: "H5Tcreate",
    dynlib: libname.}
proc H5Tcopy*(type_id: hid_t): hid_t {.cdecl, importc: "H5Tcopy", dynlib: libname.}
proc H5Tclose*(type_id: hid_t): herr_t {.cdecl, importc: "H5Tclose", dynlib: libname.}
proc H5Tequal*(type1_id: hid_t; type2_id: hid_t): htri_t {.cdecl, importc: "H5Tequal",
    dynlib: libname.}
proc H5Tlock*(type_id: hid_t): herr_t {.cdecl, importc: "H5Tlock", dynlib: libname.}
proc H5Tcommit2*(loc_id: hid_t; name: cstring; type_id: hid_t; lcpl_id: hid_t;
                tcpl_id: hid_t; tapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Tcommit2", dynlib: libname.}
proc H5Topen2*(loc_id: hid_t; name: cstring; tapl_id: hid_t): hid_t {.cdecl,
    importc: "H5Topen2", dynlib: libname.}
proc H5Tcommit_anon*(loc_id: hid_t; type_id: hid_t; tcpl_id: hid_t; tapl_id: hid_t): herr_t {.
    cdecl, importc: "H5Tcommit_anon", dynlib: libname.}
proc H5Tget_create_plist*(type_id: hid_t): hid_t {.cdecl,
    importc: "H5Tget_create_plist", dynlib: libname.}
proc H5Tcommitted*(type_id: hid_t): htri_t {.cdecl, importc: "H5Tcommitted",
    dynlib: libname.}
proc H5Tencode*(obj_id: hid_t; buf: pointer; nalloc: ptr csize): herr_t {.cdecl,
    importc: "H5Tencode", dynlib: libname.}
proc H5Tdecode*(buf: pointer): hid_t {.cdecl, importc: "H5Tdecode", dynlib: libname.}
proc H5Tflush*(type_id: hid_t): herr_t {.cdecl, importc: "H5Tflush", dynlib: libname.}
proc H5Trefresh*(type_id: hid_t): herr_t {.cdecl, importc: "H5Trefresh",
                                       dynlib: libname.}
##  Operations defined on compound datatypes

proc H5Tinsert*(parent_id: hid_t; name: cstring; offset: csize; member_id: hid_t): herr_t {.
    cdecl, importc: "H5Tinsert", dynlib: libname.}
proc H5Tpack*(type_id: hid_t): herr_t {.cdecl, importc: "H5Tpack", dynlib: libname.}
##  Operations defined on enumeration datatypes

proc H5Tenum_create*(base_id: hid_t): hid_t {.cdecl, importc: "H5Tenum_create",
    dynlib: libname.}
proc H5Tenum_insert*(`type`: hid_t; name: cstring; value: pointer): herr_t {.cdecl,
    importc: "H5Tenum_insert", dynlib: libname.}
proc H5Tenum_nameof*(`type`: hid_t; value: pointer; name: cstring; ## out
                    size: csize): herr_t {.cdecl, importc: "H5Tenum_nameof",
                                        dynlib: libname.}
proc H5Tenum_valueof*(`type`: hid_t; name: cstring; value: pointer): herr_t {.cdecl,
    importc: "H5Tenum_valueof", dynlib: libname.}
  ## out
##  Operations defined on variable-length datatypes

proc H5Tvlen_create*(base_id: hid_t): hid_t {.cdecl, importc: "H5Tvlen_create",
    dynlib: libname.}
##  Operations defined on array datatypes

proc H5Tarray_create2*(base_id: hid_t; ndims: cuint; dim: ptr hsize_t): hid_t {.cdecl,
    importc: "H5Tarray_create2", dynlib: libname.}
  ##  ndims
proc H5Tget_array_ndims*(type_id: hid_t): cint {.cdecl,
    importc: "H5Tget_array_ndims", dynlib: libname.}
proc H5Tget_array_dims2*(type_id: hid_t; dims: ptr hsize_t): cint {.cdecl,
    importc: "H5Tget_array_dims2", dynlib: libname.}
##  Operations defined on opaque datatypes

proc H5Tset_tag*(`type`: hid_t; tag: cstring): herr_t {.cdecl, importc: "H5Tset_tag",
    dynlib: libname.}
proc H5Tget_tag*(`type`: hid_t): cstring {.cdecl, importc: "H5Tget_tag",
                                       dynlib: libname.}
##  Querying property values

proc H5Tget_super*(`type`: hid_t): hid_t {.cdecl, importc: "H5Tget_super",
                                       dynlib: libname.}
proc H5Tget_class*(type_id: hid_t): H5T_class_t {.cdecl, importc: "H5Tget_class",
    dynlib: libname.}
proc H5Tdetect_class*(type_id: hid_t; cls: H5T_class_t): htri_t {.cdecl,
    importc: "H5Tdetect_class", dynlib: libname.}
proc H5Tget_size*(type_id: hid_t): csize {.cdecl, importc: "H5Tget_size",
                                       dynlib: libname.}
proc H5Tget_order*(type_id: hid_t): H5T_order_t {.cdecl, importc: "H5Tget_order",
    dynlib: libname.}
proc H5Tget_precision*(type_id: hid_t): csize {.cdecl, importc: "H5Tget_precision",
    dynlib: libname.}
proc H5Tget_offset*(type_id: hid_t): cint {.cdecl, importc: "H5Tget_offset",
                                        dynlib: libname.}
proc H5Tget_pad*(type_id: hid_t; lsb: ptr H5T_pad_t; ## out
                msb: ptr H5T_pad_t): herr_t {.cdecl, importc: "H5Tget_pad",
    dynlib: libname.}
  ## out
proc H5Tget_sign*(type_id: hid_t): H5T_sign_t {.cdecl, importc: "H5Tget_sign",
    dynlib: libname.}
proc H5Tget_fields*(type_id: hid_t; spos: ptr csize; ## out
                   epos: ptr csize; ## out
                   esize: ptr csize; ## out
                   mpos: ptr csize; ## out
                   msize: ptr csize): herr_t {.cdecl, importc: "H5Tget_fields",
    dynlib: libname.}
  ## out
proc H5Tget_ebias*(type_id: hid_t): csize {.cdecl, importc: "H5Tget_ebias",
                                        dynlib: libname.}
proc H5Tget_norm*(type_id: hid_t): H5T_norm_t {.cdecl, importc: "H5Tget_norm",
    dynlib: libname.}
proc H5Tget_inpad*(type_id: hid_t): H5T_pad_t {.cdecl, importc: "H5Tget_inpad",
    dynlib: libname.}
proc H5Tget_strpad*(type_id: hid_t): H5T_str_t {.cdecl, importc: "H5Tget_strpad",
    dynlib: libname.}
proc H5Tget_nmembers*(type_id: hid_t): cint {.cdecl, importc: "H5Tget_nmembers",
    dynlib: libname.}
proc H5Tget_member_name*(type_id: hid_t; membno: cuint): cstring {.cdecl,
    importc: "H5Tget_member_name", dynlib: libname.}
proc H5Tget_member_index*(type_id: hid_t; name: cstring): cint {.cdecl,
    importc: "H5Tget_member_index", dynlib: libname.}
proc H5Tget_member_offset*(type_id: hid_t; membno: cuint): csize {.cdecl,
    importc: "H5Tget_member_offset", dynlib: libname.}
proc H5Tget_member_class*(type_id: hid_t; membno: cuint): H5T_class_t {.cdecl,
    importc: "H5Tget_member_class", dynlib: libname.}
proc H5Tget_member_type*(type_id: hid_t; membno: cuint): hid_t {.cdecl,
    importc: "H5Tget_member_type", dynlib: libname.}
proc H5Tget_member_value*(type_id: hid_t; membno: cuint; value: pointer): herr_t {.
    cdecl, importc: "H5Tget_member_value", dynlib: libname.}
  ## out
proc H5Tget_cset*(type_id: hid_t): H5T_cset_t {.cdecl, importc: "H5Tget_cset",
    dynlib: libname.}
proc H5Tis_variable_str*(type_id: hid_t): htri_t {.cdecl,
    importc: "H5Tis_variable_str", dynlib: libname.}
proc H5Tget_native_type*(type_id: hid_t; direction: H5T_direction_t): hid_t {.cdecl,
    importc: "H5Tget_native_type", dynlib: libname.}
##  Setting property values

proc H5Tset_size*(type_id: hid_t; size: csize): herr_t {.cdecl, importc: "H5Tset_size",
    dynlib: libname.}
proc H5Tset_order*(type_id: hid_t; order: H5T_order_t): herr_t {.cdecl,
    importc: "H5Tset_order", dynlib: libname.}
proc H5Tset_precision*(type_id: hid_t; prec: csize): herr_t {.cdecl,
    importc: "H5Tset_precision", dynlib: libname.}
proc H5Tset_offset*(type_id: hid_t; offset: csize): herr_t {.cdecl,
    importc: "H5Tset_offset", dynlib: libname.}
proc H5Tset_pad*(type_id: hid_t; lsb: H5T_pad_t; msb: H5T_pad_t): herr_t {.cdecl,
    importc: "H5Tset_pad", dynlib: libname.}
proc H5Tset_sign*(type_id: hid_t; sign: H5T_sign_t): herr_t {.cdecl,
    importc: "H5Tset_sign", dynlib: libname.}
proc H5Tset_fields*(type_id: hid_t; spos: csize; epos: csize; esize: csize; mpos: csize;
                   msize: csize): herr_t {.cdecl, importc: "H5Tset_fields",
                                        dynlib: libname.}
proc H5Tset_ebias*(type_id: hid_t; ebias: csize): herr_t {.cdecl,
    importc: "H5Tset_ebias", dynlib: libname.}
proc H5Tset_norm*(type_id: hid_t; norm: H5T_norm_t): herr_t {.cdecl,
    importc: "H5Tset_norm", dynlib: libname.}
proc H5Tset_inpad*(type_id: hid_t; pad: H5T_pad_t): herr_t {.cdecl,
    importc: "H5Tset_inpad", dynlib: libname.}
proc H5Tset_cset*(type_id: hid_t; cset: H5T_cset_t): herr_t {.cdecl,
    importc: "H5Tset_cset", dynlib: libname.}
proc H5Tset_strpad*(type_id: hid_t; strpad: H5T_str_t): herr_t {.cdecl,
    importc: "H5Tset_strpad", dynlib: libname.}
##  Type conversion database

proc H5Tregister*(pers: H5T_pers_t; name: cstring; src_id: hid_t; dst_id: hid_t;
                 `func`: H5T_conv_t): herr_t {.cdecl, importc: "H5Tregister",
    dynlib: libname.}
proc H5Tunregister*(pers: H5T_pers_t; name: cstring; src_id: hid_t; dst_id: hid_t;
                   `func`: H5T_conv_t): herr_t {.cdecl, importc: "H5Tunregister",
    dynlib: libname.}
proc H5Tfind*(src_id: hid_t; dst_id: hid_t; pcdata: ptr ptr H5T_cdata_t): H5T_conv_t {.
    cdecl, importc: "H5Tfind", dynlib: libname.}
proc H5Tcompiler_conv*(src_id: hid_t; dst_id: hid_t): htri_t {.cdecl,
    importc: "H5Tcompiler_conv", dynlib: libname.}
proc H5Tconvert*(src_id: hid_t; dst_id: hid_t; nelmts: csize; buf: pointer;
                background: pointer; plist_id: hid_t): herr_t {.cdecl,
    importc: "H5Tconvert", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
## 
##  Use of these symbols is deprecated.
## 

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  Typedefs
  ##  Function prototypes
  proc H5Tcommit1*(loc_id: hid_t; name: cstring; type_id: hid_t): herr_t {.cdecl,
      importc: "H5Tcommit1", dynlib: libname.}
  proc H5Topen1*(loc_id: hid_t; name: cstring): hid_t {.cdecl, importc: "H5Topen1",
      dynlib: libname.}
  proc H5Tarray_create1*(base_id: hid_t; ndims: cint; dim: ptr hsize_t; ##  ndims
                        perm: ptr cint): hid_t {.cdecl, importc: "H5Tarray_create1",
      dynlib: libname.}
    ##  ndims
  proc H5Tget_array_dims1*(type_id: hid_t; dims: ptr hsize_t; perm: ptr cint): cint {.
      cdecl, importc: "H5Tget_array_dims1", dynlib: libname.}
