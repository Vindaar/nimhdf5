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

## This example illustrates how to create a dataset in a group.
## It is used in the HDF5 Tutorial.

## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "groups.h5"

proc main() =
  var
    # identifiers
    file_id: hid_t
    group_id: hid_t
    dataset_id: hid_t
    dataspace_id: hid_t
    dims: array[2, hsize_t]
    dset1_data: array[3, array[3, cint]]
    dset2_data: array[2, array[10, cint]]

    status: herr_t

  # Initialize the first dataset.
  for i in 0..<3:
    for j in 0..<3:
      dset1_data[i][j] = cint(j + 1)

  # Initialize the second dataset.
  for i in 0..<2:
    for j in 0..<10:
      dset2_data[i][j] = cint(j + 1)

  # Open an existing file. 
  file_id = H5Fopen(FILE, H5F_ACC_RDWR, H5P_DEFAULT)

  # Create the data space for the first dataset. 
  dims[0] = 3
  dims[1] = 3
  dataspace_id = H5Screate_simple(2, cast[ptr hsize_t](addr(dims)), nil)

  # Create a dataset in group "MyGroup". 
  dataset_id = H5Dcreate2(file_id, "/MyGroup/dset1", H5T_STD_I32BE, dataspace_id,
                          H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Write the first dataset. 
  status = H5Dwrite(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    cast[ptr cint](addr(dset1_data)))

  # Close the data space for the first dataset. 
  status = H5Sclose(dataspace_id)

  # Close the first dataset. 
  status = H5Dclose(dataset_id)

  # Open an existing group of the specified file. 
  group_id = H5Gopen2(file_id, "/MyGroup/Group_A", H5P_DEFAULT)

  # Create the data space for the second dataset. 
  dims[0] = 2
  dims[1] = 10
  dataspace_id = H5Screate_simple(2, cast[ptr hsize_t](addr(dims)), nil)

  # Create the second dataset in group "Group_A". 
  dataset_id = H5Dcreate2(group_id, "dset2", H5T_STD_I32BE, dataspace_id, 
                          H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

  # Write the second dataset. 
  status = H5Dwrite(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    cast[ptr cint](addr(dset2_data)))

  # Close the data space for the second dataset. 
  status = H5Sclose(dataspace_id)

  # Close the second dataset 
  status = H5Dclose(dataset_id)

  # Close the group. 
  status = H5Gclose(group_id)

  # Close the file. 
  status = H5Fclose(file_id)

when isMainModule:
  main()
