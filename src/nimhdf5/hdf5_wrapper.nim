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
##  This is the main public HDF5 include file.  Put further information in
##  a particular header file and include that here, don't fill this file with
##  lots of gunk...
##


#[ NOTE: in a few files (H5Tpublic, H5Epublic and H5Ppublic) we need to define
   several variables (regarding type ids), which can only be set after the HDF5
   library has been 'opened' (= initialized). Thus we include H5initialize
   in these libraries, which (at the moment) simply calls the H5open() function
   which does exactly that. Then we can use the variables, like e.g.
   H5T_NATIVE_INTEGER
   in the Nim progams as function arguments without getting any weird errors.
]#

include
  nimhdf5/wrapper/H5public, nimhdf5/wrapper/H5Apublic,        ##  Attributes
  nimhdf5/wrapper/H5ACpublic,                 ##  Metadata cache
  nimhdf5/wrapper/H5Dpublic,                  ##  Datasets
  nimhdf5/wrapper/H5Epublic,                  ##  Errors
  nimhdf5/wrapper/H5Fpublic,                  ##  Files
  nimhdf5/wrapper/H5FDpublic,                 ##  File drivers
  nimhdf5/wrapper/H5Gpublic,                  ##  Groups
  nimhdf5/wrapper/H5Ipublic,                  ##  ID management
  nimhdf5/wrapper/H5Lpublic,                  ##  Links
  nimhdf5/wrapper/H5MMpublic,                 ##  Memory management
  nimhdf5/wrapper/H5Opublic,                  ##  Object headers
  nimhdf5/wrapper/H5Ppublic,                  ##  Property lists
  nimhdf5/wrapper/H5PLpublic,                 ##  Plugins
  nimhdf5/wrapper/H5Rpublic,                  ##  References
  nimhdf5/wrapper/H5Spublic,                  ##  Dataspaces
  nimhdf5/wrapper/H5Tpublic,                  ##  Datatypes
  nimhdf5/wrapper/H5Zpublic


##  Data filters
##  Predefined file drivers

include
  nimhdf5/wrapper/H5FDcore,                   ##  Files stored entirely in memory
  nimhdf5/wrapper/H5FDdirect,                 ##  Linux direct I/O
  nimhdf5/wrapper/H5FDfamily,                 ##  File families
  nimhdf5/wrapper/H5FDlog,                    ##  sec2 driver with I/O logging (for debugging)
  nimhdf5/wrapper/H5FDmpi,                    ##  MPI-based file drivers
  nimhdf5/wrapper/H5FDmulti,                  ##  Usage-partitioned file family
  nimhdf5/wrapper/H5FDsec2,                   ##  POSIX unbuffered file I/O
  nimhdf5/wrapper/H5FDstdio

when defined(H5_HAVE_WINDOWS): ##  Standard C buffered I/O
  import
    H5FDwindows

  ##  Windows buffered I/O
