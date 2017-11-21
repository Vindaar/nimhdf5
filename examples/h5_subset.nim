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

##  This example illustrates how to read/write a subset of data (a slab) 
##  from/to a dataset in an HDF5 file.  It is used in the HDF5 Tutorial. 
                                                                         
## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "subset.h5"
const DATASETNAME = "IntArray"
const RANK = 2
# subset dimensions
const DIM0_SUB = 3
const DIM1_SUB = 4
# size of dataset
const DIM0 = 8
const DIM1 = 10

proc main() =
  var
    # identifiers
    file_id: hid_t
    dataset_id: hid_t
    dataspace_id: hid_t
    memspace_id: hid_t
  
    dims: array[2, hsize_t]
    dimsm: array[2, hsize_t]
    # data to write
    data: array[DIM0, array[DIM1, cint]]
    # subset to write
    sdata: array[DIM0_SUB, array[DIM1_SUB, cint]]
    # buffer for read
    rdata: array[DIM0, array[DIM1, cint]]

    status: herr_t

    # size of subset in the file
    count: array[2, hsize_t]
    # subset offset in the file
    offset: array[2, hsize_t]
    stride: array[2, hsize_t]
    `block`: array[2, hsize_t]

   
  ##################################################################
  # Create a new file with default creation and access properties. #
  # Then create a dataset and write data to it and close the file  #
  # and dataset.                                                   #
  ##################################################################


  file_id = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT)

  dims[0] = DIM0
  dims[1] = DIM1
  dataspace_id = H5Screate_simple(RANK, cast[ptr hsize_t](addr(dims)), nil) 

  dataset_id = H5Dcreate2(file_id, DATASETNAME, H5T_STD_I32BE, dataspace_id,
                          H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)


  for j in 0..<DIM0:
    for i in 0..<DIM1:
      if i < int(DIM1 / 2):
        data[j][i] = cint(1)
      else:
        data[j][i] = cint(2)

  status = H5Dwrite(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL,
                    H5P_DEFAULT, cast[ptr cint](addr(data)))

  echo "\nData Written to File:\n"
  for i in 0..<DIM0:
    for j in 0..<DIM1:
      stdout.write(" " & $data[i][j])
    echo ""

  status = H5Sclose(dataspace_id)
  status = H5Dclose(dataset_id)
  status = H5Fclose(file_id)

  # Reopen the file and dataset and write a subset of 
  # values to the dataset. 

  file_id = H5Fopen(FILE, H5F_ACC_RDWR, H5P_DEFAULT)
  dataset_id = H5Dopen2(file_id, DATASETNAME, H5P_DEFAULT)

  # Specify size and shape of subset to write. 

  offset[0] = 1
  offset[1] = 2

  count[0]  = DIM0_SUB  
  count[1]  = DIM1_SUB

  stride[0] = 1
  stride[1] = 1

  `block`[0] = 1
  `block`[1] = 1

  # Create memory space with size of subset. Get file dataspace 
  # and select subset from file dataspace. 

  dimsm[0] = DIM0_SUB
  dimsm[1] = DIM1_SUB
  memspace_id = H5Screate_simple(RANK, cast[ptr hsize_t](addr(dimsm)), nil)

  dataspace_id = H5Dget_space(dataset_id)
  status = H5Sselect_hyperslab(dataspace_id, H5S_SELECT_SET,
                               cast[ptr hsize_t](addr(offset)),
                               cast[ptr hsize_t](addr(stride)),
                               cast[ptr hsize_t](addr(count)),
                               cast[ptr hsize_t](addr(`block`)))

  # Write a subset of data to the dataset, then read the 
  # entire dataset back from the file.  

  echo "\nWrite subset to file specifying:\n"
  echo "    offset=1x2 stride=1x1 count=3x4 `block`=1x1\n"
  for j in 0..<DIM0_SUB:
    for i in 0..<DIM1_SUB:
      sdata[j][i] = cint(5)

  status = H5Dwrite(dataset_id, H5T_NATIVE_INT, memspace_id,
                    dataspace_id, H5P_DEFAULT, cast[ptr cint](addr(sdata)))
  
  status = H5Dread(dataset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL,
                   H5P_DEFAULT, cast[ptr cint](addr(rdata)))

  echo "\nData in File after Subset is Written:\n"
  for i in 0..<DIM0:
    for j in 0..<DIM1:
      stdout.write(" " & $rdata[i][j])
    echo ""

  status = H5Sclose(memspace_id)
  status = H5Sclose(dataspace_id)
  status = H5Dclose(dataset_id)
  status = H5Fclose(file_id)
 
when isMainModule:
  main()
