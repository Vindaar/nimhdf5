
#############################################################################
# Copyright by The HDF Group.                                               #
# Copyright by the Board of Trustees of the University of Illinois.         #
# All rights reserved.                                                      #
#                                                                           #
# This file is part of HDF5.  The full HDF5 copyright notice, including     #
# terms governing use, modification, and redistribution, is contained in    #
# the COPYING file, which can be found at the root of the source code       #
# distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.  #
# If you do not have access to either file, you may request a copy from     #
# help@hdfgroup.org.                                                        #
#############################################################################

## This example illustrates how to create a dataset that is a 4 x 6 
## array.  It is used in the HDF5 Tutorial.

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
    dataspace_id: hid_t

    dims: array[2, hsize_t]
    status: herr_t
  
  # Create a new file using default properties.
  file_id = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT)

  # Create the data space for the dataset. 
  dims[0] = 4
  dims[1] = 6
  dataspace_id = H5Screate_simple(cint(2), cast[ptr hsize_t](addr(dims)), nil)

  # Create the dataset. 
  dataset_id = H5Dcreate2(file_id, "/dset", H5T_STD_I32BE, dataspace_id, 
                          H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  
  # End access to the dataset and release resources used by it.
  status = H5Dclose(dataset_id)

  # Terminate access to the data space. 
  status = H5Sclose(dataspace_id)

  # Close the file. 
  status = H5Fclose(file_id)

when isMainModule:
  main()
