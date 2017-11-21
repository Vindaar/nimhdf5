
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


## This example illustrates how to write and read data in an existing
## dataset.  It is used in the HDF5 Tutorial.

## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "dset.h5"

proc main() =
  var
    # identifiers
    file_id: hid_t
    dataset_id: hid_t
    dset_data: array[4, array[6, cint]]

    status: herr_t

  # Initialize the dataset.
  for i in 0..<4:
    for j in 0..<6:
      dset_data[i][j] = cint(i * 6 + j + 1)

  # Open an existing file. 
  file_id = H5Fopen(FILE, H5F_ACC_RDWR, H5P_DEFAULT)

  # Open an existing dataset. 
  dataset_id = H5Dopen2(file_id, "/dset", H5P_DEFAULT)

  # Write the dataset. 
  status = H5Dwrite(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    cast[ptr cint](addr(dset_data)))

  status = H5Dread(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT, 
                   cast[ptr cint](addr(dset_data)))

  # Close the dataset. 
  status = H5Dclose(dataset_id)

  # Close the file. 
  status = H5Fclose(file_id)

when isMainModule:
  main()
