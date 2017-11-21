##############################################################################
# Copyright by The HDF Group.                                                #
# Copyright by the Board of Trustees of the University of Illinois.          #
# All rights reserved.                                                       #
#                                                                            #
# This file is part of HDF5.  The full HDF5 copyright notice, including      #
# terms governing use, modification, and redistribution, is contained in     #
# the COPYING file, which can be found at the root of the source code        #
# distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.   #
# If you do not have access to either file, you may request a copy from      #
# help@hdfgroup.org.                                                         #
##############################################################################

## This example illustrates how to create and close a group. 
## It is used in the HDF5 Tutorial.

## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "group.h5"

proc main() =
  var
    # identifiers
    file_id: hid_t
    group_id: hid_t

    status: herr_t

  # Create a new file using default properties. 
  file_id = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT)

  # Create a group named "/MyGroup" in the file. 
  group_id = H5Gcreate2(file_id, "/MyGroup", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Close the group. 
  status = H5Gclose(group_id)

  # Terminate access to the file. 
  status = H5Fclose(file_id)

when isMainModule:
  main()
