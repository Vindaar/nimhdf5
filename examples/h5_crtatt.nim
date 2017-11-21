
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


## This example illustrates how to create an attribute attached to a
## dataset. It is used in the HDF5 Tutorial.

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
    attribute_id: hid_t
    dataspace_id: hid_t
    dims: hsize_t
    attr_data: array[2, cint]
  
    status: herr_t

  # Initialize the attribute data.
  attr_data[0] = 100
  attr_data[1] = 200

  # Open an existing file. */
  file_id = H5Fopen(FILE, H5F_ACC_RDWR, H5P_DEFAULT)

  # Open an existing dataset. */
  dataset_id = H5Dopen2(file_id, "/dset", H5P_DEFAULT)

  # Create the data space for the attribute. */
  dims = 2
  dataspace_id = H5Screate_simple(1, addr(dims), nil)

  # Create a dataset attribute. */
  attribute_id = H5Acreate2(dataset_id, "Units", H5T_STD_I32BE, dataspace_id, 
                            H5P_DEFAULT, H5P_DEFAULT)

  # Write the attribute data. */
  status = H5Awrite(attribute_id, H5T_NATIVE_INT, cast[ptr cint](addr(attr_data)))

  # Close the attribute. */
  status = H5Aclose(attribute_id)

  # Close the dataspace. */
  status = H5Sclose(dataspace_id)

  # Close to the dataset. */
  status = H5Dclose(dataset_id)

  # Close the file. */
  status = H5Fclose(file_id)

when isMainModule:
  main()
