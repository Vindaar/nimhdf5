
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

import tables
import os, ospaths
import typeinfo
import typetraits
import sequtils
import strutils
import options
import future

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
const FILE = "dset.h5"

type
  # an object to store information about a hdf5 dataset. It is a combination of
  # an HDF5 dataspace and dataset id (contains both of them)
  H5DataSet = object
    name*: string
    # we store the shape information internally as a seq, so that we do
    # not have to know about it at compile time
    shape*: seq[int]
    # descriptor of datatype as string of the Nim type
    dtype*: string
    # actual HDF5 datatype used as a hid_t, this can be handed to functions needing
    # its datatype
    dtype_c*: hid_t
    # parent string, which contains the name of the group in which the
    # dataset is located
    parent*: string
    # the id of the parent (location id in HDF5 lang). Either file id or group ID
    parent_id*: hid_t
    # filename string, in which the dataset is located
    file*: string
    #  the id of the reserved dataspace
    dataspace_id*: hid_t
    # the id of the dataset
    dataset_id*: hid_t

  # an object to store information about a HDF5 group
  H5Group = object
    name*: string
    # parent string, which contains the name of the group in which the
    # dataset is located
    parent*: string
    # the id of the parent (location id in HDF5 lang). Either file id or group ID
    parent_id*: hid_t
    # filename string, in which the dataset is located
    file*: string
    # the id of the HDF5 group (its location id)
    group_id*: hid_t
    # TODO: think, should H5Group contain a table about its dataspaces? Or should
    # all of this be in H5FileObj? Probably better here for accessing it later via
    # [] I guess
    # However: then H5FileObj needs to still know (!) about its dataspaces and where
    # they are located. Easily done by keeping a table of string of each dataset, which
    # contains their location simply by the path and have a table of H5Group objects
    datasets*: Table[string, H5DataSet]

  H5FileObj = object
    name*: string
    # the file_id is the unique identifier of the opened file. Each
    # low level C call uses this file_id to idenfity the file to work
    # on. Should only be used if you need to access functions for which
    # no high level equivalent exists.
    file_id: hid_t
    # var which stores access type. For internal use. Might be needed
    # for access to low level C calls, which have no high level equiv.
    rw_type: cuint
    # var to store error codes of called C functions
    err: herr_t
    # var to store status of C calls
    status: hid_t
    # groups is a table, which stores the names of groups stored in the file
    groups: Table[string, H5Group]
    # datasets is a table, which stores the names of datasets by string
    # while keeping the hid_t dataset_id as the value
    datasets: Table[string, H5DataSet]
    dataspaces: Table[string, hid_t]

  # H5Tree = object
  #   file*: string
  #   branches*: seq[ref H5Branch]
  #   leaves*: HashSet[ref H5DataSet]

  # H5Branch = object
  #   name*: string
  #   branches*: seq[ref H5Branch]
  #   leaves*: HashSet[ref H5DataSet]
  #   parent*: ref H5Branch
  #   root*: ref H5Tree
    
const    
    H5_NOFILE = hid_t(-1)
    H5_OPENFILE = hid_t(1)

# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW    = cuint(0x00FF)


# proc hash(x: H5DataSet): Hash =
#   # the hash value of a H5DataSet only depends on
#   # its name, shape, dtype and file, since these
#   # are the properties, which uniquely idenfity a
#   # dataset in the HDF5 file
#   var h: Hash = 0
#   h = h !& x.name
#   h = h !& x.shape
#   h = h !& x.dtype
#   h = h !& file
#   result = !$h


proc newH5File(): H5FileObj =
  ## default constructor for a H5File object, for internal use
  let dset = initTable[string, H5DataSet]()
  let dspace = initTable[string, hid_t]()  
  result = H5FileObj(name: "",
                     file_id: H5_NOFILE,
                     rw_type: H5F_INVALID_RW,
                     err: -1,
                     status: -1,
                     datasets: dset,
                     dataspaces: dspace)

proc newH5DataSet(name: string = ""): H5DataSet =
  ## default constructor for a H5File object, for internal use
  let shape: seq[int] = @[]
  result = H5DataSet(name: name,
                     shape: shape,
                     dtype: nil,
                     dtype_c: -1,
                     parent: "",
                     file: "",
                     dataspace_id: -1,
                     dataset_id: -1)

proc newH5Group(name: string = ""): H5Group =
  ## default constructor for a H5Group object, for internal use
  let datasets = initTable[string, H5DataSet]()
  result = H5Group(name: name,
                   parent: "",
                   parent_id: -1,
                   file: "",
                   group_id: -1,
                   datasets: datasets)

proc isInH5Root(name: string): bool =
  # this procedure returns whether the given group or dataset is in a group
  # or in the root of the HDF5 file.
  # NOTE: make suree the name is a formated string via formatName!
  #       otherwise the result may be completely wrong
  let n_slash = count(name, '/')
  assert n_slash > 0
  if n_slash > 1:
    result = false
  elif n_slash == 1:
    result = true

template getH5Id(h5_object: typed): hid_t =
  # this template returns the correct location id of either
  # - a H5FileObj
  # - a H5DataSet
  # - a H5Group
  var result: hid_t = -1
  when h5_object is H5FileObj:
    result = h5_object.file_id
  elif h5_object is H5DataSet:
    result = h5_object.dataspace_id
  elif h5_object is H5Group:
    result = h5_object.group_id
  result

template getParent(dset_name: string): string =
  # given a dataset name after formating (!), return the parent name,
  # simly done by a call to parentDir from ospaths
  var result: string
  result = parentDir(dset_name)
  if result == "":
    result = "/"
  result

proc findExistingParent(h5f: H5FileObj, name: string): Option[H5Group] =
  # proc to find the first existing parent of a given object in H5F
  # recursively
  # inputs:
  #    h5f: H5FileObj: the object in which to look for the parent
  #    name: string: name of object from which to start looking upwards
  # outputs:
  #    Option[H5Group] = if an existing H5Group is found recursively an
  #      optional type is returned with some(result), while none(H5Group)
  #      is returned in case the root is the first existing parent
  if name != "/":
    # in this case we're not at the root, so check whether name exists
    let exists = hasKey(h5f.groups, name)
    if exists == true:
      result = some(h5f.groups[name])
    else:
      result = findExistingParent(h5f, getParent(name))
  else:
    # no parent found, first existing parent is root
    result = none(H5Group)

template getParentId(h5f: H5FileObj, h5_object: typed): hid_t =
  # template returns the id of the parent of h5_object
  var result: hid_t = -1
  let parent = getParent(h5_object.name)
  when h5_object is H5DataSet:
    discard
  elif h5_object is H5Group:
    let p = findExistingParent(h5f, h5_object.name)
    if isSome(p) == true:
      result = getH5Id(unsafeGet(p))
    else:
      # this means the only existing parent is root
      result = h5f.file_id
  else:
    echo "Warning: This should not happen, as we have no other types so far. If you see this"
    echo "you handed a not supported type to getParentId()"
  result

proc parseH5rw_type(rw_type: string, exists: bool): cuint =
  ## this proc simply acts as a parser for the read/write
  ## type string handed to the H5file() proc.
  ## inputs:
  ##    rw_type: string = the identifier string, which sets the
  ##            read / write options for a HDF5 file
  ##    exits: bool = a bool to tell whether the file for which
  ##          we need to parse r/w already exists. Changes
  ##          potential return values
  ## outputs:
  ##    cuint = returns a C uint, since that is the datatype of
  ##            the constans defined in H5Fpublic.nim. These can be
  ##            handed directly to the low level C functions
  ## throws:
  ##    
  if rw_type == "w" or
     rw_type == "rw" or
     rw_type == "write":
    if exists == true:
      result = H5F_ACC_RDWR
    else:
      result = H5F_ACC_EXCL
  elif rw_type == "r" or
       rw_type == "read":
    result = H5F_ACC_RDONLY
  else:
    result = H5F_INVALID_RW

template getH5rw_invalid_error(): string =
  
  """
  The given r/w type is invalid. Make sure to use one of the following:\n
  - {'r', 'read'} = read access\n
  - {'w', 'write', 'rw'} =  read/write access
  """
template getH5read_non_exist_file(): string =
  """ 
  Cannot open a non-existing file with read only access. Write access would\n
  create the file for you.
  """
proc H5file(name, rw_type: string): H5FileObj = #{.raises = [IOError].} =
  ## this procedure is the main creating / opening procedure
  ## for HDF5 files.
  ## inputs:
  ##     name: string = the name or path to the HDF5 to open or to create
  ##           - if file does not exist, it is created if rw_type includes
  ##             a {'w', 'write'}. Else it throws an IOError
  ##           - if it exists, the H5FileObj object for that file is returned
  ##     rw_tupe: string = an identifier to indicate whether to open an HDF5
  ##           with read or read/write access.
  ##           - {'r', 'read'} = read access
  ##           - {'w', 'write', 'rw'} =  read/write access
  ## outputs:
  ##    H5FileObj: the H5FileObj object, which is handed to all HDF5 related functions
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

  # before we can parse the read/write identifier, we need to check whether
  # the HDF5 file exists. This determines whether we use H5Fcreate or H5Fopen,
  # which both need different file flags
  let exists = fileExists(name)

  # parse rw_type to decide what to do
  let rw = parseH5rw_type(rw_type, exists)
  result.rw_type = rw
  if rw == H5F_INVALID_RW:
     raise newException(IOError, getH5rw_invalid_error())
  # else we can now use rw_type to correcly deal with file opening
  elif rw == H5F_ACC_RDONLY:
    # check whether the file actually exists
    if exists == true:
      # then we call H5Fopen, last argument is fapl_id, specifying file access
      # properties (...somehwat unclear to me so far...)
      echo "exists and read only"
      result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
    else:
      # cannot open a non existing file with read only properties
      raise newException(IOError,  getH5read_non_exist_file())
  elif rw == H5F_ACC_RDWR:
    # check whether file exists already
    # then use open call
    echo "exists and read write"      
    result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
  elif rw == H5F_ACC_EXCL:
    # use create call
    echo "rw is  ", rw
    result.file_id = H5Fcreate(name, rw, H5P_DEFAULT, H5P_DEFAULT)


  # after having opened / created the given file, we get the datasets etc.
  # which are stored in the file
    

proc parseShapeTuple[T: tuple](dims: T): seq[hsize_t] =
  ## parses the shape tuple handed to create_dataset
  ## receives a tuple of one datatype, which was previously
  ## determined using getCtype()
  ## inputs:
  ##    dims: T = tuple of type T for which we need to allocate
  ##              space
  ## outputs:
  ##    seq[hsize_t] = seq of hsize_t of length len(dims), containing
  ##            the size of each dimension of dset
  ##            Note: H5File needs to be aware of that size!
  var n_dims: int
  # count the number of fields in the array, since that is number
  # of dimensions we have
  for field in dims.fields:
    inc n_dims

  result = newSeq[hsize_t](n_dims)
  # now set the elements of result to the values in the tuple
  var count: int = 0
  for el in dims.fields:
    # now set the value of each dimension 
    result[count] = hsize_t(el)
    inc count
  
  
template getCtype(dtype: typedesc): hid_t =
  # given a typedesc, we return a corresponding
  # C data type. This is a template, since we
  # the compiler won't be able to determine
  # the generic return type by the given typedesc
  # inputs:
  #    dtype: typedesc = a typedescription of the data type for the dataset
  #          which we want to store
  # outputs:
  #    hid_t = the identifier int value of the HDF5 library for the data types

  var result_type: hid_t = -1
  when dtype is int8:
    # for 8 bit int we take the STD LE one, since there is no
    # native type available (besides char)
    when cpuEndian == littleEndian:
      result_type = H5T_STD_I8LE
    else:
      result_type = H5T_STD_I8BE
  elif dtype is int16:
    result_type = H5T_NATIVE_SHORT
  elif dtype is int32:
    result_type = H5T_NATIVE_INT # H5T_STD_I32LE
  elif dtype is int or dtype is int64:
    result_type = H5T_NATIVE_LLONG # H5T_STD_I64LE
  elif dtype is uint8:
    # for 8 bit int we take the STD LE one, since there is no
    # native type available (besides char)
    when cpuEndian == littleEndian:
      result_type = H5T_STD_U8LE
    else:
      result_type = H5T_STD_U8BE
  elif dtype is uint16:
    result_type = H5T_NATIVE_USHORT
  elif dtype is uint32:
    result_type = H5T_NATIVE_UINT # H5T_STD_I32LE
  elif dtype is uint or dtype is uint64:
    result_type = H5T_NATIVE_ULLONG # H5T_STD_I64LE    
  elif dtype is float32:
    result_type = H5T_NATIVE_FLOAT # H5T_STD_    
  elif dtype is float or dtype is float64:
    result_type = H5T_NATIVE_DOUBLE # H5T_STD_
  elif dtype is char:
    # Nim's char is an unsigned char!
    result_type = H5T_NATIVE_UCHAR
  result_type

proc formatName(name: string): string =
  # this procedure formats a given group / dataset namy by prepending
  # a potenatially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  result = "/" & strip(name, chars = ({'/'} + Whitespace + NewLines))

proc createGroupFromParent(h5f: var H5FileObj, group_name: string): H5Group =
  # procedure to create a group within a H5F
  # Note: this procedure requires that the parentb of the group
  # to create exists, while the group to be created does not!
  # i.e. only call this function of you are certain of these two
  # facts
  # inputs:
  #    h5f: H5FilObj = the file in which to create the group
  #    group_name: string = the name of the group to be created
  # outputs:
  #    H5Group = returns a group object with the basic properties set

  # the location id (id of group or the root) at which to create the group
  var location_id: hid_t
  # default for parent is root, might be changed if group_name lies outside
  # of root
  var p_str: string = "/"
  if isInH5Root(group_name) == false:
    # the location id is the id of the parent of group_name
    # i.e. the group is created in the parent group
    p_str = getParent(group_name)
    let parent = h5f.groups[p_str]
    location_id = getH5Id(parent)
  else:
    # the group will be created in the root of the file
    location_id = h5f.file_id

  result = newH5Group(group_name)
  result.group_id = H5Gcreate2(location_id, group_name, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  result.parent = p_str
  # since we know that the parent exists, we can simply use the (recursive!) getParentId
  # to get the id of the parent, without worrying about receiving a parent id of an
  # object, which is in reality not a parent
  result.parent_id = getParentId(h5f, result)
  result.file = h5f.name

  # now that we have created the group fully (including IDs), we can add it
  # to the H5FileObj
  h5f.groups[group_name] = result
  
  
proc create_group(h5f: var H5FileObj, group_name: string): H5Group =
  # checks whether the given group name already exists or not.
  # If yes:
  #   return the H5Group object,
  # else:
  #   check the parent of that group recursively as well.
  #   If parent exists:
  #     create new group and return it
  # inputs:
  #    h5f: H5FileObj = the h5f file object in which to look for the group
  #    group_name: string = the name of the group to check for in h5f
  # outputs:
  #    H5Group = an object containing the (newly) created group in the file
  # NOTE: the creation of the groups via recusion is not all that nice,
  #   because it relies heavily on state changes via the h5f object
  #   Think about a cleaner way?
  let exists = hasKey(h5f.groups, group_name)
  if exists == true:
    # then we return the object
    result = h5f.groups[group_name]
  else:
    # we need to create it. But first check whether the parent
    # group already exists
    # whether such a group already exists
    # in the HDF5 file and h5f is simply not aware of it yet
    if isInH5Root(group_name) == false:
      let parent = create_group(h5f, getParent(group_name))
      result = createGroupFromParent(h5f, group_name)
    else:
      result = createGroupFromParent(h5f, group_name)
    
proc create_dataset[T: tuple](h5f: var H5FileObj, dset_raw: string, shape: T, dtype: typedesc) =
  ## proceduer to create a dataset given a H5file object. The shape of
  ## that type is given as a tuple, the datatype as a typedescription
  ## inputs:
  ##    h5file: H5FileObj = the H5FileObj received by H5file() into which the data
  ##                   set belongs
  ##    shape: T = the shape of the dataset, given as a tuple
  ##    dtype = typedesc = a Nim typedesc (e.g. int, float, etc.) for that
  ##            dataset. vlen not yet supported
  ## outputs:
  ##    ... some dataset object, part of the file?!
  ## throws:
  ##    ... some H5 C related errors ?!

  # TODO: before call to create_simple and create2, we need to check whether
  # any such dataset already exists. Could include that in the opening procedure
  # by getting all groups etc in the file (by id, not reading the data)

  # remove any trailing / and insert potential missing root /
  var dset_name = formatName(dset_raw)

  # first get the appropriate datatype for the given Nim type
  let dtype_c = getCtype(dtype)

  # need to deal with the shape of the dataset to be created
  #let shape_ar = parseShapeTuple(shape)
  var shape_seq = parseShapeTuple(shape)

  # set up the dataset object
  var dset = newH5DataSet(dset_name)
  dset.dtype   = name(dtype)
  dset.dtype_c = dtype_c
  dset.file    = h5f.name
  dset.parent  = getParent(dset_name)

  # given the full dataset name, we need to check whether the group in which the
  # dataset is supposed to be placed, already exists
  let is_root = isInH5Root(dset_name)
  var group: H5Group
  if is_root == false:
    group = create_group(h5f, dset.parent)
  
  # TODO: CHANGE THIS; determine parent using os file functions
  echo "Getting parent Id of ", dset.name
  dset.parent  = "/"
  dset.parent_id = getParentId(h5f, dset)
  
  dset.parent_id = h5f.file_id
  dset.shape   = map(shape_seq, (x: hsize_t) -> int => int(x))
  
  # check whether there already exists a dataset with the given name
  # first in H5FileObj:
  var exists = hasKey(h5f.datasets, dset_name)
  if exists == false:
    # then check the actual file for a dataset with the given name
    # TODO: FOR NOW the location id given to H5Dopen2 is only the file id
    # once we have the parent properly determined, we can also check for
    # the parent (group) id!
    echo "Checking if dataset exists via H5Lexists ", dset.name    
    dset.dataset_id = H5Lexists(h5f.file_id, dset.name, H5P_DEFAULT)
    if dset.dataset_id > 0:
      # in this case successful, dataset exists already
      exists = true
    elif dset.dataset_id == 0:
      # does not exist
      # now
      echo "Does not exist, so create dataspace ", dset.name          
      let dataspace_id = H5Screate_simple(cint(len(shape_seq)), addr(shape_seq[0]), nil)
      
      # using H5Dcreate2, try to create the dataset
      echo "Does not exist, so create dataset via H5create2 ", dset.name                
      let dataset_id = H5Dcreate2(h5f.file_id, dset_name, dtype_c, dataspace_id,
                                  H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

      dset.dataspace_id = dataspace_id
      dset.dataset_id = dataset_id
    else:
      echo "You probably see the HDF5 errors piling up..."
  

  #h5f.dataspaces[dset_name] = dset
  h5f.datasets[dset_name] = dset
  #dataset_id = H5Dcreate2(h5f.file_id, "/dset", H5T_STD_I32BE, dataspace_id, 
  
  
proc main() =
  var
    # identifiers
    file_id: hid_t
    dataset_id: hid_t
    dataspace_id: hid_t

    dims: array[2, hsize_t]
    status: herr_t
  
  # Create a new file using default properties.
  #file_id = H5Fcreate(FILE, H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT)
  var h5f = H5file(FILE, "rw")

  h5f.create_dataset("/dset", (2, 2), float)

  # # Create the data space for the dataset. 
  # dims[0] = 4
  # dims[1] = 6
  #var d: seq[hsize_t] = @[hsize_t(4), hsize_t(6)]
  #dataspace_id = H5Screate_simple(cint(2), addr(d[0]), nil)#cast[ptr hsize_t](addr(dims)), nil)

  # # Create the dataset. 
  # dataset_id = H5Dcreate2(h5f.file_id, "/dset", H5T_STD_I32BE, dataspace_id, 
  #                         H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  
  # # End access to the dataset and release resources used by it.
  # status = H5Dclose(dataset_id)

  # # Terminate access to the data space. 
  # status = H5Sclose(dataspace_id)

  # # Close the file. 
  status = H5Fclose(h5f.file_id)

when isMainModule:
  main()
