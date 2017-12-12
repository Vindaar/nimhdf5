
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

type
  H5File = object
    name*: string
    # the file_id is the unique identifier of the opened file. Each
    # low level C call uses this file_id to idenfity the file to work
    # on. Should only be used if you need to access functions for which
    # no high level equivalent exists.
    file_id: hid_t
    # datasets is a table, which stores the names of datasets by string
    # while keeping the hid_t dataset_id as the value
    datasets: Table[string, int]

type
  H5FileStatus = enum
    H5_NOFILE = -1
    H5_OPENFILE = 1

# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW    = cuint(0x00FF)
    

proc newH5File(): H5File =
  ## default constructor for a H5File object, for internal use
  let dset = initTable[string, int]()
  result = H5File(name = "", file_id = H5_NOFILE, datasets = dset)

proc parseH5rw_type(rw_type: string): cuint =
  ## this proc simply acts as a parser for the read/write
  ## type string handed to the H5file() proc.
  ## inputs:
  ##    rw_type: string = the identifier string, which sets the
  ##            read / write options for a HDF5 file
  ## outputs:
  ##    cuint = returns a C uint, since that is the datatype of
  ##            the constans defined in H5Fpublic.nim. These can be
  ##            handed directly to the low level C functions
  ## throws:
  ##    
  if rw_type == "w" or
     rw_type == "rw" or
     rw_type == "write":
    result = H5F_ACC_RDWR
  elif rw_type == "r" or
       rw_type == "read":
    result = H5F_ACC_RDONLY
  else:
    result = H5F_INVALID_RW

template getH5rw_invalid_error() =
  """
  The given r/w type is invalid. Make sure to use one of the following:\n
  - {'r', 'read'} = read access\n
  - {'w', 'write', 'rw'} =  read/write access
  """
template getH5read_non_exist_file() =
  """ 
  Cannot open a non-existing file with read only access. Write access would\n
  create the file for you.
  """
proc H5file(name, rw_type: string): H5File {.raises = [IOError].} =
  ## this procedure is the main creating / opening procedure
  ## for HDF5 files.
  ## inputs:
  ##     name: string = the name or path to the HDF5 to open or to create
  ##           - if file does not exist, it is created if rw_type includes
  ##             a {'w', 'write'}. Else it throws an IOError
  ##           - if it exists, the H5File object for that file is returned
  ##     rw_tupe: string = an identifier to indicate whether to open an HDF5
  ##           with read or read/write access.
  ##           - {'r', 'read'} = read access
  ##           - {'w', 'write', 'rw'} =  read/write access
  ## outputs:
  ##    H5File: the H5File object, which is handed to all HDF5 related functions
  ##            (or thanks to unified calling syntax of nim, on which functions
  ##            are called). Contains all low level handling information needed
  ##            for the C functions
  ## throws:
  ##     IOError: in case file is opened without write access, but does not exist

  # TODO: implement truncate read / write option

  # create a new H5File object with default settings (i.e. no opened file etc)
  result = newH5File()
  # set the name of the file to be accessed
  result.name = name

  # parse rw_type to decide what to do
  let rw = parseH5rw_type(rw_type)
  if rw == H5F_INVALID_RW:
     raise newException(IOError, getH5rw_invalid_error())
  # else we can now use rw_type to correcly deal with file opening
  elif rw == H5F_ACC_RDONLY:
    # check whether the file actually exists
    if fileExists(name) == true:
      # then we call H5Fopen, last argument is fapl_id, specifying file access
      # properties (...somehwat unclear to me so far...)
      result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
    else:
      # cannot open a non existing file with read only properties
      raise newException(IOError,  getH5read_non_exist_file())
  elif rw == H5F_ACC_RDWR:
    # check whether file exists already
    if fileExists(name) == true:
      # then use open call
      result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
    else:
      # use create call
      result.file_id = H5Fcreate(name, rw, H5P_DEFAULT, H5P_DEFAULT)

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
