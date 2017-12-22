import tables
import os, ospaths
import typeinfo
import typetraits
import sequtils
import strutils
import options
import future
import algorithm
#import seqmath
#import arraymancer
import macros

import ../src/hdf5_wrapper
import ../src/nimhdf5/H5nimtypes

# simple list of TODOs
# TODO:
#  - add ability to read / write hyperslabs
#  - add ability to write arraymancer.Tensor
#  - add a lot of safety checks 


type
  # an object to store information about a hdf5 dataset. It is a combination of
  # an HDF5 dataspace and dataset id (contains both of them)

  grp_str*  = distinct string
  dset_str* = distinct string

  DsetReadWrite = enum
    RW_ALL

  H5Object = object of RootObj
    name*: string
    parent*: string
    parent_id*: hid_t
    
  H5DataSet* = object #of H5Object
    name*: string
    # we store the shape information internally as a seq, so that we do
    # not have to know about it at compile time
    shape*: seq[int]
    # descriptor of datatype as string of the Nim type
    dtype*: string
    dtypeAnyKind*: AnyKind
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
    # `all` index, to indicate that we wish to set the whole dataset to the
    # value on the RHS (has to be exactly the same shape!)
    all*: DsetReadWrite

  # an object to store information about a HDF5 group
  H5Group* = object #of H5Object
    name*: string
    # # parent string, which contains the name of the group in which the
    # # dataset is located
    parent*: string
    # # the id of the parent (location id in HDF5 lang). Either file id or group ID
    parent_id*: hid_t
    # filename string, in which the dataset is located
    file*: string
    # file id of the file in which group is stored
    file_id*: hid_t
    # the id of the HDF5 group (its location id)
    group_id*: hid_t
    # TODO: think, should H5Group contain a table about its dataspaces? Or should
    # all of this be in H5FileObj? Probably better here for accessing it later via
    # [] I guess
    # However: then H5FileObj needs to still know (!) about its dataspaces and where
    # they are located. Easily done by keeping a table of string of each dataset, which
    # contains their location simply by the path and have a table of H5Group objects
    datasets*: Table[string, H5DataSet]
    # each group may have subgroups itself, keep table of these
    groups: ref Table[string, ref H5Group]


  H5FileObj* = object #of H5Object
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
    groups*: ref Table[string, ref H5Group]
    # datasets is a table, which stores the names of datasets by string
    # while keeping the hid_t dataset_id as the value
    datasets*: Table[string, H5DataSet]
    dataspaces: Table[string, hid_t]

const    
    H5_NOFILE = hid_t(-1)
    H5_OPENFILE = hid_t(1)

# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW    = cuint(0x00FF)

proc newH5File*(): H5FileObj =
  ## default constructor for a H5File object, for internal use
  let dset = initTable[string, H5DataSet]()
  let dspace = initTable[string, hid_t]()
  let groups = newTable[string, ref H5Group]()
  result = H5FileObj(name: "",
                     file_id: H5_NOFILE,
                     rw_type: H5F_INVALID_RW,
                     err: -1,
                     status: -1,
                     datasets: dset,
                     dataspaces: dspace,
                     groups: groups)

proc newH5DataSet*(name: string = ""): H5DataSet =
  ## default constructor for a H5File object, for internal use
  let shape: seq[int] = @[]
  result = H5DataSet(name: name,
                     shape: shape,
                     dtype: nil,
                     dtype_c: -1,
                     parent: "",
                     file: "",
                     dataspace_id: -1,
                     dataset_id: -1,
                     all: RW_ALL)

proc newH5Group*(name: string = ""): ref H5Group =
  ## default constructor for a H5Group object, for internal use
  let datasets = initTable[string, H5DataSet]()
  let groups = newTable[string, ref H5Group]()
  result = new H5Group
  result.name = name
  result.parent = ""
  result.parent_id = -1
  result.file = ""
  result.datasets = datasets
  result.groups = groups
  # result = H5Group(name: name,
  #                  parent: "",
  #                  parent_id: -1,
  #                  file: "",
  #                  group_id: -1,
  #                  datasets: datasets,
  #                  groups: groups)

proc `$`*(group: ref H5Group): string =
  result = "\n{\n\t'name': " & group.name & "\n\t'parent': " & group.parent & "\n\t'parent_id': " & $group.parent_id
  result = result & "\n\t'file': " & group.file & "\n\t'group_id': " & $group.group_id & "\n\t'datasets': " & $group.datasets
  result = result & "\n\t'groups': {"
  for k, v in group.groups:
    result = result & "\n\t\t" & k
  result = result & "\n\t}\n}"

proc `$`*(group: H5Group): string =
  result = "\n{\n\t'name': " & group.name & "\n\t'parent': " & group.parent & "\n\t'parent_id': " & $group.parent_id
  result = result & "\n\t'file': " & group.file & "\n\t'group_id': " & $group.group_id & "\n\t'datasets': " & $group.datasets
  result = result & "\n\t'groups': {"
  for k, v in group.groups:
    result = result & "\n\t\t" & k
  result = result & "\n\t}\n}"

proc h5ToNimType(dtype_id: hid_t): AnyKind =
  ## proc to return a type descriptor (via typeinfo.AnyKind) describing the given
  ## H5 type. From the return value, we can set the data type in the H5DataSet obj
  ## inputs:
  ##     dtype_id: hid_t = datatype id returned by the H5 library about the datasets' type
  ## outputs:
  ##     AnyKind = typeinfo.AnyKind enum value corresponding to a Nim datatype. We use the
  ##            string representation of it to set the H5DataSet.dtype: string to its
  ##            correct value
  ## throws:
  ##    KeyError: if the given H5 data type is currently not mapped to a Nim type
  ##              (see src/nimhdf5/H5Tpublic.nim for a list of *all* H5 types...)
  
  echo "dtype is ", dtype_id
  # TODO: we may can seperate the dtypes by class using H5Tget_class, which returns a value
  # of the H5T_class_t enum (e.g. H5T_FLOAT)
  echo H5Tget_class(dtype_id)
  echo "native is ", H5Tget_native_type(dtype_id, H5T_DIR_ASCEND)
  # TODO: make sure the types are correctly identified!
  # MAKING PROBLEMS ALREADY! int64 is read back as a NATIVE_LONG, which thus needs to be
  # converted to int64
  
  if H5Tequal(H5T_NATIVE_DOUBLE, dtype_id) == 1:
    echo "is float64"
    result = akFloat64
  elif H5Tequal(H5T_NATIVE_FLOAT, dtype_id) == 1:
    result = akFloat32
  elif H5Tequal(H5T_NATIVE_SHORT, dtype_id) == 1:
    result = akInt32
  elif H5Tequal(H5T_NATIVE_LONG, dtype_id) == 1 or H5Tequal(H5T_NATIVE_INT, dtype_id) == 1 or H5Tequal(H5T_NATIVE_LLONG, dtype_id) == 1:
    result = akInt64
  elif H5Tequal(H5T_NATIVE_UINT, dtype_id) == 1 or H5Tequal(H5T_NATIVE_ULONG, dtype_id) == 1:
    result = akUint32
  elif H5Tequal(H5T_NATIVE_ULLONG, dtype_id) == 1:
    result = akUint64
  elif H5Tequal(H5T_NATIVE_SHORT, dtype_id) == 1:
    result = akInt16
  elif H5Tequal(H5T_NATIVE_USHORT, dtype_id) == 1:
    result = akUint16
  elif H5Tequal(H5T_NATIVE_CHAR, dtype_id) == 1:
    result = akChar
  elif H5Tequal(H5T_NATIVE_UCHAR, dtype_id) == 1:
    result = akUint8
  else:
    raise newException(KeyError, "Warning: the following H5 type could not be converted: $#" % $dtype_id)
  
template nimToH5type*(dtype: typedesc): hid_t =
  # given a typedesc, we return a corresponding
  # H5 data type. This is a template, since we
  # the compiler won't be able to determine
  # the generic return type by the given typedesc
  # inputs:
  #    dtype: typedesc = a typedescription of the data type for the dataset
  #          which we want to store
  # outputs:
  #    hid_t = the identifier int value of the HDF5 library for the data types

  # TODO: this still seems to be very much wrong and it's only valid for my machine
  # (64 bit) anyways. 

  var result_type: hid_t = -1
  when dtype is int8:
    # for 8 bit int we take the STD LE one, since there is no
    # native type available (besides char)
    # TODO: are we doing this the correct way round? maybe only relevant, if
    # we read data, as the data is STORED in some byte order...!
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

proc existsInFile(h5_id: hid_t, name: string): hid_t =
  # convenience function to check whether a given object exists in a
  # H5 file
  result = H5Lexists(h5_id, name, H5P_DEFAULT)

template getH5Id(h5_object: typed): hid_t =
  # this template returns the correct location id of either
  # - a H5FileObj
  # - a H5DataSet
  # - a H5Group
  # var result: hid_t = -1
  when h5_object is H5FileObj:
    let result = h5_object.file_id
  elif h5_object is H5DataSet:
    let result = h5_object.dataspace_id
  elif h5_object is H5Group:
    let result = h5_object.group_id
  result

template getParent(dset_name: string): string =
  # given a dataset name after formating (!), return the parent name,
  # simly done by a call to parentDir from ospaths
  var result: string
  result = parentDir(dset_name)
  if result == "":
    result = "/"
  result

proc nameFirstExistingParent(h5f: H5FileObj, name: string): string =
  # similar to firstExistingParent, except that only the name of
  # the object is returned
  discard

proc firstExistingParent[T](h5f: T, name: string): Option[H5Group] =
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
      result = some(h5f.groups[name][])
    else:
      result = firstExistingParent(h5f, getParent(name))
  else:
    # no parent found, first existing parent is root
    result = none(H5Group)

template getParentId[T](h5f: T, h5_object: typed): hid_t =
  # template returns the id of the first existing parent of h5_object
  var result: hid_t = -1
  let parent = getParent(h5_object.name)
  when h5_object is H5DataSet:
    discard
  elif h5_object is H5Group:
    let p = firstExistingParent(h5f, h5_object.name)
    if isSome(p) == true:
      result = getH5Id(unsafeGet(p))
    else:
      # this means the only existing parent is root
      result = h5f.file_id
  else:
    echo "Warning: This should not happen, as we have no other types so far. If you see this"
    echo "you handed a not supported type to getParentId()"
  result
  

# template get(h5f: H5FileObj, dset_name: string): H5Object =
#   # convenience proc to return the dataset with name dset_name
#   # if it does not exist, KeyError is thrown
#   # inputs:
#   #    h5f: H5FileObj = the file object from which to get the dset
#   #    obj_name: string = name of the dset to get
#   # outputs:
#   #    H5DataSet = if dataset is found
#   # throws:
#   #    KeyError: if dataset could not be found
#   # let exists = hasKey(h5f.datasets, dset_name)
#   # if exists == true:
#   #   result = h5f.datasets[dset_name]
#   # else:
#   #   discard
#   var is_dataset: bool = false
#   let dset_exist = hasKey(h5f.datasets, dset_name)
#   if dset_exist == false:
#     let group_exist = hasKey(h5f.groups, dset_name)
#     if group_exist == false:
#       raise newException(KeyError, "Object with name: " & dset_name & " not found in file " & h5f.name)
#     else:
#       is_dataset = false
#   else:
#     is_dataset = true
#   if is_dataset == true:
#     let result = h5f.datasets[dset_name]
#     result
#   else:
#     let result = h5f.groups[dset_name]
#     result

proc getDset(h5f: H5FileObj, dset_name: string): Option[H5DataSet] =
  # convenience proc to return the dataset with name dset_name
  # if it does not exist, KeyError is thrown
  # inputs:
  #    h5f: H5FileObj = the file object from which to get the dset
  #    obj_name: string = name of the dset to get
  # outputs:
  #    H5DataSet = if dataset is found
  # throws:
  #    KeyError: if dataset could not be found
  # let exists = hasKey(h5f.datasets, dset_name)
  # if exists == true:
  #   result = h5f.datasets[dset_name]
  # else:
  #   discard
  let dset_exist = hasKey(h5f.datasets, dset_name)
  if dset_exist == false:
    #raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
    result = none(H5DataSet)
  else:
    result = some(h5f.datasets[dset_name])

proc getGroup(h5f: H5FileObj, grp_name: string): Option[H5Group] =
  # convenience proc to return the group with name grp_name
  # if it does not exist, KeyError is thrown
  # inputs:
  #    h5f: H5FileObj = the file object from which to get the group
  #    obj_name: string = name of the group to get
  # outputs:
  #    H5Group = if group is found
  # throws:
  #    KeyError: if group could not be found
  # let exists = hasKey(h5f.groups, grp_name)
  # if exists == true:
  #   result = h5f.groups[grp_name]
  # else:
  #   discard
  let grp_exist = hasKey(h5f.datasets, grp_name)
  if grp_exist == false:
    #raise newException(KeyError, "Dataset with name: " & grp_name & " not found in file " & h5f.name)
    result = none(H5Group)
  else:
    result = some(h5f.groups[grp_name][])


template get(h5f: var H5FileObj, dset_in: dset_str): H5DataSet =
  # convenience proc to return the dataset with name dset_name
  # if it does not exist, KeyError is thrown
  # inputs:
  #    h5f: H5FileObj = the file object from which to get the dset
  #    obj_name: string = name of the dset to get
  # outputs:
  #    H5DataSet = if dataset is found
  # throws:
  #    KeyError: if dataset could not be found
  # let exists = hasKey(h5f.datasets, dset_name)
  # if exists == true:
  #   result = h5f.datasets[dset_name]
  # else:
  #   discard
  var status: cint
  
  let dset_name = string(dset_in)
  let dset_exist = hasKey(h5f.datasets, dset_name)
  var result = newH5DataSet(dset_name)
  if dset_exist == false:
    # before we raise an exception, because the dataset does not yet exist,
    # check whether such a dataset exists in the file we're not aware of yet
    echo "file id is ", h5f.file_id
    echo "name is ", result.name
    let exists = existsInFile(h5f.file_id, result.name)
    if exists > 0:
      result.dataset_id   = H5Dopen2(h5f.file_id, result.name, H5P_DEFAULT)
      result.dataspace_id = H5Dget_space(result.dataset_id)
      # does exist, add to H5FileObj
      echo result.dataset_id
      let datatype_id = H5Dget_type(result.dataset_id)
      let f = h5ToNimType(datatype_id)
      result.dtype = strip($f, chars = {'a', 'k'}).toLowerAscii
      result.dtypeAnyKind = f
      result.dtype_c = H5Tget_native_type(datatype_id, H5T_DIR_ASCEND)

      echo H5Tget_class(datatype_id)
      
      # get the shape of the dataset
      let ndims = H5Sget_simple_extent_ndims(result.dataspace_id)
      # given ndims, create a seq in which to store the dimensions of
      # the dataset
      var shapes = newSeq[hsize_t](ndims)
      var max_sizes = newSeq[hsize_t](ndims)
      let s = H5Sget_simple_extent_dims(result.dataspace_id, addr(shapes[0]), addr(max_sizes[0]))
      echo "dimensions seem to be ", shapes
      result.shape = mapIt(shapes, int(it))

      # still need to determine the parents of the dataset
      result.parent = getParent(result.name)      
      var parent = create_group(h5f, result.parent)
      result.parent_id = getH5Id(parent)
      parent.datasets[result.name] = result

      result.file = h5f.name

      # need to close the datatype again, otherwise cause resource leak
      status = H5Tclose(datatype_id)
      if status < 0:
        echo "Status of H5Tclose() returned non-negative value. H5 will probably complain now..."
      
      h5f.datasets[result.name] = result
    else:
      raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
  else:
    result = h5f.datasets[dset_name]
  result

template get(h5f: H5FileObj, group_in: grp_str): H5Group =
  # convenience proc to return the group with name group_name
  # if it does not exist, KeyError is thrown
  # inputs:
  #    h5f: H5FileObj = the file object from which to get the dset
  #    obj_name: string = name of the dset to get
  # outputs:
  #    H5Group = if group is found
  # throws:
  #    KeyError: if group could not be found
  # let exists = hasKey(h5f.groups, group_name)
  # if exists == true:
  #   result = h5f.groups[group_name]
  # else:
  #   discard
  let group_name = string(group_in)  
  let group_exist = hasKey(h5f.groups, group_name)
  var result: H5Group
  if group_exist == false:
    raise newException(KeyError, "Group with name: " & group_name & " not found in file " & h5f.name)
  else:
    result = h5f.groups[group_name][]
  result    

proc nameExistingObjectOrParent(h5f: H5FileObj, name: string): string =
  # this procedure can be used to get the name of the given object
  # or its first existing parent
  # inputs:
  #    h5f: H5FileObj = the file object in which to check the tables
  #    name: string = name of the object to check for
  # outputs:
  #    string = the name of the given object (if it exists), or the
  #          name of the first existing parent. If root is the only
  #          existing object, empty string is returned
  let dset = hasKey(h5f.datasets, name)
  if dset == false:
    let group = hasKey(h5f.groups, name)
    if group == false:
      # in this case object does not yet exist, search up hierarchy from
      # name for existing parent
      let p = firstExistingParent(h5f, name)
      if isSome(p) == true:
        # in this case return the name
        result = unsafeGet(p).name
      else:
        # else return empty string, nothing found in file object
        result = ""

template isGroup(h5_object: typed): bool =
  # procedure to check whether object is a H5Group
  result: bool = false
  if h5_object is H5Group:
    result = true
  else:
    result = false
  result

template isDataSet(h5_object: typed): bool =
  # procedure to check whether object is a H5DataSet
  result: bool = false
  if h5_object is H5DataSet:
    result = true
  else:
    result = false
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
  
proc H5file*(name, rw_type: string): H5FileObj = #{.raises = [IOError].} =
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
      raise newException(IOError, getH5read_non_exist_file())
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

proc close*(h5f: H5FileObj): herr_t =
  # this procedure closes all known datasets, dataspaces, groups and the HDF5 file
  # itself to clean up
  # inputs:
  #    h5f: H5FileObj = file object which to close
  # outputs:
  #    hid_t = status of the closing of the file

  for dset, id in pairs(h5f.datasets):
    #echo("Closing dset ", dset, " with id ", id)
    result = H5Dclose(id.dataset_id)
    result = H5Sclose(id.dataspace_id)

  for group, id in pairs(h5f.groups):
    #echo("Closing group ", group, " with id ", id)
    result = H5Gclose(id.group_id)
  
  result = H5Fclose(h5f.file_id)


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
    # enter the shape in reverse order, since H5 expects data in other notation
    # as we do in Nim
    #result[^(count + 1)] = hsize_t(el)
    result[count] = hsize_t(el)    
    inc count

proc formatName(name: string): string =
  # this procedure formats a given group / dataset namy by prepending
  # a potenatially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  result = "/" & strip(name, chars = ({'/'} + Whitespace + NewLines))

proc createGroupFromParent[T](h5f: var T, group_name: string): H5Group =
  # procedure to create a group within a H5F
  # Note: this procedure requires that the parent of the group
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
    let parent = h5f.groups[p_str][]
    location_id = getH5Id(parent)
  else:
    # the group will be created in the root of the file
    location_id = h5f.file_id

  result = newH5Group(group_name)[]
  # before we create a greoup, check whether said group exists in the H5 file
  # already
  echo "Checking for existence of group ", result.name, " ", group_name

  let exists = location_id.existsInFile(result.name)
  if exists > 0:
    # group exists, open it
    result.group_id = H5Gopen2(location_id, result.name, H5P_DEFAULT)
    echo "Group exists H5Gopen2() returned id ", result.group_id    
  elif exists == 0:
    echo "Group non existant, creating group ", result.name
    # group non existant, create
    result.group_id = H5Gcreate2(location_id, result.name, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  else:
    echo "create_group(): You probably see the HDF5 errors piling up..."
  result.parent = p_str
  # since we know that the parent exists, we can simply use the (recursive!) getParentId
  # to get the id of the parent, without worrying about receiving a parent id of an
  # object, which is in reality not a parent
  result.parent_id = getParentId(h5f, result)
  when h5f is H5FileObj:
    result.file = h5f.name
  elif h5f is H5Group:
    result.file = h5f.file

  result.file_id = h5f.file_id
  # now that we have created the group fully (including IDs), we can add it
  # to the H5FileObj
  var grp = new H5Group
  grp[] = result
  echo "Adding element to h5f groups ", group_name
  #echo "h5f before ", h5f.groups
  h5f.groups[group_name] = grp
  #echo "h5f after ", h5f.groups
  grp.groups = h5f.groups
  
  
proc create_group*[T](h5f: var T, group_name: string): H5Group =
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

  when h5f is H5Group:
    # in this case need to modify the path of the group from a relative path to an
    # absolute path in the H5 file
    var group_path: string
    if h5f.name notin group_name and group_name notin h5f.name:
      group_path = joinPath(h5f.name, group_name)
    else:
      group_path = group_name
    echo "Group path is now ", group_path, " ", h5f.name
  else:
    let group_path = group_name
  
  let exists = hasKey(h5f.groups, group_path)
  if exists == true:
    # then we return the object
    result = h5f.groups[group_path][]
  else:
    # we need to create it. But first check whether the parent
    # group already exists
    # whether such a group already exists
    # in the HDF5 file and h5f is simply not aware of it yet
    if isInH5Root(group_path) == false:
      let parent = create_group(h5f, getParent(group_path))
      result = createGroupFromParent(h5f, group_path)
    else:
      result = createGroupFromParent(h5f, group_path)

proc create_dataset*[T: tuple](h5f: var H5FileObj, dset_raw: string, shape: T, dtype: typedesc): H5DataSet =
  ## procedure to create a dataset given a H5file object. The shape of
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
  let dtype_c = nimToH5type(dtype)

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
  dset.parent_id = getParentId(h5f, dset)
  
  # dset.parent_id = h5f.file_id
  dset.shape = map(shape_seq, (x: hsize_t) -> int => int(x))
  echo dset.shape, " ", shape_seq
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
      # in this case open the dataset to read
      dset.dataset_id   = H5Dopen2(h5f.file_id, dset.name, H5P_DEFAULT)
      dset.dataspace_id = H5Dget_space(dset.dataset_id)
      # TODO: include a check about whether the opened dataset actually conforms
      # to what we wanted to create (e.g. same shape etc.)
      
    elif dset.dataset_id == 0:
      # does not exist
      # now
      echo "Does not exist, so create dataspace ", dset.name, " with shape ", shape_seq
      let dataspace_id = H5Screate_simple(cint(len(shape_seq)), addr(shape_seq[0]), nil)
      
      # using H5Dcreate2, try to create the dataset
      echo "Does not exist, so create dataset via H5create2 ", dset.name                
      let dataset_id = H5Dcreate2(h5f.file_id, dset_name, dtype_c, dataspace_id,
                                  H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)

      dset.dataspace_id = dataspace_id
      dset.dataset_id = dataset_id
    else:
      echo "create_dataset(): You probably see the HDF5 errors piling up..."
  

  
  h5f.datasets[dset_name] = dset
  # redundant:
  h5f.dataspaces[dset_name] = dset.dataspace_id
  #dataset_id = H5Dcreate2(h5f.file_id, "/dset", H5T_STD_I32BE, dataspace_id, 

  result = dset


  
# template check_shape(shape: seq[int], data: openArray[T]): bool =
#   if data is seq or data is array:
#     let d

template getIndexSeq(ind: int, shape: seq[int]): seq[int] =
  # given an index for a 1D array (flattened from nD), calculate back
  # the indices of that index in terms of N dimensions
  # e.g. if shape is [2, 4, 10] and index ind == 54:
  # returns a seq of: @[1, 1, 4], because:
  # x = 1
  # y = 1
  # z = 4
  # => ind = x + y * 10 + z * 4 * 10
  let dim = foldl(shape, a * b)
  let n_dims = len(shape)
  var result = newSeq[int](n_dims)
  var
    # set our remaining variable to ind as the start
    rem = ind
    # variable for dimensionality, starting by 1, multiplying with each j in shape
    d = 1
  for i, j in shape:
    # multiply with current dimensionality
    d *= j
    # given remainder, get the current index by dividing out the rest of the
    # dimensionality 
    result[i] = rem div int(dim / d)
    rem = rem mod int(dim / d)
  result

macro test_access(x: typed): untyped =
  result = newStmtList()
  echo treeRepr(x)
  echo treeRepr(result)
  for el in x:
    echo el
  
proc getValueFromArrayByIndexTuple[T](x: openArray[T], inds: seq[int]): float64 =
  dumpTree:
    result = x[inds[0]][inds[1]]
    x
  test_access(x)


# proc flatten*[T](x: openArray[T], shape: seq[int], dtype: typedesc): seq[dtype] = 
#   # procedure to flatten a nested sequence or array
#   let dim = foldl(shape, a * b)
#   result = newSeq[dtype](dim)
#   var remain = dim
#   for i in 0..<dim:
#     # calculate current tuple of indices
#     let inds = getIndexSeq(i, shape)
#     # and access correct element using seq accessing; need to reinvent access of seqs...
#     # for k in inds:
#     #   x[k] = 
    
#     result[i] = getValueFromArrayByIndexTuple(x, inds)
#     echo "result i is now ", result[i]

# var x = seq[seq[seq[float]]]

# var x_1: seq[seq[float]]
# for el in x:
#   ## el == seq[seq[float]]
#   x_1 = concat(x_1, el)

# var x_2 = seq[float]  
# for el in x_1:
#   x_2 = concat(x_2, el)


# [ [ [1, 2, 3], [1, 2, 3], [1, 2, 3] ],
#   [ [1, x, 3], [1, 2, 3], [1, 2, 3] ],
#   [ [1, 2, 3], [1, 2, 3], [1, 2, 3] ] ]


# x = (1 / 0 / 1)

proc shape[T: SomeNumber](x: T): seq[int] = @[]
  # Exists so that recursive template stops with this proc.

proc shape*[T](x: seq[T]): seq[int] =
  # recursively determine the dimension of a nested sequence.
  # we simply append the dimension of the current seq to the
  # result and call this function again recursively until
  # we hit the type at core, which is catched by the above proc
  result = @[]
  if len(x) > 0:
    result.add(len(x))
    result.add(shape(x[0]))

proc flatten[T: SomeNumber](a: seq[T]): seq[T] = a
proc flatten*[T: seq](a: seq[T]): auto =  a.concat.flatten
    
proc `[]=`*[T](dset: var H5DataSet, ind: DsetReadWrite, data: seq[T]) = #openArray[T])  
  # procedure to write a sequence of array to a dataset
  # will be given to HDF5 library upon call, H5DataSet object
  # does not store the data
  # inputs:
  #    dset: var H5DataSet = the dataset which contains the necessary information
  #         about dataset shape, dtype etc. to write to
  #    ind: DsetReadWrite = indicator telling us to write whole dataset,
  #         used to differentiate from the case in which we only write a hyperslab    
  #    data: openArray[T] = any array type containing the data to be written
  #         needs to be of the same size as the shape given during creation of
  #         the dataset or smaller
  # throws:
  #    ValueError: if the shape of the input dataset is different from the reserved
  #         size of the dataspace on which we wish to write in the H5 file
  #         TODO: create an appropriate Exception for this case!

  # TODO: IMPORTANT: think about whether we should be using array types instead
  # of a dataspace of certain dimensions for arrays / nested seqs we're handed
  
  if ind == RW_ALL:
    let shape = dset.shape
    echo "shape is ", shape
    echo "shape is a ", type(shape).name, " and data is a ", type(data).name, " and data.shape = "
    if data.shape == dset.shape:
      var data_write = flatten(data) 
      discard H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                       addr(data_write[0]))
    else:
      var msg = """
Wrong input shape of data to write in `[]=`. Given shape `$#`, dataspace has shape `$#`"""
      msg = msg % [$data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    echo "Dataset not assigned anything, ind: DsetReadWrite invalid"

proc `[]=`*[T](dset: var H5DataSet, inds: HSlice[int, int], data: var seq[T]) = #openArray[T])  
  # procedure to write a sequence of array to a dataset
  # will be given to HDF5 library upon call, H5DataSet object
  # does not store the data
  # inputs:
  #    dset: var H5DataSet = the dataset which contains the necessary information
  #         about dataset shape, dtype etc. to write to
  #    inds: HSlice[int, int] = slice of a range, which to write in dataset
  #    data: openArray[T] = any array type containing the data to be written
  #         needs to be of the same size as the shape given during creation of
  #         the dataset or smaller

  # only write slice of dset by using hyperslabs

  # TODO: change this function to do what it's supposed to!
  if dset.shape == data.shape:
    #var ten = data.toTensor()
    # in this case run over all dimensions and flatten arrayA
    echo "shape before is ", data.shape
    echo data
    var data_write = flatten(data) 
    discard H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                     addr(data_write[0]))
  else:
    echo "All bad , shapes are ", data.shape, " ", dset.shape


# proc buildType[T](shape: seq[int], ind: int, t: T): seq[T] =
#   dumpTree:
#     shape
#   if ind < 10:
#     let v = newSeq[type(t)](1)
#     let tt = buildType(shape, ind + 1, v)
#     result = newSeq[type(tt)](1)
#   else:
#     result = newSeq[type(t)](1)

# proc newSeqOfNest1[T](tmp: T): seq[seq[T]] =
#   result = newSeq[seq[seq[T]]](0)

# proc newSeqOfNest2[T](tmp: T): seq[seq[seq[T]]] =
#   result = newSeq[seq[seq[seq[T]]]](0)
  
# proc newSeqOfNest3[T](tmp: T): seq[seq[seq[seq[T]]]] =
#   result = newSeq[seq[seq[seq[seq[T]]]]](0)

# template newSeqOfNest[T](shape: seq[int], tmp: T): typed =
#   case len(shape)
#   of 1:
#     for i in 0..<1:
#       newSeq[T](shape[i])
#   of 2:
#     var result = newSeq[seq[seq[T]]](0)    
#     for i in 0..<1:
#       newSeq[T](shape[i])    

#   of 3:
#     newSeq[seq[seq[seq[T]]]](0)
#   of 4:
#     newSeq[seq[seq[seq[seq[T]]]]](0)
  
# proc getTypeOfSeq(shape: seq[int]): auto =
#   if len(shape) > 1:
#     result = type(
    
# proc newSeqOfShape(shape: seq[int], dtype: typedesc): auto =
#   # procedure to create a new (nested) sequence of
#   # a given shape
#   for dim in shape:
#     let t = type(getTypeOfSeq(shape[1:]))
#     var d = newSeq[](dim)
#     echo d

# proc build(typestr: string): auto =
#   result = nnkTypeSection(parseStmt(typestr))

# template test(s: AnyKind): untyped {.dirty.} =
#   if s == akFloat64:
#     return type(float64)#type(4.4)
#   else:
#     return type(int64)

template getSeq(t: untyped, data: untyped): untyped =
  when t is float64:
    data = newSeq[float64](n_elements)
  elif t is int64:
    data = newSeq[int64](n_elements)
  else:
    discard
  data

template withDset*(h5dset: H5DataSet, actions: untyped) =
  # convenience template to read a dataset from the file and perform actions
  # with that dataset, without having to manually check the data type of the
  # dataset
  case h5dset.dtypeAnyKind
  of akBool:
    let dset {.inject.} = h5dset[bool]
    actions
  of akChar:
    let dset {.inject.} = h5dset[char]
    actions
  of akString:
    let dset {.inject.} = h5dset[string]
    actions
  of akFloat32:
    let dset {.inject.} = h5dset[float32]
    actions
  of akFloat64:
    let dset {.inject.} = h5dset[float64]
    actions
  of akInt8:
    let dset {.inject.} = h5dset[int8]
    actions
  of akInt16:
    let dset {.inject.} = h5dset[int16]
    actions
  of akInt32:
    let dset {.inject.} = h5dset[int32]
    actions
  of akInt64:
    let dset {.inject.} = h5dset[int64]
    actions
  of akUint8:
    let dset {.inject.} = h5dset[uint8]
    actions
  of akUint16:
    let dset {.inject.} = h5dset[uint16]
    actions
  of akUint32:
    let dset {.inject.} = h5dset[uint32]
    actions
  of akUint64:
    let dset {.inject.} = h5dset[uint64]
    actions    
  else:
    echo "it's of type ", h5dset.dtypeAnyKind
    discard


proc `[]`*[T](dset: var H5DataSet, t: typedesc[T]): seq[T] =
  # procedure to read the data of an existing dataset into 
  # inputs:
  #    dset: var H5DataSet = the dataset which contains the necessary information
  #         about dataset shape, dtype etc. to read from
  #    ind: DsetReadWrite = indicator telling us to read whole dataset,
  #         used to differentiate from the case in which we only read a hyperslab
  # outputs:
  #    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  #         dataset
  #         TODO: return the correct data shape!
  # throws:
  #     ValueError: in case the given typedesc t is different than
  #         the datatype of the dataset
  if $t != dset.dtype:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given `$#`, dset is `$#`" % [$t, $dset.dtype])

  let
    shape = dset.shape
    n_elements = foldl(shape, a * b)
  # create a flat sequence of the size of the dataset in the H5 file, then read data
  # cannot use the result sequence, since we need to hand the address of the sequence to
  # the H5 library
  var data = newSeq[T](n_elements)
  discard H5Dread(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                  addr(data[0]))
  result = data

template `[]`*(h5f: H5FileObj, name: dset_str): H5DataSet =
  # a simple wrapper around get for datasets
  h5f.get(name)

template `[]`*(h5f: H5FileObj, name: grp_str): H5Group =
  # a simple wrapper around get for groups
  h5f.get(name)

