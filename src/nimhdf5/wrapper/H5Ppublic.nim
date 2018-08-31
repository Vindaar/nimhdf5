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
##  This file contains function prototypes for each exported function in the
##  H5P module.
##

##  System headers needed by this file
##  Public headers needed by this file

import
  H5public, H5ACpublic, H5Dpublic, H5Fpublic, H5FDpublic, H5Ipublic, H5Lpublic,
  H5Opublic, H5MMpublic, H5Tpublic, H5Zpublic, ../H5nimtypes, ../h5libname


# before we can import any of the variables, from the already shared library
# we need to make sure that they are defined. The library needs to be
# initialized. Thus we include
include H5niminitialize


##  Common creation order flags (for links in groups and attributes on objects)

const
  H5P_CRT_ORDER_TRACKED* = 0x00000001
  H5P_CRT_ORDER_INDEXED* = 0x00000002

##  Default value for all property list classes

const
  H5P_DEFAULT* = hid_t(0)

## *****************
##  Public Typedefs
## *****************
##  Define property list class callback function pointer types

type
  H5P_cls_create_func_t* = proc (prop_id: hid_t; create_data: pointer): herr_t {.cdecl.}
  H5P_cls_copy_func_t* = proc (new_prop_id: hid_t; old_prop_id: hid_t;
                            copy_data: pointer): herr_t {.cdecl.}
  H5P_cls_close_func_t* = proc (prop_id: hid_t; close_data: pointer): herr_t {.cdecl.}

##  Define property list callback function pointer types

type
  H5P_prp_cb1_t* = proc (name: cstring; size: csize; value: pointer): herr_t {.cdecl.}
  H5P_prp_cb2_t* = proc (prop_id: hid_t; name: cstring; size: csize; value: pointer): herr_t {.
      cdecl.}
  H5P_prp_create_func_t* = H5P_prp_cb1_t
  H5P_prp_set_func_t* = H5P_prp_cb2_t
  H5P_prp_get_func_t* = H5P_prp_cb2_t
  H5P_prp_encode_func_t* = proc (value: pointer; buf: ptr pointer; size: ptr csize): herr_t {.
      cdecl.}
  H5P_prp_decode_func_t* = proc (buf: ptr pointer; value: pointer): herr_t {.cdecl.}
  H5P_prp_delete_func_t* = H5P_prp_cb2_t
  H5P_prp_copy_func_t* = H5P_prp_cb1_t
  H5P_prp_compare_func_t* = proc (value1: pointer; value2: pointer; size: csize): cint {.
      cdecl.}
  H5P_prp_close_func_t* = H5P_prp_cb1_t

##  Define property list iteration function type

type
  H5P_iterate_t* = proc (id: hid_t; name: cstring; iter_data: pointer): herr_t {.cdecl.}

##  Actual IO mode property

type ##  The default value, H5D_MPIO_NO_CHUNK_OPTIMIZATION, is used for all I/O
    ##  operations that do not use chunk optimizations, including non-collective
    ##  I/O and contiguous collective I/O.
    ##
    ##  The following four values are conveniently defined as a bit field so that
    ##  we can switch from the default to indpendent or collective and then to
    ##  mixed without having to check the original value.
    ##
    ##  NO_COLLECTIVE means that either collective I/O wasn't requested or that
    ##  no I/O took place.
    ##
    ##  CHUNK_INDEPENDENT means that collective I/O was requested, but the
    ##  chunk optimization scheme chose independent I/O for each chunk.
    ##
  H5D_mpio_actual_chunk_opt_mode_t* {.size: sizeof(cint).} = enum
    H5D_MPIO_NO_CHUNK_OPTIMIZATION = 0, H5D_MPIO_LINK_CHUNK, H5D_MPIO_MULTI_CHUNK
  H5D_mpio_actual_io_mode_t* {.size: sizeof(cint).} = enum
    H5D_MPIO_NO_COLLECTIVE = 0x00000000, H5D_MPIO_CHUNK_INDEPENDENT = 0x00000001,
    H5D_MPIO_CHUNK_COLLECTIVE = 0x00000002, H5D_MPIO_CHUNK_MIXED = 0x00000001 or
        0x00000002,           ##  The contiguous case is separate from the bit field.
    H5D_MPIO_CONTIGUOUS_COLLECTIVE = 0x00000004



##  Broken collective IO property

type
  H5D_mpio_no_collective_cause_t* {.size: sizeof(cint).} = enum
    H5D_MPIO_COLLECTIVE = 0x00000000, H5D_MPIO_SET_INDEPENDENT = 0x00000001,
    H5D_MPIO_DATATYPE_CONVERSION = 0x00000002,
    H5D_MPIO_DATA_TRANSFORMS = 0x00000004,
    H5D_MPIO_MPI_OPT_TYPES_ENV_VAR_DISABLED = 0x00000008,
    H5D_MPIO_NOT_SIMPLE_OR_SCALAR_DATASPACES = 0x00000010,
    H5D_MPIO_NOT_CONTIGUOUS_OR_CHUNKED_DATASET = 0x00000020,
    H5D_MPIO_FILTERS = 0x00000040


## ******************
##  Public Variables
## ******************
##  Property list class IDs
##  (Internal to library, do not use!  Use macros above)

## NOTE: these lines are not used. They are what c2nim did
## with the e.g.
## H5_DLLVAR hid_t H5P_CLS_DATASET_CREATE_ID_g;
## lines. However, as the comment above mentions, these are
## not to be used. Instead the macros (in this library below,
## not above) are to be used. See the long comment further
## down in the file regarding what is actually being used.

#var H5P_CLS_ROOT_ID_g* {.importc: "H5P_CLS_ROOT_ID_g", dynlib: libname.}: hid_t
#var H5P_CLS_ROOT_ID_g* {.importc: "H5P_CLS_ROOT_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_OBJECT_CREATE_ID_g* {.importc: "H5P_CLS_OBJECT_CREATE_ID_g",
#                                   dynlib: libname.}: hid_t

# var H5P_CLS_FILE_CREATE_ID_g* {.importc: "H5P_CLS_FILE_CREATE_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_FILE_ACCESS_ID_g* {.importc: "H5P_CLS_FILE_ACCESS_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_DATASET_CREATE_ID_g* {.importc: "H5P_CLS_DATASET_CREATE_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_CLS_DATASET_ACCESS_ID_g* {.importc: "H5P_CLS_DATASET_ACCESS_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_CLS_DATASET_XFER_ID_g* {.importc: "H5P_CLS_DATASET_XFER_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_CLS_FILE_MOUNT_ID_g* {.importc: "H5P_CLS_FILE_MOUNT_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_GROUP_CREATE_ID_g* {.importc: "H5P_CLS_GROUP_CREATE_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_CLS_GROUP_ACCESS_ID_g* {.importc: "H5P_CLS_GROUP_ACCESS_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_CLS_DATATYPE_CREATE_ID_g* {.importc: "H5P_CLS_DATATYPE_CREATE_ID_g",
#                                   dynlib: libname.}: hid_t

# var H5P_CLS_DATATYPE_ACCESS_ID_g* {.importc: "H5P_CLS_DATATYPE_ACCESS_ID_g",
#                                   dynlib: libname.}: hid_t

# var H5P_CLS_STRING_CREATE_ID_g* {.importc: "H5P_CLS_STRING_CREATE_ID_g",
#                                 dynlib: libname.}: hid_t

# var H5P_CLS_ATTRIBUTE_CREATE_ID_g* {.importc: "H5P_CLS_ATTRIBUTE_CREATE_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_CLS_ATTRIBUTE_ACCESS_ID_g* {.importc: "H5P_CLS_ATTRIBUTE_ACCESS_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_CLS_OBJECT_COPY_ID_g* {.importc: "H5P_CLS_OBJECT_COPY_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_LINK_CREATE_ID_g* {.importc: "H5P_CLS_LINK_CREATE_ID_g", dynlib: libname.}: hid_t

# var H5P_CLS_LINK_ACCESS_ID_g* {.importc: "H5P_CLS_LINK_ACCESS_ID_g", dynlib: libname.}: hid_t

# ##  Default roperty list IDs
# ##  (Internal to library, do not use!  Use macros above)

# var H5P_LST_FILE_CREATE_ID_g* {.importc: "H5P_LST_FILE_CREATE_ID_g", dynlib: libname.}: hid_t

# var H5P_LST_FILE_ACCESS_ID_g* {.importc: "H5P_LST_FILE_ACCESS_ID_g", dynlib: libname.}: hid_t

# var H5P_LST_DATASET_CREATE_ID_g* {.importc: "H5P_LST_DATASET_CREATE_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_LST_DATASET_ACCESS_ID_g* {.importc: "H5P_LST_DATASET_ACCESS_ID_g",
#                                  dynlib: libname.}: hid_t

# var H5P_LST_DATASET_XFER_ID_g* {.importc: "H5P_LST_DATASET_XFER_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_LST_FILE_MOUNT_ID_g* {.importc: "H5P_LST_FILE_MOUNT_ID_g", dynlib: libname.}: hid_t

# var H5P_LST_GROUP_CREATE_ID_g* {.importc: "H5P_LST_GROUP_CREATE_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_LST_GROUP_ACCESS_ID_g* {.importc: "H5P_LST_GROUP_ACCESS_ID_g",
#                                dynlib: libname.}: hid_t

# var H5P_LST_DATATYPE_CREATE_ID_g* {.importc: "H5P_LST_DATATYPE_CREATE_ID_g",
#                                   dynlib: libname.}: hid_t

# var H5P_LST_DATATYPE_ACCESS_ID_g* {.importc: "H5P_LST_DATATYPE_ACCESS_ID_g",
#                                   dynlib: libname.}: hid_t

# var H5P_LST_ATTRIBUTE_CREATE_ID_g* {.importc: "H5P_LST_ATTRIBUTE_CREATE_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_LST_ATTRIBUTE_ACCESS_ID_g* {.importc: "H5P_LST_ATTRIBUTE_ACCESS_ID_g",
#                                    dynlib: libname.}: hid_t

# var H5P_LST_OBJECT_COPY_ID_g* {.importc: "H5P_LST_OBJECT_COPY_ID_g", dynlib: libname.}: hid_t

# var H5P_LST_LINK_CREATE_ID_g* {.importc: "H5P_LST_LINK_CREATE_ID_g", dynlib: libname.}: hid_t

# var H5P_LST_LINK_ACCESS_ID_g* {.importc: "H5P_LST_LINK_ACCESS_ID_g", dynlib: libname.}: hid_t

# ## ***************
# ##  Public Macros
# ## ***************
# ##  When this header is included from a private HDF5 header, don't make calls to H5open()
# ##  #undef H5OPEN
# ##  #ifndef _H5private_H
# ##  #define H5OPEN        H5open(),
# ##  #else   /\* _H5private_H *\/
# ##  #define H5OPEN
# ##  #endif  /\* _H5private_H *\/
# ##
# ##  The library's property list classes
# ##


############################################################
########################### NOTE ###########################
############################################################
############################################################
# For some reason, which is not entirely clear to me,      #
# if we try to import the following variables by their     #
# (in my opinion) expected name, e.g.                      #
# H5P_DATASET_ACCESS -> H5P_CLS_DATASET_ACCESS_ID_g,       #
# because that is what the C macro resolves to, the        #
# program compiles, but complains with a                   #
# "could not import: <SymbolName>"                         #
# error. The way I understand the C code from my glance    #
# at it, this seems unexpected, but well. Importing the    #
# variables by the `_g` instead of `_ID_g` names seems     #
# to work as expected. The H5Pprivate.h file contains      #
# definitios such as                                       #
# H5P_genclass_t *H5P_CLS_DATASET_CREATE_g        = NULL;  #
# hid_t H5P_CLS_DATASET_ACCESS_ID_g               = FAIL;  #
# which is why I find it confusing (besides the C macros). #
# I mean the header comments of this file mention that one #
# should not use the variables defined, but rather the     #
# macros. But well..?!                                     #
#                                                          #
# I suppose the answer to this mistery lies in my stupidity#
# wrt basing the wrapper on HDF5 1.10.1, while working on a#
# HDF5 1.8 system without keeping that in mind...!         #
############################################################


# TODO:
# with the Hdf5 1.10.1 libarry these seem to make some problems too. When creating
# dataset access / create property list, the call to HDF5 fails with a
# `wrong argument type` error

# TODO: include a when based on HDF5 version or something along
# this line and either importc _ID_g variables for HDF5 1.10.1
# or _g (without ID) for HDF5 1.8


when defined(H5_LEGACY):
  var
    H5P_ROOT* {.importc: "H5P_CLS_ROOT_g", dynlib: libname.}: hid_t
    H5P_OBJECT_CREATE* {.importc: "H5P_CLS_OBJECT_CREATE_g", dynlib: libname.}: hid_t
    H5P_FILE_CREATE* {.importc: "H5P_CLS_FILE_CREATE_g", dynlib: libname.}: hid_t
    H5P_FILE_ACCESS* {.importc: "H5P_CLS_FILE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATASET_CREATE* {.importc: "H5P_CLS_DATASET_CREATE_g", dynlib: libname.}: hid_t
    H5P_DATASET_ACCESS* {.importc: "H5P_CLS_DATASET_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATASET_XFER* {.importc: "H5P_CLS_DATASET_XFER_g", dynlib: libname.}: hid_t
    H5P_FILE_MOUNT* {.importc: "H5P_CLS_FILE_MOUNT_g", dynlib: libname.}: hid_t
    H5P_GROUP_CREATE* {.importc: "H5P_CLS_GROUP_CREATE_g", dynlib: libname.}: hid_t
    H5P_GROUP_ACCESS* {.importc: "H5P_CLS_GROUP_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_CREATE* {.importc: "H5P_CLS_DATATYPE_CREATE_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_ACCESS* {.importc: "H5P_CLS_DATATYPE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_STRING_CREATE* {.importc: "H5P_CLS_STRING_CREATE_g", dynlib: libname.}: hid_t
    H5P_ATTRIBUTE_CREATE* {.importc: "H5P_CLS_ATTRIBUTE_CREATE_g", dynlib: libname.}: hid_t

    ## NOTE:
    ## For some weird reason Attribute access is still not found?!
    ## Maybe they were only added in HDF5 v. 1.10.x ? This computer
    ## still only uses 1.8, I believe?
    #H5P_ATTRIBUTE_ACCESS* {.importc: "H5P_CLS_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_OBJECT_COPY* {.importc: "H5P_CLS_OBJECT_COPY_g", dynlib: libname.}: hid_t
    H5P_LINK_CREATE* {.importc: "H5P_CLS_LINK_CREATE_g", dynlib: libname.}: hid_t
    H5P_LINK_ACCESS* {.importc: "H5P_CLS_LINK_ACCESS_g", dynlib: libname.}: hid_t

    H5P_FILE_CREATE_DEFAULT* {.importc: "H5P_LST_FILE_CREATE_g", dynlib: libname.}: hid_t
    H5P_FILE_ACCESS_DEFAULT* {.importc: "H5P_LST_FILE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATASET_CREATE_DEFAULT* {.importc: "H5P_LST_DATASET_CREATE_g", dynlib: libname.}: hid_t
    H5P_DATASET_ACCESS_DEFAULT* {.importc: "H5P_LST_DATASET_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATASET_XFER_DEFAULT* {.importc: "H5P_LST_DATASET_XFER_g", dynlib: libname.}: hid_t
    H5P_FILE_MOUNT_DEFAULT* {.importc: "H5P_LST_FILE_MOUNT_g", dynlib: libname.}: hid_t
    H5P_GROUP_CREATE_DEFAULT* {.importc: "H5P_LST_GROUP_CREATE_g", dynlib: libname.}: hid_t
    H5P_GROUP_ACCESS_DEFAULT* {.importc: "H5P_LST_GROUP_ACCESS_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_CREATE_DEFAULT* {.importc: "H5P_LST_DATATYPE_CREATE_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_ACCESS_DEFAULT* {.importc: "H5P_LST_DATATYPE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_ATTRIBUTE_CREATE_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_CREATE_g", dynlib: libname.}: hid_t

    ## see comment in CLS types above, same goes for attribute access default
    #H5P_ATTRIBUTE_ACCESS_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_OBJECT_COPY_DEFAULT* {.importc: "H5P_LST_OBJECT_COPY_g", dynlib: libname.}: hid_t
    H5P_LINK_CREATE_DEFAULT* {.importc: "H5P_LST_LINK_CREATE_g", dynlib: libname.}: hid_t
    H5P_LINK_ACCESS_DEFAULT* {.importc: "H5P_LST_LINK_ACCESS_g", dynlib: libname.}: hid_t

else:
  # else we've loaded an older HDF5 library than 1.10.1, in this case, set the
  # variables to those without ID
  var
    H5P_ROOT* {.importc: "H5P_CLS_ROOT_ID_g", dynlib: libname.}: hid_t
    H5P_OBJECT_CREATE* {.importc: "H5P_CLS_OBJECT_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_FILE_CREATE* {.importc: "H5P_CLS_FILE_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_FILE_ACCESS* {.importc: "H5P_CLS_FILE_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_CREATE* {.importc: "H5P_CLS_DATASET_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_ACCESS* {.importc: "H5P_CLS_DATASET_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_XFER* {.importc: "H5P_CLS_DATASET_XFER_ID_g", dynlib: libname.}: hid_t
    H5P_FILE_MOUNT* {.importc: "H5P_CLS_FILE_MOUNT_ID_g", dynlib: libname.}: hid_t
    H5P_GROUP_CREATE* {.importc: "H5P_CLS_GROUP_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_GROUP_ACCESS* {.importc: "H5P_CLS_GROUP_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_CREATE* {.importc: "H5P_CLS_DATATYPE_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_ACCESS* {.importc: "H5P_CLS_DATATYPE_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_STRING_CREATE* {.importc: "H5P_CLS_STRING_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_ATTRIBUTE_CREATE* {.importc: "H5P_CLS_ATTRIBUTE_CREATE_ID_g", dynlib: libname.}: hid_t

    ## NOTE:
    ## For some weird reason Attribute access is still not found?!
    ## Maybe they were only added in HDF5 v. 1.10.x ? This computer
    ## still only uses 1.8, I believe?
    #H5P_ATTRIBUTE_ACCESS* {.importc: "H5P_CLS_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_OBJECT_COPY* {.importc: "H5P_CLS_OBJECT_COPY_ID_g", dynlib: libname.}: hid_t
    H5P_LINK_CREATE* {.importc: "H5P_CLS_LINK_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_LINK_ACCESS* {.importc: "H5P_CLS_LINK_ACCESS_ID_g", dynlib: libname.}: hid_t

    H5P_FILE_CREATE_DEFAULT* {.importc: "H5P_LST_FILE_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_FILE_ACCESS_DEFAULT* {.importc: "H5P_LST_FILE_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_CREATE_DEFAULT* {.importc: "H5P_LST_DATASET_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_ACCESS_DEFAULT* {.importc: "H5P_LST_DATASET_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATASET_XFER_DEFAULT* {.importc: "H5P_LST_DATASET_XFER_ID_g", dynlib: libname.}: hid_t
    H5P_FILE_MOUNT_DEFAULT* {.importc: "H5P_LST_FILE_MOUNT_ID_g", dynlib: libname.}: hid_t
    H5P_GROUP_CREATE_DEFAULT* {.importc: "H5P_LST_GROUP_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_GROUP_ACCESS_DEFAULT* {.importc: "H5P_LST_GROUP_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_CREATE_DEFAULT* {.importc: "H5P_LST_DATATYPE_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_DATATYPE_ACCESS_DEFAULT* {.importc: "H5P_LST_DATATYPE_ACCESS_ID_g", dynlib: libname.}: hid_t
    H5P_ATTRIBUTE_CREATE_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_CREATE_ID_g", dynlib: libname.}: hid_t

    ## see comment in CLS types above, same goes for attribute access default
    #H5P_ATTRIBUTE_ACCESS_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
    H5P_OBJECT_COPY_DEFAULT* {.importc: "H5P_LST_OBJECT_COPY_ID_g", dynlib: libname.}: hid_t
    H5P_LINK_CREATE_DEFAULT* {.importc: "H5P_LST_LINK_CREATE_ID_g", dynlib: libname.}: hid_t
    H5P_LINK_ACCESS_DEFAULT* {.importc: "H5P_LST_LINK_ACCESS_ID_g", dynlib: libname.}: hid_t



##
##  The library's default property lists
##

# TODO:
# for some reason: on my laptop HDF5 version 1.8.11 the symbols are not found
# if ID is not present, on my desktop they are /only/ found if it is not present
# maybe related to this:
# https://support.hdfgroup.org/HDF5/doc/ADGuide/Compatibility_Report/CR_1.8.14.html
# ?
###### AHHHHHHHHHH NOOOOO. my laptop runs on HDF5 1.10.1!!!

# var
#   H5P_FILE_CREATE_DEFAULT* {.importc: "H5P_LST_FILE_CREATE_g", dynlib: libname.}: hid_t
#   H5P_FILE_ACCESS_DEFAULT* {.importc: "H5P_LST_FILE_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_DATASET_CREATE_DEFAULT* {.importc: "H5P_LST_DATASET_CREATE_g", dynlib: libname.}: hid_t
#   H5P_DATASET_ACCESS_DEFAULT* {.importc: "H5P_LST_DATASET_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_DATASET_XFER_DEFAULT* {.importc: "H5P_LST_DATASET_XFER_g", dynlib: libname.}: hid_t
#   H5P_FILE_MOUNT_DEFAULT* {.importc: "H5P_LST_FILE_MOUNT_g", dynlib: libname.}: hid_t
#   H5P_GROUP_CREATE_DEFAULT* {.importc: "H5P_LST_GROUP_CREATE_g", dynlib: libname.}: hid_t
#   H5P_GROUP_ACCESS_DEFAULT* {.importc: "H5P_LST_GROUP_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_DATATYPE_CREATE_DEFAULT* {.importc: "H5P_LST_DATATYPE_CREATE_g", dynlib: libname.}: hid_t
#   H5P_DATATYPE_ACCESS_DEFAULT* {.importc: "H5P_LST_DATATYPE_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_ATTRIBUTE_CREATE_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_CREATE_g", dynlib: libname.}: hid_t

#   ## see comment in CLS types above, same goes for attribute access default
#   #H5P_ATTRIBUTE_ACCESS_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_OBJECT_COPY_DEFAULT* {.importc: "H5P_LST_OBJECT_COPY_g", dynlib: libname.}: hid_t
#   H5P_LINK_CREATE_DEFAULT* {.importc: "H5P_LST_LINK_CREATE_g", dynlib: libname.}: hid_t
#   H5P_LINK_ACCESS_DEFAULT* {.importc: "H5P_LST_LINK_ACCESS_g", dynlib: libname.}: hid_t

# var
#   H5P_FILE_CREATE_DEFAULT* {.importc: "H5P_LST_FILE_CREATE_ID_g", dynlib: libname.}: hid_t
#   H5P_FILE_ACCESS_DEFAULT* {.importc: "H5P_LST_FILE_ACCESS_ID_g", dynlib: libname.}: hid_t
#   H5P_DATASET_CREATE_DEFAULT* {.importc: "H5P_LST_DATASET_CREATE_ID_g", dynlib: libname.}: hid_t
#   H5P_DATASET_ACCESS_DEFAULT* {.importc: "H5P_LST_DATASET_ACCESS_ID_g", dynlib: libname.}: hid_t
#   H5P_DATASET_XFER_DEFAULT* {.importc: "H5P_LST_DATASET_XFER_ID_g", dynlib: libname.}: hid_t
#   H5P_FILE_MOUNT_DEFAULT* {.importc: "H5P_LST_FILE_MOUNT_ID_g", dynlib: libname.}: hid_t
#   H5P_GROUP_CREATE_DEFAULT* {.importc: "H5P_LST_GROUP_CREATE_ID_g", dynlib: libname.}: hid_t
#   H5P_GROUP_ACCESS_DEFAULT* {.importc: "H5P_LST_GROUP_ACCESS_ID_g", dynlib: libname.}: hid_t
#   H5P_DATATYPE_CREATE_DEFAULT* {.importc: "H5P_LST_DATATYPE_CREATE_ID_g", dynlib: libname.}: hid_t
#   H5P_DATATYPE_ACCESS_DEFAULT* {.importc: "H5P_LST_DATATYPE_ACCESS_ID_g", dynlib: libname.}: hid_t
#   H5P_ATTRIBUTE_CREATE_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_CREATE_ID_g", dynlib: libname.}: hid_t

#   ## see comment in CLS types above, same goes for attribute access default
#   #H5P_ATTRIBUTE_ACCESS_DEFAULT* {.importc: "H5P_LST_ATTRIBUTE_ACCESS_g", dynlib: libname.}: hid_t
#   H5P_OBJECT_COPY_DEFAULT* {.importc: "H5P_LST_OBJECT_COPY_ID_g", dynlib: libname.}: hid_t
#   H5P_LINK_CREATE_DEFAULT* {.importc: "H5P_LST_LINK_CREATE_ID_g", dynlib: libname.}: hid_t
#   H5P_LINK_ACCESS_DEFAULT* {.importc: "H5P_LST_LINK_ACCESS_ID_g", dynlib: libname.}: hid_t


## *******************
##  Public Prototypes
## *******************
##  Generic property list routines


proc H5Pcreate_class*(parent: hid_t; name: cstring;
                     cls_create: H5P_cls_create_func_t; create_data: pointer;
                     cls_copy: H5P_cls_copy_func_t; copy_data: pointer;
                     cls_close: H5P_cls_close_func_t; close_data: pointer): hid_t {.
    cdecl, importc: "H5Pcreate_class", dynlib: libname.}
proc H5Pget_class_name*(pclass_id: hid_t): cstring {.cdecl,
    importc: "H5Pget_class_name", dynlib: libname.}
proc H5Pcreate*(cls_id: hid_t): hid_t {.cdecl, importc: "H5Pcreate", dynlib: libname.}
proc H5Pregister2*(cls_id: hid_t; name: cstring; size: csize; def_value: pointer;
                  prp_create: H5P_prp_create_func_t; prp_set: H5P_prp_set_func_t;
                  prp_get: H5P_prp_get_func_t; prp_del: H5P_prp_delete_func_t;
                  prp_copy: H5P_prp_copy_func_t; prp_cmp: H5P_prp_compare_func_t;
                  prp_close: H5P_prp_close_func_t): herr_t {.cdecl,
    importc: "H5Pregister2", dynlib: libname.}
proc H5Pinsert2*(plist_id: hid_t; name: cstring; size: csize; value: pointer;
                prp_set: H5P_prp_set_func_t; prp_get: H5P_prp_get_func_t;
                prp_delete: H5P_prp_delete_func_t; prp_copy: H5P_prp_copy_func_t;
                prp_cmp: H5P_prp_compare_func_t; prp_close: H5P_prp_close_func_t): herr_t {.
    cdecl, importc: "H5Pinsert2", dynlib: libname.}
proc H5Pset*(plist_id: hid_t; name: cstring; value: pointer): herr_t {.cdecl,
    importc: "H5Pset", dynlib: libname.}
proc H5Pexist*(plist_id: hid_t; name: cstring): htri_t {.cdecl, importc: "H5Pexist",
    dynlib: libname.}
proc H5Pencode*(plist_id: hid_t; buf: pointer; nalloc: ptr csize): herr_t {.cdecl,
    importc: "H5Pencode", dynlib: libname.}
proc H5Pdecode*(buf: pointer): hid_t {.cdecl, importc: "H5Pdecode", dynlib: libname.}
proc H5Pget_size*(id: hid_t; name: cstring; size: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_size", dynlib: libname.}
proc H5Pget_nprops*(id: hid_t; nprops: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_nprops", dynlib: libname.}
proc H5Pget_class*(plist_id: hid_t): hid_t {.cdecl, importc: "H5Pget_class",
    dynlib: libname.}
proc H5Pget_class_parent*(pclass_id: hid_t): hid_t {.cdecl,
    importc: "H5Pget_class_parent", dynlib: libname.}
proc H5Pget*(plist_id: hid_t; name: cstring; value: pointer): herr_t {.cdecl,
    importc: "H5Pget", dynlib: libname.}
proc H5Pequal*(id1: hid_t; id2: hid_t): htri_t {.cdecl, importc: "H5Pequal",
    dynlib: libname.}
proc H5Pisa_class*(plist_id: hid_t; pclass_id: hid_t): htri_t {.cdecl,
    importc: "H5Pisa_class", dynlib: libname.}
proc H5Piterate*(id: hid_t; idx: ptr cint; iter_func: H5P_iterate_t; iter_data: pointer): cint {.
    cdecl, importc: "H5Piterate", dynlib: libname.}
proc H5Pcopy_prop*(dst_id: hid_t; src_id: hid_t; name: cstring): herr_t {.cdecl,
    importc: "H5Pcopy_prop", dynlib: libname.}
proc H5Premove*(plist_id: hid_t; name: cstring): herr_t {.cdecl, importc: "H5Premove",
    dynlib: libname.}
proc H5Punregister*(pclass_id: hid_t; name: cstring): herr_t {.cdecl,
    importc: "H5Punregister", dynlib: libname.}
proc H5Pclose_class*(plist_id: hid_t): herr_t {.cdecl, importc: "H5Pclose_class",
    dynlib: libname.}
proc H5Pclose*(plist_id: hid_t): herr_t {.cdecl, importc: "H5Pclose", dynlib: libname.}
proc H5Pcopy*(plist_id: hid_t): hid_t {.cdecl, importc: "H5Pcopy", dynlib: libname.}
##  Object creation property list (OCPL) routines

proc H5Pset_attr_phase_change*(plist_id: hid_t; max_compact: cuint; min_dense: cuint): herr_t {.
    cdecl, importc: "H5Pset_attr_phase_change", dynlib: libname.}
proc H5Pget_attr_phase_change*(plist_id: hid_t; max_compact: ptr cuint;
                              min_dense: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_attr_phase_change", dynlib: libname.}
proc H5Pset_attr_creation_order*(plist_id: hid_t; crt_order_flags: cuint): herr_t {.
    cdecl, importc: "H5Pset_attr_creation_order", dynlib: libname.}
proc H5Pget_attr_creation_order*(plist_id: hid_t; crt_order_flags: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_attr_creation_order", dynlib: libname.}
proc H5Pset_obj_track_times*(plist_id: hid_t; track_times: hbool_t): herr_t {.cdecl,
    importc: "H5Pset_obj_track_times", dynlib: libname.}
proc H5Pget_obj_track_times*(plist_id: hid_t; track_times: ptr hbool_t): herr_t {.
    cdecl, importc: "H5Pget_obj_track_times", dynlib: libname.}
proc H5Pmodify_filter*(plist_id: hid_t; filter: H5Z_filter_t; flags: cuint;
                      cd_nelmts: csize; cd_values: ptr cuint): herr_t {.cdecl,
    importc: "H5Pmodify_filter", dynlib: libname.}
  ## cd_nelmts
proc H5Pset_filter*(plist_id: hid_t; filter: H5Z_filter_t; flags: cuint;
                   cd_nelmts: csize; c_values: ptr cuint): herr_t {.cdecl,
    importc: "H5Pset_filter", dynlib: libname.}
proc H5Pget_nfilters*(plist_id: hid_t): cint {.cdecl, importc: "H5Pget_nfilters",
    dynlib: libname.}
proc H5Pget_filter2*(plist_id: hid_t; filter: cuint; flags: ptr cuint; ## out
                    cd_nelmts: ptr csize; ## out
                    cd_values: ptr cuint; ## out
                    namelen: csize; name: ptr char; filter_config: ptr cuint): H5Z_filter_t {.
    cdecl, importc: "H5Pget_filter2", dynlib: libname.}
  ## out
proc H5Pget_filter_by_id2*(plist_id: hid_t; id: H5Z_filter_t; flags: ptr cuint; ## out
                          cd_nelmts: ptr csize; ## out
                          cd_values: ptr cuint; ## out
                          namelen: csize; name: ptr char; ## out
                          filter_config: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_filter_by_id2", dynlib: libname.}
  ## out
proc H5Pall_filters_avail*(plist_id: hid_t): htri_t {.cdecl,
    importc: "H5Pall_filters_avail", dynlib: libname.}
proc H5Premove_filter*(plist_id: hid_t; filter: H5Z_filter_t): herr_t {.cdecl,
    importc: "H5Premove_filter", dynlib: libname.}
proc H5Pset_deflate*(plist_id: hid_t; aggression: cuint): herr_t {.cdecl,
    importc: "H5Pset_deflate", dynlib: libname.}
proc H5Pset_fletcher32*(plist_id: hid_t): herr_t {.cdecl,
    importc: "H5Pset_fletcher32", dynlib: libname.}
##  File creation property list (FCPL) routines

proc H5Pset_userblock*(plist_id: hid_t; size: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_userblock", dynlib: libname.}
proc H5Pget_userblock*(plist_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pget_userblock", dynlib: libname.}
proc H5Pset_sizes*(plist_id: hid_t; sizeof_addr: csize; sizeof_size: csize): herr_t {.
    cdecl, importc: "H5Pset_sizes", dynlib: libname.}
proc H5Pget_sizes*(plist_id: hid_t; sizeof_addr: ptr csize; ## out
                  sizeof_size: ptr csize): herr_t {.cdecl, importc: "H5Pget_sizes",
    dynlib: libname.}
  ## out
proc H5Pset_sym_k*(plist_id: hid_t; ik: cuint; lk: cuint): herr_t {.cdecl,
    importc: "H5Pset_sym_k", dynlib: libname.}
proc H5Pget_sym_k*(plist_id: hid_t; ik: ptr cuint; ## out
                  lk: ptr cuint): herr_t {.cdecl, importc: "H5Pget_sym_k",
                                       dynlib: libname.}
  ## out
proc H5Pset_istore_k*(plist_id: hid_t; ik: cuint): herr_t {.cdecl,
    importc: "H5Pset_istore_k", dynlib: libname.}
proc H5Pget_istore_k*(plist_id: hid_t; ik: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_istore_k", dynlib: libname.}
  ## out
proc H5Pset_shared_mesg_nindexes*(plist_id: hid_t; nindexes: cuint): herr_t {.cdecl,
    importc: "H5Pset_shared_mesg_nindexes", dynlib: libname.}
proc H5Pget_shared_mesg_nindexes*(plist_id: hid_t; nindexes: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_shared_mesg_nindexes", dynlib: libname.}
proc H5Pset_shared_mesg_index*(plist_id: hid_t; index_num: cuint;
                              mesg_type_flags: cuint; min_mesg_size: cuint): herr_t {.
    cdecl, importc: "H5Pset_shared_mesg_index", dynlib: libname.}
proc H5Pget_shared_mesg_index*(plist_id: hid_t; index_num: cuint;
                              mesg_type_flags: ptr cuint; min_mesg_size: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_shared_mesg_index", dynlib: libname.}
proc H5Pset_shared_mesg_phase_change*(plist_id: hid_t; max_list: cuint;
                                     min_btree: cuint): herr_t {.cdecl,
    importc: "H5Pset_shared_mesg_phase_change", dynlib: libname.}
proc H5Pget_shared_mesg_phase_change*(plist_id: hid_t; max_list: ptr cuint;
                                     min_btree: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_shared_mesg_phase_change", dynlib: libname.}
proc H5Pset_file_space_strategy*(plist_id: hid_t; strategy: H5F_fspace_strategy_t;
                                persist: hbool_t; threshold: hsize_t): herr_t {.
    cdecl, importc: "H5Pset_file_space_strategy", dynlib: libname.}
proc H5Pget_file_space_strategy*(plist_id: hid_t;
                                strategy: ptr H5F_fspace_strategy_t;
                                persist: ptr hbool_t; threshold: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Pget_file_space_strategy", dynlib: libname.}
proc H5Pset_file_space_page_size*(plist_id: hid_t; fsp_size: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_file_space_page_size", dynlib: libname.}
proc H5Pget_file_space_page_size*(plist_id: hid_t; fsp_size: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Pget_file_space_page_size", dynlib: libname.}
##  File access property list (FAPL) routines

proc H5Pset_alignment*(fapl_id: hid_t; threshold: hsize_t; alignment: hsize_t): herr_t {.
    cdecl, importc: "H5Pset_alignment", dynlib: libname.}
proc H5Pget_alignment*(fapl_id: hid_t; threshold: ptr hsize_t; ## out
                      alignment: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pget_alignment", dynlib: libname.}
  ## out
proc H5Pset_driver*(plist_id: hid_t; driver_id: hid_t; driver_info: pointer): herr_t {.
    cdecl, importc: "H5Pset_driver", dynlib: libname.}
proc H5Pget_driver*(plist_id: hid_t): hid_t {.cdecl, importc: "H5Pget_driver",
    dynlib: libname.}
proc H5Pget_driver_info*(plist_id: hid_t): pointer {.cdecl,
    importc: "H5Pget_driver_info", dynlib: libname.}
proc H5Pset_family_offset*(fapl_id: hid_t; offset: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_family_offset", dynlib: libname.}
proc H5Pget_family_offset*(fapl_id: hid_t; offset: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pget_family_offset", dynlib: libname.}
proc H5Pset_multi_type*(fapl_id: hid_t; `type`: H5FD_mem_t): herr_t {.cdecl,
    importc: "H5Pset_multi_type", dynlib: libname.}
proc H5Pget_multi_type*(fapl_id: hid_t; `type`: ptr H5FD_mem_t): herr_t {.cdecl,
    importc: "H5Pget_multi_type", dynlib: libname.}
proc H5Pset_cache*(plist_id: hid_t; mdc_nelmts: cint; rdcc_nslots: csize;
                  rdcc_nbytes: csize; rdcc_w0: cdouble): herr_t {.cdecl,
    importc: "H5Pset_cache", dynlib: libname.}
proc H5Pget_cache*(plist_id: hid_t; mdc_nelmts: ptr cint; rdcc_nslots: ptr csize; ##  out
## out
                  rdcc_nbytes: ptr csize; ## out
                  rdcc_w0: ptr cdouble): herr_t {.cdecl, importc: "H5Pget_cache",
    dynlib: libname.}
proc H5Pset_mdc_config*(plist_id: hid_t; config_ptr: ptr H5AC_cache_config_t): herr_t {.
    cdecl, importc: "H5Pset_mdc_config", dynlib: libname.}
proc H5Pget_mdc_config*(plist_id: hid_t; config_ptr: ptr H5AC_cache_config_t): herr_t {.
    cdecl, importc: "H5Pget_mdc_config", dynlib: libname.}
##  out

proc H5Pset_gc_references*(fapl_id: hid_t; gc_ref: cuint): herr_t {.cdecl,
    importc: "H5Pset_gc_references", dynlib: libname.}
proc H5Pget_gc_references*(fapl_id: hid_t; gc_ref: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_gc_references", dynlib: libname.}
  ## out
proc H5Pset_fclose_degree*(fapl_id: hid_t; degree: H5F_close_degree_t): herr_t {.
    cdecl, importc: "H5Pset_fclose_degree", dynlib: libname.}
proc H5Pget_fclose_degree*(fapl_id: hid_t; degree: ptr H5F_close_degree_t): herr_t {.
    cdecl, importc: "H5Pget_fclose_degree", dynlib: libname.}
proc H5Pset_meta_block_size*(fapl_id: hid_t; size: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_meta_block_size", dynlib: libname.}
proc H5Pget_meta_block_size*(fapl_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pget_meta_block_size", dynlib: libname.}
  ## out
proc H5Pset_sieve_buf_size*(fapl_id: hid_t; size: csize): herr_t {.cdecl,
    importc: "H5Pset_sieve_buf_size", dynlib: libname.}
proc H5Pget_sieve_buf_size*(fapl_id: hid_t; size: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_sieve_buf_size", dynlib: libname.}
  ## out
proc H5Pset_small_data_block_size*(fapl_id: hid_t; size: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_small_data_block_size", dynlib: libname.}
proc H5Pget_small_data_block_size*(fapl_id: hid_t; size: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pget_small_data_block_size", dynlib: libname.}
  ## out
proc H5Pset_libver_bounds*(plist_id: hid_t; low: H5F_libver_t; high: H5F_libver_t): herr_t {.
    cdecl, importc: "H5Pset_libver_bounds", dynlib: libname.}
proc H5Pget_libver_bounds*(plist_id: hid_t; low: ptr H5F_libver_t;
                          high: ptr H5F_libver_t): herr_t {.cdecl,
    importc: "H5Pget_libver_bounds", dynlib: libname.}
proc H5Pset_elink_file_cache_size*(plist_id: hid_t; efc_size: cuint): herr_t {.cdecl,
    importc: "H5Pset_elink_file_cache_size", dynlib: libname.}
proc H5Pget_elink_file_cache_size*(plist_id: hid_t; efc_size: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_elink_file_cache_size", dynlib: libname.}
proc H5Pset_file_image*(fapl_id: hid_t; buf_ptr: pointer; buf_len: csize): herr_t {.
    cdecl, importc: "H5Pset_file_image", dynlib: libname.}
proc H5Pget_file_image*(fapl_id: hid_t; buf_ptr_ptr: ptr pointer;
                       buf_len_ptr: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_file_image", dynlib: libname.}
proc H5Pset_file_image_callbacks*(fapl_id: hid_t;
                                 callbacks_ptr: ptr H5FD_file_image_callbacks_t): herr_t {.
    cdecl, importc: "H5Pset_file_image_callbacks", dynlib: libname.}
proc H5Pget_file_image_callbacks*(fapl_id: hid_t;
                                 callbacks_ptr: ptr H5FD_file_image_callbacks_t): herr_t {.
    cdecl, importc: "H5Pget_file_image_callbacks", dynlib: libname.}
proc H5Pset_core_write_tracking*(fapl_id: hid_t; is_enabled: hbool_t;
                                page_size: csize): herr_t {.cdecl,
    importc: "H5Pset_core_write_tracking", dynlib: libname.}
proc H5Pget_core_write_tracking*(fapl_id: hid_t; is_enabled: ptr hbool_t;
                                page_size: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_core_write_tracking", dynlib: libname.}
proc H5Pset_metadata_read_attempts*(plist_id: hid_t; attempts: cuint): herr_t {.cdecl,
    importc: "H5Pset_metadata_read_attempts", dynlib: libname.}
proc H5Pget_metadata_read_attempts*(plist_id: hid_t; attempts: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_metadata_read_attempts", dynlib: libname.}
proc H5Pset_object_flush_cb*(plist_id: hid_t; `func`: H5F_flush_cb_t; udata: pointer): herr_t {.
    cdecl, importc: "H5Pset_object_flush_cb", dynlib: libname.}
proc H5Pget_object_flush_cb*(plist_id: hid_t; `func`: ptr H5F_flush_cb_t;
                            udata: ptr pointer): herr_t {.cdecl,
    importc: "H5Pget_object_flush_cb", dynlib: libname.}
proc H5Pset_mdc_log_options*(plist_id: hid_t; is_enabled: hbool_t; location: cstring;
                            start_on_access: hbool_t): herr_t {.cdecl,
    importc: "H5Pset_mdc_log_options", dynlib: libname.}
proc H5Pget_mdc_log_options*(plist_id: hid_t; is_enabled: ptr hbool_t;
                            location: cstring; location_size: ptr csize;
                            start_on_access: ptr hbool_t): herr_t {.cdecl,
    importc: "H5Pget_mdc_log_options", dynlib: libname.}
proc H5Pset_evict_on_close*(fapl_id: hid_t; evict_on_close: hbool_t): herr_t {.cdecl,
    importc: "H5Pset_evict_on_close", dynlib: libname.}
proc H5Pget_evict_on_close*(fapl_id: hid_t; evict_on_close: ptr hbool_t): herr_t {.
    cdecl, importc: "H5Pget_evict_on_close", dynlib: libname.}
when defined(H5_HAVE_PARALLEL):
  proc H5Pset_all_coll_metadata_ops*(plist_id: hid_t; is_collective: hbool_t): herr_t {.
      cdecl, importc: "H5Pset_all_coll_metadata_ops", dynlib: libname.}
  proc H5Pget_all_coll_metadata_ops*(plist_id: hid_t; is_collective: ptr hbool_t): herr_t {.
      cdecl, importc: "H5Pget_all_coll_metadata_ops", dynlib: libname.}
  proc H5Pset_coll_metadata_write*(plist_id: hid_t; is_collective: hbool_t): herr_t {.
      cdecl, importc: "H5Pset_coll_metadata_write", dynlib: libname.}
  proc H5Pget_coll_metadata_write*(plist_id: hid_t; is_collective: ptr hbool_t): herr_t {.
      cdecl, importc: "H5Pget_coll_metadata_write", dynlib: libname.}
proc H5Pset_mdc_image_config*(plist_id: hid_t;
                             config_ptr: ptr H5AC_cache_image_config_t): herr_t {.
    cdecl, importc: "H5Pset_mdc_image_config", dynlib: libname.}
proc H5Pget_mdc_image_config*(plist_id: hid_t; config_ptr: ptr H5AC_cache_image_config_t): herr_t {.
    cdecl, importc: "H5Pget_mdc_image_config", dynlib: libname.}
  ## out
proc H5Pset_page_buffer_size*(plist_id: hid_t; buf_size: csize; min_meta_per: cuint;
                             min_raw_per: cuint): herr_t {.cdecl,
    importc: "H5Pset_page_buffer_size", dynlib: libname.}
proc H5Pget_page_buffer_size*(plist_id: hid_t; buf_size: ptr csize;
                             min_meta_per: ptr cuint; min_raw_per: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_page_buffer_size", dynlib: libname.}
##  Dataset creation property list (DCPL) routines

proc H5Pset_layout*(plist_id: hid_t; layout: H5D_layout_t): herr_t {.cdecl,
    importc: "H5Pset_layout", dynlib: libname.}
proc H5Pget_layout*(plist_id: hid_t): H5D_layout_t {.cdecl, importc: "H5Pget_layout",
    dynlib: libname.}
proc H5Pset_chunk*(plist_id: hid_t; ndims: cint; dim: ptr hsize_t): herr_t {.cdecl,
    importc: "H5Pset_chunk", dynlib: libname.}
  ## ndims
proc H5Pget_chunk*(plist_id: hid_t; max_ndims: cint; dim: ptr hsize_t): cint {.cdecl,
    importc: "H5Pget_chunk", dynlib: libname.}
  ## out
proc H5Pset_virtual*(dcpl_id: hid_t; vspace_id: hid_t; src_file_name: cstring;
                    src_dset_name: cstring; src_space_id: hid_t): herr_t {.cdecl,
    importc: "H5Pset_virtual", dynlib: libname.}
proc H5Pget_virtual_count*(dcpl_id: hid_t; count: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_virtual_count", dynlib: libname.}
  ## out
proc H5Pget_virtual_vspace*(dcpl_id: hid_t; index: csize): hid_t {.cdecl,
    importc: "H5Pget_virtual_vspace", dynlib: libname.}
proc H5Pget_virtual_srcspace*(dcpl_id: hid_t; index: csize): hid_t {.cdecl,
    importc: "H5Pget_virtual_srcspace", dynlib: libname.}
proc H5Pget_virtual_filename*(dcpl_id: hid_t; index: csize; name: cstring; ## out
                             size: csize): ssize_t {.cdecl,
    importc: "H5Pget_virtual_filename", dynlib: libname.}
proc H5Pget_virtual_dsetname*(dcpl_id: hid_t; index: csize; name: cstring; ## out
                             size: csize): ssize_t {.cdecl,
    importc: "H5Pget_virtual_dsetname", dynlib: libname.}
proc H5Pset_external*(plist_id: hid_t; name: cstring; offset: off_t; size: hsize_t): herr_t {.
    cdecl, importc: "H5Pset_external", dynlib: libname.}
proc H5Pset_chunk_opts*(plist_id: hid_t; opts: cuint): herr_t {.cdecl,
    importc: "H5Pset_chunk_opts", dynlib: libname.}
proc H5Pget_chunk_opts*(plist_id: hid_t; opts: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_chunk_opts", dynlib: libname.}
proc H5Pget_external_count*(plist_id: hid_t): cint {.cdecl,
    importc: "H5Pget_external_count", dynlib: libname.}
proc H5Pget_external*(plist_id: hid_t; idx: cuint; name_size: csize; name: cstring; ## out
                     offset: ptr off_t; ## out
                     size: ptr hsize_t): herr_t {.cdecl, importc: "H5Pget_external",
    dynlib: libname.}
  ## out
proc H5Pset_szip*(plist_id: hid_t; options_mask: cuint; pixels_per_block: cuint): herr_t {.
    cdecl, importc: "H5Pset_szip", dynlib: libname.}
proc H5Pset_shuffle*(plist_id: hid_t): herr_t {.cdecl, importc: "H5Pset_shuffle",
    dynlib: libname.}
proc H5Pset_nbit*(plist_id: hid_t): herr_t {.cdecl, importc: "H5Pset_nbit",
    dynlib: libname.}
proc H5Pset_scaleoffset*(plist_id: hid_t; scale_type: H5Z_SO_scale_type_t;
                        scale_factor: cint): herr_t {.cdecl,
    importc: "H5Pset_scaleoffset", dynlib: libname.}
proc H5Pset_fill_value*(plist_id: hid_t; type_id: hid_t; value: pointer): herr_t {.
    cdecl, importc: "H5Pset_fill_value", dynlib: libname.}
proc H5Pget_fill_value*(plist_id: hid_t; type_id: hid_t; value: pointer): herr_t {.
    cdecl, importc: "H5Pget_fill_value", dynlib: libname.}
  ## out
proc H5Pfill_value_defined*(plist: hid_t; status: ptr H5D_fill_value_t): herr_t {.
    cdecl, importc: "H5Pfill_value_defined", dynlib: libname.}
proc H5Pset_alloc_time*(plist_id: hid_t; alloc_time: H5D_alloc_time_t): herr_t {.
    cdecl, importc: "H5Pset_alloc_time", dynlib: libname.}
proc H5Pget_alloc_time*(plist_id: hid_t; alloc_time: ptr H5D_alloc_time_t): herr_t {.
    cdecl, importc: "H5Pget_alloc_time", dynlib: libname.}
  ## out
proc H5Pset_fill_time*(plist_id: hid_t; fill_time: H5D_fill_time_t): herr_t {.cdecl,
    importc: "H5Pset_fill_time", dynlib: libname.}
proc H5Pget_fill_time*(plist_id: hid_t; fill_time: ptr H5D_fill_time_t): herr_t {.
    cdecl, importc: "H5Pget_fill_time", dynlib: libname.}
  ## out
##  Dataset access property list (DAPL) routines

proc H5Pset_chunk_cache*(dapl_id: hid_t; rdcc_nslots: csize; rdcc_nbytes: csize;
                        rdcc_w0: cdouble): herr_t {.cdecl,
    importc: "H5Pset_chunk_cache", dynlib: libname.}
proc H5Pget_chunk_cache*(dapl_id: hid_t; rdcc_nslots: ptr csize; ## out
                        rdcc_nbytes: ptr csize; ## out
                        rdcc_w0: ptr cdouble): herr_t {.cdecl,
    importc: "H5Pget_chunk_cache", dynlib: libname.}
  ## out
proc H5Pset_virtual_view*(plist_id: hid_t; view: H5D_vds_view_t): herr_t {.cdecl,
    importc: "H5Pset_virtual_view", dynlib: libname.}
proc H5Pget_virtual_view*(plist_id: hid_t; view: ptr H5D_vds_view_t): herr_t {.cdecl,
    importc: "H5Pget_virtual_view", dynlib: libname.}
proc H5Pset_virtual_printf_gap*(plist_id: hid_t; gap_size: hsize_t): herr_t {.cdecl,
    importc: "H5Pset_virtual_printf_gap", dynlib: libname.}
proc H5Pget_virtual_printf_gap*(plist_id: hid_t; gap_size: ptr hsize_t): herr_t {.
    cdecl, importc: "H5Pget_virtual_printf_gap", dynlib: libname.}
proc H5Pset_append_flush*(plist_id: hid_t; ndims: cuint; boundary: ptr hsize_t;
                         `func`: H5D_append_cb_t; udata: pointer): herr_t {.cdecl,
    importc: "H5Pset_append_flush", dynlib: libname.}
proc H5Pget_append_flush*(plist_id: hid_t; dims: cuint; boundary: ptr hsize_t;
                         `func`: ptr H5D_append_cb_t; udata: ptr pointer): herr_t {.
    cdecl, importc: "H5Pget_append_flush", dynlib: libname.}
proc H5Pset_efile_prefix*(dapl_id: hid_t; prefix: cstring): herr_t {.cdecl,
    importc: "H5Pset_efile_prefix", dynlib: libname.}
proc H5Pget_efile_prefix*(dapl_id: hid_t; prefix: cstring; ## out
                         size: csize): ssize_t {.cdecl,
    importc: "H5Pget_efile_prefix", dynlib: libname.}
##  Dataset xfer property list (DXPL) routines

proc H5Pset_data_transform*(plist_id: hid_t; expression: cstring): herr_t {.cdecl,
    importc: "H5Pset_data_transform", dynlib: libname.}
proc H5Pget_data_transform*(plist_id: hid_t; expression: cstring; ## out
                           size: csize): ssize_t {.cdecl,
    importc: "H5Pget_data_transform", dynlib: libname.}
proc H5Pset_buffer*(plist_id: hid_t; size: csize; tconv: pointer; bkg: pointer): herr_t {.
    cdecl, importc: "H5Pset_buffer", dynlib: libname.}
proc H5Pget_buffer*(plist_id: hid_t; tconv: ptr pointer; ## out
                   bkg: ptr pointer): csize {.cdecl, importc: "H5Pget_buffer",
    dynlib: libname.}
  ## out
proc H5Pset_preserve*(plist_id: hid_t; status: hbool_t): herr_t {.cdecl,
    importc: "H5Pset_preserve", dynlib: libname.}
proc H5Pget_preserve*(plist_id: hid_t): cint {.cdecl, importc: "H5Pget_preserve",
    dynlib: libname.}
proc H5Pset_edc_check*(plist_id: hid_t; check: H5Z_EDC_t): herr_t {.cdecl,
    importc: "H5Pset_edc_check", dynlib: libname.}
proc H5Pget_edc_check*(plist_id: hid_t): H5Z_EDC_t {.cdecl,
    importc: "H5Pget_edc_check", dynlib: libname.}
proc H5Pset_filter_callback*(plist_id: hid_t; `func`: H5Z_filter_func_t;
                            op_data: pointer): herr_t {.cdecl,
    importc: "H5Pset_filter_callback", dynlib: libname.}
proc H5Pset_btree_ratios*(plist_id: hid_t; left: cdouble; middle: cdouble;
                         right: cdouble): herr_t {.cdecl,
    importc: "H5Pset_btree_ratios", dynlib: libname.}
proc H5Pget_btree_ratios*(plist_id: hid_t; left: ptr cdouble; ## out
                         middle: ptr cdouble; ## out
                         right: ptr cdouble): herr_t {.cdecl,
    importc: "H5Pget_btree_ratios", dynlib: libname.}
  ## out
proc H5Pset_vlen_mem_manager*(plist_id: hid_t; alloc_func: H5MM_allocate_t;
                             alloc_info: pointer; free_func: H5MM_free_t;
                             free_info: pointer): herr_t {.cdecl,
    importc: "H5Pset_vlen_mem_manager", dynlib: libname.}
proc H5Pget_vlen_mem_manager*(plist_id: hid_t; alloc_func: ptr H5MM_allocate_t;
                             alloc_info: ptr pointer; free_func: ptr H5MM_free_t;
                             free_info: ptr pointer): herr_t {.cdecl,
    importc: "H5Pget_vlen_mem_manager", dynlib: libname.}
proc H5Pset_hyper_vector_size*(fapl_id: hid_t; size: csize): herr_t {.cdecl,
    importc: "H5Pset_hyper_vector_size", dynlib: libname.}
proc H5Pget_hyper_vector_size*(fapl_id: hid_t; size: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_hyper_vector_size", dynlib: libname.}
  ## out
proc H5Pset_type_conv_cb*(dxpl_id: hid_t; op: H5T_conv_except_func_t;
                         operate_data: pointer): herr_t {.cdecl,
    importc: "H5Pset_type_conv_cb", dynlib: libname.}
proc H5Pget_type_conv_cb*(dxpl_id: hid_t; op: ptr H5T_conv_except_func_t;
                         operate_data: ptr pointer): herr_t {.cdecl,
    importc: "H5Pget_type_conv_cb", dynlib: libname.}
when defined(H5_HAVE_PARALLEL):
  proc H5Pget_mpio_actual_chunk_opt_mode*(plist_id: hid_t;
      actual_chunk_opt_mode: ptr H5D_mpio_actual_chunk_opt_mode_t): herr_t {.cdecl,
      importc: "H5Pget_mpio_actual_chunk_opt_mode", dynlib: libname.}
  proc H5Pget_mpio_actual_io_mode*(plist_id: hid_t;
                                  actual_io_mode: ptr H5D_mpio_actual_io_mode_t): herr_t {.
      cdecl, importc: "H5Pget_mpio_actual_io_mode", dynlib: libname.}
  proc H5Pget_mpio_no_collective_cause*(plist_id: hid_t;
                                       local_no_collective_cause: ptr uint32_t;
                                       global_no_collective_cause: ptr uint32_t): herr_t {.
      cdecl, importc: "H5Pget_mpio_no_collective_cause", dynlib: libname.}
##  Link creation property list (LCPL) routines

proc H5Pset_create_intermediate_group*(plist_id: hid_t; crt_intmd: cuint): herr_t {.
    cdecl, importc: "H5Pset_create_intermediate_group", dynlib: libname.}
proc H5Pget_create_intermediate_group*(plist_id: hid_t; crt_intmd: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_create_intermediate_group", dynlib: libname.}
  ## out
##  Group creation property list (GCPL) routines

proc H5Pset_local_heap_size_hint*(plist_id: hid_t; size_hint: csize): herr_t {.cdecl,
    importc: "H5Pset_local_heap_size_hint", dynlib: libname.}
proc H5Pget_local_heap_size_hint*(plist_id: hid_t; size_hint: ptr csize): herr_t {.
    cdecl, importc: "H5Pget_local_heap_size_hint", dynlib: libname.}
  ## out
proc H5Pset_link_phase_change*(plist_id: hid_t; max_compact: cuint; min_dense: cuint): herr_t {.
    cdecl, importc: "H5Pset_link_phase_change", dynlib: libname.}
proc H5Pget_link_phase_change*(plist_id: hid_t; max_compact: ptr cuint; ## out
                              min_dense: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_link_phase_change", dynlib: libname.}
  ## out
proc H5Pset_est_link_info*(plist_id: hid_t; est_num_entries: cuint;
                          est_name_len: cuint): herr_t {.cdecl,
    importc: "H5Pset_est_link_info", dynlib: libname.}
proc H5Pget_est_link_info*(plist_id: hid_t; est_num_entries: ptr cuint; ##  out
                          est_name_len: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_est_link_info", dynlib: libname.}
  ##  out
proc H5Pset_link_creation_order*(plist_id: hid_t; crt_order_flags: cuint): herr_t {.
    cdecl, importc: "H5Pset_link_creation_order", dynlib: libname.}
proc H5Pget_link_creation_order*(plist_id: hid_t; crt_order_flags: ptr cuint): herr_t {.
    cdecl, importc: "H5Pget_link_creation_order", dynlib: libname.}
  ##  out
##  String creation property list (STRCPL) routines

proc H5Pset_char_encoding*(plist_id: hid_t; encoding: H5T_cset_t): herr_t {.cdecl,
    importc: "H5Pset_char_encoding", dynlib: libname.}
proc H5Pget_char_encoding*(plist_id: hid_t; encoding: ptr H5T_cset_t): herr_t {.cdecl,
    importc: "H5Pget_char_encoding", dynlib: libname.}
  ## out
##  Link access property list (LAPL) routines

proc H5Pset_nlinks*(plist_id: hid_t; nlinks: csize): herr_t {.cdecl,
    importc: "H5Pset_nlinks", dynlib: libname.}
proc H5Pget_nlinks*(plist_id: hid_t; nlinks: ptr csize): herr_t {.cdecl,
    importc: "H5Pget_nlinks", dynlib: libname.}
proc H5Pset_elink_prefix*(plist_id: hid_t; prefix: cstring): herr_t {.cdecl,
    importc: "H5Pset_elink_prefix", dynlib: libname.}
proc H5Pget_elink_prefix*(plist_id: hid_t; prefix: cstring; size: csize): ssize_t {.
    cdecl, importc: "H5Pget_elink_prefix", dynlib: libname.}
proc H5Pget_elink_fapl*(lapl_id: hid_t): hid_t {.cdecl, importc: "H5Pget_elink_fapl",
    dynlib: libname.}
proc H5Pset_elink_fapl*(lapl_id: hid_t; fapl_id: hid_t): herr_t {.cdecl,
    importc: "H5Pset_elink_fapl", dynlib: libname.}
proc H5Pset_elink_acc_flags*(lapl_id: hid_t; flags: cuint): herr_t {.cdecl,
    importc: "H5Pset_elink_acc_flags", dynlib: libname.}
proc H5Pget_elink_acc_flags*(lapl_id: hid_t; flags: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_elink_acc_flags", dynlib: libname.}
proc H5Pset_elink_cb*(lapl_id: hid_t; `func`: H5L_elink_traverse_t; op_data: pointer): herr_t {.
    cdecl, importc: "H5Pset_elink_cb", dynlib: libname.}
proc H5Pget_elink_cb*(lapl_id: hid_t; `func`: ptr H5L_elink_traverse_t;
                     op_data: ptr pointer): herr_t {.cdecl,
    importc: "H5Pget_elink_cb", dynlib: libname.}
##  Object copy property list (OCPYPL) routines

proc H5Pset_copy_object*(plist_id: hid_t; crt_intmd: cuint): herr_t {.cdecl,
    importc: "H5Pset_copy_object", dynlib: libname.}
proc H5Pget_copy_object*(plist_id: hid_t; crt_intmd: ptr cuint): herr_t {.cdecl,
    importc: "H5Pget_copy_object", dynlib: libname.}
  ## out
proc H5Padd_merge_committed_dtype_path*(plist_id: hid_t; path: cstring): herr_t {.
    cdecl, importc: "H5Padd_merge_committed_dtype_path", dynlib: libname.}
proc H5Pfree_merge_committed_dtype_paths*(plist_id: hid_t): herr_t {.cdecl,
    importc: "H5Pfree_merge_committed_dtype_paths", dynlib: libname.}
proc H5Pset_mcdt_search_cb*(plist_id: hid_t; `func`: H5O_mcdt_search_cb_t;
                           op_data: pointer): herr_t {.cdecl,
    importc: "H5Pset_mcdt_search_cb", dynlib: libname.}
proc H5Pget_mcdt_search_cb*(plist_id: hid_t; `func`: ptr H5O_mcdt_search_cb_t;
                           op_data: ptr pointer): herr_t {.cdecl,
    importc: "H5Pget_mcdt_search_cb", dynlib: libname.}
##  Symbols defined for compatibility with previous versions of the HDF5 API.
##
##  Use of these symbols is deprecated.
##

when not defined(H5_NO_DEPRECATED_SYMBOLS):
  ##  Macros
  ##  We renamed the "root" of the property list class hierarchy
  #let
  #  H5P_NO_CLASS* = H5P_ROOT
  ##  Typedefs
  ##  Function prototypes
  proc H5Pregister1*(cls_id: hid_t; name: cstring; size: csize; def_value: pointer;
                    prp_create: H5P_prp_create_func_t;
                    prp_set: H5P_prp_set_func_t; prp_get: H5P_prp_get_func_t;
                    prp_del: H5P_prp_delete_func_t; prp_copy: H5P_prp_copy_func_t;
                    prp_close: H5P_prp_close_func_t): herr_t {.cdecl,
      importc: "H5Pregister1", dynlib: libname.}
  proc H5Pinsert1*(plist_id: hid_t; name: cstring; size: csize; value: pointer;
                  prp_set: H5P_prp_set_func_t; prp_get: H5P_prp_get_func_t;
                  prp_delete: H5P_prp_delete_func_t;
                  prp_copy: H5P_prp_copy_func_t; prp_close: H5P_prp_close_func_t): herr_t {.
      cdecl, importc: "H5Pinsert1", dynlib: libname.}
  proc H5Pget_filter1*(plist_id: hid_t; filter: cuint; flags: ptr cuint; ## out
                      cd_nelmts: ptr csize; ## out
                      cd_values: ptr cuint; ## out
                      namelen: csize; name: ptr char): H5Z_filter_t {.cdecl,
      importc: "H5Pget_filter1", dynlib: libname.}
  proc H5Pget_filter_by_id1*(plist_id: hid_t; id: H5Z_filter_t; flags: ptr cuint; ## out
                            cd_nelmts: ptr csize; ## out
                            cd_values: ptr cuint; ## out
                            namelen: csize; name: ptr char): herr_t {.cdecl,
      importc: "H5Pget_filter_by_id1", dynlib: libname.}
    ## out
  proc H5Pget_version*(plist_id: hid_t; boot: ptr cuint; ## out
                      freelist: ptr cuint; ## out
                      stab: ptr cuint; ## out
                      shhdr: ptr cuint): herr_t {.cdecl, importc: "H5Pget_version",
      dynlib: libname.}
    ## out
  proc H5Pset_file_space*(plist_id: hid_t; strategy: H5F_file_space_type_t;
                         threshold: hsize_t): herr_t {.cdecl,
      importc: "H5Pset_file_space", dynlib: libname.}
  proc H5Pget_file_space*(plist_id: hid_t; strategy: ptr H5F_file_space_type_t;
                         threshold: ptr hsize_t): herr_t {.cdecl,
      importc: "H5Pget_file_space", dynlib: libname.}
