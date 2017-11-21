
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

## This example illustrates the creation of groups using absolute and 
## relative names.  It is used in the HDF5 Tutorial.

## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "groups.h5"

proc main() =
  var
    # identifiers
    file_id: hid_t
    group1_id: hid_t
    group2_id: hid_t
    group3_id: hid_t  

    status: herr_t

  # Create a new file using default properties. 
  file_id = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT)

  # Create group "MyGroup" in the root group using absolute name. 
  group1_id = H5Gcreate2(file_id, "/MyGroup", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Create group "Group_A" in group "MyGroup" using absolute name. 
  group2_id = H5Gcreate2(file_id, "/MyGroup/Group_A", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Create group "Group_B" in group "MyGroup" using relative name. 
  group3_id = H5Gcreate2(group1_id, "Group_B", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Close groups. 
  status = H5Gclose(group1_id)
  status = H5Gclose(group2_id)
  status = H5Gclose(group3_id)

  # Close the file. 
  status = H5Fclose(file_id)

when isMainModule:
  main()
