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
##  Purpose:	The public header file for the mpio driver.
##

# before we can import any of the variables, from the already shared library
# we need to make sure that they are defined. The library needs to be
# initialized. Thus we include
include H5niminitialize

##  Macros

when defined(H5_HAVE_PARALLEL):
  const
    H5FD_MPIO* = (H5FD_mpio_init())
else:
  const
    H5FD_MPIO* = (- 1)
when defined(H5_HAVE_PARALLEL):
  ## Turn on H5FDmpio_debug if H5F_DEBUG is on
  # when defined(H5F_DEBUG):
  ##  Global var whose value comes from environment variable
  ##  (Defined in H5FDmpio.c)
  var H5FD_mpi_opt_types_g* {.importc: "H5FD_mpi_opt_types_g", dynlib: libname.}: hbool_t
  ##  Function prototypes
  proc H5FD_mpio_init*(): hid_t {.cdecl, importc: "H5FD_mpio_init", dynlib: libname.}
  proc H5Pset_fapl_mpio*(fapl_id: hid_t; comm: MPI_Comm; info: MPI_Info): herr_t {.
      cdecl, importc: "H5Pset_fapl_mpio", dynlib: libname.}
  proc H5Pget_fapl_mpio*(fapl_id: hid_t; comm: ptr MPI_Comm; ## out
                        info: ptr MPI_Info): herr_t {.cdecl,
      importc: "H5Pget_fapl_mpio", dynlib: libname.}
    ## out
  proc H5Pset_dxpl_mpio*(dxpl_id: hid_t; xfer_mode: H5FD_mpio_xfer_t): herr_t {.cdecl,
      importc: "H5Pset_dxpl_mpio", dynlib: libname.}
  proc H5Pget_dxpl_mpio*(dxpl_id: hid_t; xfer_mode: ptr H5FD_mpio_xfer_t): herr_t {.
      cdecl, importc: "H5Pget_dxpl_mpio", dynlib: libname.}
    ## out
  proc H5Pset_dxpl_mpio_collective_opt*(dxpl_id: hid_t;
                                       opt_mode: H5FD_mpio_collective_opt_t): herr_t {.
      cdecl, importc: "H5Pset_dxpl_mpio_collective_opt", dynlib: libname.}
  proc H5Pset_dxpl_mpio_chunk_opt*(dxpl_id: hid_t; opt_mode: H5FD_mpio_chunk_opt_t): herr_t {.
      cdecl, importc: "H5Pset_dxpl_mpio_chunk_opt", dynlib: libname.}
  proc H5Pset_dxpl_mpio_chunk_opt_num*(dxpl_id: hid_t; num_chunk_per_proc: cuint): herr_t {.
      cdecl, importc: "H5Pset_dxpl_mpio_chunk_opt_num", dynlib: libname.}
  proc H5Pset_dxpl_mpio_chunk_opt_ratio*(dxpl_id: hid_t;
                                        percent_num_proc_per_chunk: cuint): herr_t {.
      cdecl, importc: "H5Pset_dxpl_mpio_chunk_opt_ratio", dynlib: libname.}
