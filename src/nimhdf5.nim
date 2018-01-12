import tables
import os,ospaths
import typeinfo
import typetraits
import sequtils
import strutils
import options
import future
import algorithm
#import seqmath
import macros

# TODO: fix requirement of arraymancer!
import arraymancer

import nimhdf5/hdf5_wrapper
include nimhdf5/H5nimtypes

# simple list of TODOs
# TODO:
#  - CHECK: does opening an dataset in a file, and trying to write a larger
#    dataset to it than the one currently in the file work? Does not seem to
#    be the case, but I didn't t see any errors either?!
#  - add iterators for attributes, groups etc..!
#  - add ability to read / write hyperslabs
#  - add ability to write arraymancer.Tensor
#  - add a lot of safety checks
#  - CLEAN UP and refactor the code! way too long in a single file by now...


type
  # these distinct types provide the ability to distinguish the `[]` function
  # acting on H5FileObj between a dataset and a group, s.t. we can access groups
  # as well as datasets from the object using `[]`. Typecast the name (as a string) 
  # of the object to either of the two types (you have to know the type of the
  # dset / group you want to access of course!)
  grp_str*  = distinct string
  dset_str* = distinct string

  #special_vlen = hid_t
  #special_str  = hid_t

  # an enum, which is used for the `[]=` functions of H5DataSets. By handing
  # RW_ALL as the argument to said function, we declare to write all data contained
  # in the object on the RHS of the `=`
  DsetReadWrite = enum
    RW_ALL

  H5Object = object of RootObj
    name*: string
    parent*: string
    parent_id*: hid_t

  # object which stores information about the attributes of a H5 object
  # each dataset, group etc. has a field .attr, which contains a H5Attributes
  # object
  H5Attributes* = object
    # attr_tab is a table containing names and corresponding
    # H5 info
    attr_tab*: Table[string, H5Attr]
    num_attrs: int
    parent_name: string
    parent_id: hid_t
    parent_type: string

  # a tuple which stores information about a single attribute
  H5Attr = tuple[
    attr_id: hid_t,
    dtype_c: hid_t,
    dtypeAnyKind: AnyKind,
    # BaseKind contains the type within a (nested) seq iff
    # dtypeAnyKind is akSequence
    dtypeBaseKind: AnyKind,
    attr_dspace_id: hid_t]

  # an object to store information about a hdf5 dataset. It is a combination of
  # an HDF5 dataspace and dataset id (contains both of them)
  H5DataSet* = object #of H5Object
    name*: string
    # we store the shape information internally as a seq, so that we do
    # not have to know about it at compile time
    shape*: seq[int]
    # maxshape stores the maximum size of each dimension the dataset can have,
    # if empty sequence or one dimension set to `int.high`, unlimited size
    maxshape*: seq[int]
    # if chunking is used, stores the size of a chunk, same shape as `shape`, e.g.
    # if shape is @[1000, 1000], chunksize may be @[100, 100]
    chunksize*: seq[int]
    # descriptor of datatype as string of the Nim type
    dtype*: string
    dtypeAnyKind*: AnyKind
    # actual HDF5 datatype used as a hid_t, this can be handed to functions needing
    # its datatype
    dtype_c*: hid_t
    # H5 datatype class, useful to check what kind of data we're dealing with (VLEN etc.)
    dtype_class: H5T_class_t
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
    # attr stores information about attributes
    attrs*: H5Attributes
    # property list identifiers, which stores information like "is chunked storage" etc.
    # here we store H5P_DATASET_ACCESS property list 
    dapl_id*: hid_t
    # here we store H5P_DATASET_CREATE property list 
    dcpl_id*: hid_t

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
    # attr stores information about attributes
    attrs*: H5Attributes
    # property list identifier, which stores information like "is chunked storage" etc.
    # here we store H5P_GROUP_ACCESS property list 
    gapl_id*: hid_t
    # here we store H5P_GROUP_CREATE property list 
    gcpl_id*: hid_t

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
    # attr stores information about attributes
    attrs*: H5Attributes
    # property list identifier, which stores information like "is chunked storage" etc.
    # here we store H5P_FILE_ACCESS property list    
    fapl_id*: hid_t
    # here we store H5P_FILE_CREATE property list    
    fcpl_id*: hid_t

  # this exception is used in cases where all conditional cases are already thought
  # to be covered to annotate (hopefully!) unreachable branches
  UnkownError* = object of Exception
  # raised if a call to a HDF5 library function returned with an error
  # (typically result < 0 means error)
  HDF5LibraryError* = object of Exception
  # raised if the user tries to change the size of an immutable dataset, i.e. non-chunked storage
  ImmutableDatasetError* = object of Exception

const    
    H5_NOFILE = hid_t(-1)
    H5_OPENFILE = hid_t(1)

# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW    = cuint(0x00FF)

template withDebug(actions: untyped) =
  when defined(DEBUG_HDF5):
    actions


# forward declare procs, which we need to read the attributes from file
proc read_all_attributes(h5attr: var H5Attributes)
proc h5ToNimType(dtype_id: hid_t): AnyKind

proc newH5Attributes(): H5Attributes =
  let attr = initTable[string, H5Attr]()  
  result = H5Attributes(attr_tab: attr,
                        num_attrs: -1,
                        parent_name: "",
                        parent_id: -1,
                        parent_type: "")

proc initH5Attributes(p_name: string = "", p_id: hid_t = -1, p_type: string = ""): H5Attributes =
  let attr = initTable[string, H5Attr]()
  var h5attr = H5Attributes(attr_tab: attr,
                            num_attrs: -1,
                            parent_name: p_name,
                            parent_id: p_id,
                            parent_type: p_type)
  read_all_attributes(h5attr)
  result = h5attr

    

proc newH5File*(): H5FileObj =
  ## default constructor for a H5File object, for internal use
  let dset = initTable[string, H5DataSet]()
  let dspace = initTable[string, hid_t]()
  let groups = newTable[string, ref H5Group]()
  let attrs = newH5Attributes()
  result = H5FileObj(name: "",
                     file_id: H5_NOFILE,
                     rw_type: H5F_INVALID_RW,
                     err: -1,
                     status: -1,
                     datasets: dset,
                     dataspaces: dspace,
                     groups: groups,
                     attrs: attrs)


proc newH5DataSet*(name: string = ""): H5DataSet =
  ## default constructor for a H5File object, for internal use
  let shape: seq[int] = @[]
  let attrs = newH5Attributes()  
  result = H5DataSet(name: name,
                     shape: shape,
                     dtype: nil,
                     dtype_c: -1,
                     parent: "",
                     file: "",
                     dataspace_id: -1,
                     dataset_id: -1,
                     all: RW_ALL,
                     attrs: attrs)

proc newH5Group*(name: string = ""): ref H5Group =
  ## default constructor for a H5Group object, for internal use
  let datasets = initTable[string, H5DataSet]()
  let groups = newTable[string, ref H5Group]()
  let attrs = newH5Attributes()  
  result = new H5Group
  result.name = name
  result.parent = ""
  result.parent_id = -1
  result.file = ""
  result.datasets = datasets
  result.groups = groups
  result.attrs = attrs

proc openAttrByIdx(h5attr: var H5Attributes, idx: int): hid_t =
  # proc to open an attribute by its id in the H5 file and returns
  # attribute id if succesful
  # need to hand H5Aopen_by_idx the location relative to the location_id,
  # if I understand correctly
  let loc = "."
  # we read by creation order, increasing from 0
  result = H5Aopen_by_idx(h5attr.parent_id,
                          loc,
                          H5_INDEX_CRT_ORDER,
                          H5_ITER_INC,
                          hsize_t(idx),
                          H5P_DEFAULT,
                          H5P_DEFAULT)

proc getAttrName(attr_id: hid_t, buf_space = 20): string =
  # proc to get the attribute name of the attribute with the given id
  # reserves space for the name to be written to
  withDebug:
    echo "Call to getAttrName! with size $#" % $buf_space
  var name = newString(buf_space)
  # read the name
  let length = attr_id.H5Aget_name(len(name), name)
  # H5Aget_name returns the length of the name. In case the name
  # is longer than the given buffer, we call this function again with
  # a buffer with the correct length
  if length <= name.len:
    result = name.strip
    # now set the length of the resulting string to the size
    # it actually occupies
    result.setLen(length)
  else:
    result = getAttrName(attr_id, length)

proc getNumAttrs(h5attr: var H5Attributes): int =
  # proc to get the number of attributes of the parent
  # uses H5Oget_info, which returns a struct containing the
  # metadata of the object (incl type etc.). Might be useful
  # at other places too?
  # reserve space for the info object
  var h5info: H5O_info_t
  echo h5attr.parent_id
  let err = H5Oget_info(h5attr.parent_id, addr(h5info))
  if err >= 0:
    # successful
    withDebug:
      echo "getNumAttrs(): ", h5attr
    var status: hid_t
    var loc = cstring(".")
    result = int(h5info.num_attrs)
  else:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getNumAttr` when reading $#" % $h5attr.parent_name)

proc setAttrAnyKind(attr: var H5Attr) =
  # proc which sets the AnyKind fields of a H5Attr
  let npoints = H5Sget_simple_extent_npoints(attr.attr_dspace_id)
  if npoints > 1:
    attr.dtypeAnyKind = akSequence
    # set the base type based on what's contained in the sequence
    attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
  else:
    attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)

proc read_all_attributes(h5attr: var H5Attributes) =
  # proc to read all attributes of the parent from file and store the names
  # and attribute ids in `h5attr`

  # first get how many objects there are
  h5attr.num_attrs = h5attr.getNumAttrs
  for i in 0..<h5attr.num_attrs:
    var attr: H5Attr
    let idx = hsize_t(i)
    attr.attr_id = openAttrByIdx(h5attr, i)
    let name = getAttrName(attr.attr_id)
    withDebug:
      echo "Found? ", attr.attr_id, " with name ", name
    # get dtypes and dataspace id
    attr.dtype_c = H5Aget_type(attr.attr_id)
    attr.attr_dspace_id = H5Aget_space(attr.attr_id)
    # now set the attribute any kind fields (checks whether attr is a sequence)
    setAttrAnyKind(attr)
    # add to this attribute object
    h5attr.attr_tab[name] = attr

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
  
  # TODO: we may can seperate the dtypes by class using H5Tget_class, which returns a value
  # of the H5T_class_t enum (e.g. H5T_FLOAT)
  withDebug:
    echo "dtype is ", dtype_id
    echo "native is ", H5Tget_native_type(dtype_id, H5T_DIR_ASCEND)
  # TODO: make sure the types are correctly identified!
  # MAKING PROBLEMS ALREADY! int64 is read back as a NATIVE_LONG, which thus needs to be
  # converted to int64

  if H5Tequal(H5T_NATIVE_DOUBLE, dtype_id) == 1:
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
  elif H5Tget_class(dtype_id) == H5T_STRING:
    result = akString
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
  elif dtype is string:
    # NOTE: in case a string is desired, we still have to prepare it later, because
    # a normal string will end up as a sequence of characters otherwise. Instead
    # to get a continous string, need to set the size of the individual string
    # datatype (the result of this), to the size of the string and instead set
    # the size of the dataspace we reserve back to 1!
    # Also we need to copy the datatype, in order to be able to change its size
    # later
    result_type = H5Tcopy(H5T_C_S1)
    # -> call string_dataspace(str: string, dtype: hid_t) with
    # `result_type` as the second argument and the string you wish to
    # write as 1st after the call to this fn    
  result_type

template special_type*(dtype: typedesc): untyped =
  # calls the H5Tvlen_create() to create a special datatype
  # for variable length data
  when dtype isnot string:
    H5Tvlen_create(nimToH5type(dtype))
  else:
    echo "Currently not implemented to create variable string datatype" 

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

proc existsAttribute(h5id: hid_t, name: string): bool =
  # proc to check whether a given
  # simply check if the given attribute name corresponds to an attribute
  # of the given object
  # throws:
  #    
  let exists = H5Aexists(h5id, name)
  if exists > 0:
    result = true
  elif exists == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "HDF5 library called returned bad value in `existsAttribute` function")

template existsAttribute[T: (H5FileObj | H5Group | H5DataSet)](h5o: T, name: string): bool =
  # proc to check whether a given
  # simply check if the given attribute name corresponds to an attribute
  # of the given object
  existsAttribute(h5o.getH5Id, name)

proc deleteAttribute(h5id: hid_t, name: string): bool =
  withDebug:
    echo "Deleting attribute $# on id $#" % [name, $h5id]
  let success = H5Adelete(h5id, name)
  result = if success >= 0: true else: false

template deleteAttribute[T: (H5FileObj | H5Group | H5DataSet)](h5o: T, name: string): bool =  
  deleteAttribute(h5o.getH5Id, name)

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
    #TODO: replace by exception
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
  let dset_exist = hasKey(h5f.datasets, dset_name)
  if dset_exist == false:
    #raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
    result = none(H5DataSet)
  else:
    result = some(h5f.datasets[dset_name])

proc getGroup(h5f: H5FileObj, grp_name: string): Option[H5Group] =
  ## convenience proc to return the group with name grp_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5FileObj = the file object from which to get the group
  ##    obj_name: string = name of the group to get
  ## outputs:
  ##    H5Group = if group is found
  ## throws:
  ##    KeyError: if group could not be found
  let grp_exist = hasKey(h5f.datasets, grp_name)
  if grp_exist == false:
    #raise newException(KeyError, "Dataset with name: " & grp_name & " not found in file " & h5f.name)
    result = none(H5Group)
  else:
    result = some(h5f.groups[grp_name][])


template readDsetShape(dspace_id: hid_t): seq[int] =
  # get the shape of the dataset
  var result: seq[int] = @[]
  let ndims = H5Sget_simple_extent_ndims(dspace_id)
  # given ndims, create a seq in which to store the dimensions of
  # the dataset
  var shapes = newSeq[hsize_t](ndims)
  var max_sizes = newSeq[hsize_t](ndims)
  let s = H5Sget_simple_extent_dims(dspace_id, addr(shapes[0]), addr(max_sizes[0]))
  withDebug:
    echo "dimensions seem to be ", shapes
  result = mapIt(shapes, int(it))
  result
    
template get(h5f: var H5FileObj, dset_in: dset_str): H5DataSet =
  ## convenience proc to return the dataset with name dset_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5FileObj = the file object from which to get the dset
  ##    obj_name: string = name of the dset to get
  ## outputs:
  ##    H5DataSet = if dataset is found
  ## throws:
  ##    KeyError: if dataset could not be found
  var status: cint
  
  let dset_name = string(dset_in)
  let dset_exist = hasKey(h5f.datasets, dset_name)
  var result = newH5DataSet(dset_name)
  if dset_exist == false:
    # before we raise an exception, because the dataset does not yet exist,
    # check whether such a dataset exists in the file we're not aware of yet
    withDebug:
      echo "file id is ", h5f.file_id
      echo "name is ", result.name
    let exists = existsInFile(h5f.file_id, result.name)
    if exists > 0:
      result.dataset_id   = H5Dopen2(h5f.file_id, result.name, H5P_DEFAULT)
      result.dataspace_id = H5Dget_space(result.dataset_id)
      # does exist, add to H5FileObj
      let datatype_id = H5Dget_type(result.dataset_id)
      let f = h5ToNimType(datatype_id)
      result.dtype = strip($f, chars = {'a', 'k'}).toLowerAscii
      result.dtypeAnyKind = f
      result.dtype_c = H5Tget_native_type(datatype_id, H5T_DIR_ASCEND)
      result.dtype_class = H5Tget_class(datatype_id)

      # get the dataset access property list 
      result.dapl_id = H5Dget_access_plist(result.dataset_id)
      # get the dataset create property list
      result.dapl_id = H5Dget_create_plist(result.dataset_id)
      withDebug:
        echo "ACCESS PROPERTY LIST IS ", result.dapl_id
        echo "CREATE PROPERTY LIST IS ", result.dapl_id      
        echo H5Tget_class(datatype_id)

        
      result.shape = readDsetShape(result.dataspace_id)
      # still need to determine the parents of the dataset
      result.parent = getParent(result.name)      
      var parent = create_group(h5f, result.parent)
      result.parent_id = getH5Id(parent)
      parent.datasets[result.name] = result

      result.file = h5f.name

      # create attributes field
      result.attrs = initH5Attributes(result.name, result.dataset_id, "H5DataSet")

      # need to close the datatype again, otherwise cause resource leak
      status = H5Tclose(datatype_id)
      if status < 0:
        #TODO: replace by exception
        echo "Status of H5Tclose() returned non-negative value. H5 will probably complain now..."
      
      h5f.datasets[result.name] = result
    else:
      raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
  else:
    result = h5f.datasets[dset_name]
    # in this case we still need to update e.g. shape
    # TODO: think about what else we might have to update!
    result.dataspace_id = H5Dget_space(result.dataset_id)
    result.shape = readDsetShape(result.dataspace_id)
  result

template get(h5f: H5FileObj, group_in: grp_str): H5Group =
  ## convenience proc to return the group with name group_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5FileObj = the file object from which to get the dset
  ##    obj_name: string = name of the dset to get
  ## outputs:
  ##    H5Group = if group is found
  ## throws:
  ##    KeyError: if group could not be found
  let
    group_name = string(group_in)  
    group_exist = hasKey(h5f.groups, group_name)
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
      withDebug:
        echo "exists and read only"
      result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
    else:
      # cannot open a non existing file with read only properties
      raise newException(IOError, getH5read_non_exist_file())
  elif rw == H5F_ACC_RDWR:
    # check whether file exists already
    # then use open call
    withDebug:
      echo "exists and read write"      
    result.file_id = H5Fopen(name, rw, H5P_DEFAULT)
  elif rw == H5F_ACC_EXCL:
    # use create call
    withDebug:
      echo "rw is  ", rw
    result.file_id = H5Fcreate(name, rw, H5P_DEFAULT, H5P_DEFAULT)
  # after having opened / created the given file, we get the datasets etc.
  # which are stored in the file
  result.attrs = initH5Attributes("/", result.file_id, "H5FileObj")

proc close*(h5f: H5FileObj): herr_t =
  # this procedure closes all known datasets, dataspaces, groups and the HDF5 file
  # itself to clean up
  # inputs:
  #    h5f: H5FileObj = file object which to close
  # outputs:
  #    hid_t = status of the closing of the file

  # TODO: can we use iterate and H5Oclose to close all this stuff
  # somewhat cleaner?

  for name, dset in pairs(h5f.datasets):
    withDebug:
      discard
      #echo("Closing dset ", name, " with dset ", dset)
    # close attributes
    for attr in values(dset.attrs.attr_tab):
      result = H5Aclose(attr.attr_id)
      result = H5Sclose(attr.attr_dspace_id)
    result = H5Dclose(dset.dataset_id)
    result = H5Sclose(dset.dataspace_id)

  for name, group in pairs(h5f.groups):
    withDebug:
      discard
      #echo("Closing group ", name, " with id ", group)
    # close attributes
    for attr in values(group.attrs.attr_tab):
      result = H5Aclose(attr.attr_id)
      result = H5Sclose(attr.attr_dspace_id)
    result = H5Gclose(group.group_id)

  # close attributes
  for attr in values(h5f.attrs.attr_tab):
    result = H5Aclose(attr.attr_id)
    result = H5Sclose(attr.attr_dspace_id)
  
  result = H5Fclose(h5f.file_id)

proc set_chunk(papl_id: hid_t, chunksize: seq[int]): hid_t =
  # proc to set chunksize of the given object, should be a dataset,
  # but we do not perform checks!
  var mchunksize = mapIt(chunksize, hsize_t(it))
  result = H5Pset_chunk(papl_id, cint(len(mchunksize)), addr(mchunksize[0]))

proc parseMaxShape(maxshape: seq[int]): seq[hsize_t] =
  # this proc parses the maxshape given to simple_dataspace by taking into
  # account the following rules:
  # @[] -> nil (meaning H5Screate_simple will interpret as same dimension as shape)
  # per dimension:
  # `int.high` -> H5S_UNLIMITED
  if maxshape.len == 0:
    result = nil
  else:
    result = mapIt(maxshape, if it == int.high: H5S_UNLIMITED else: hsize_t(it))
  

template simple_dataspace[T: (seq | int)](shape: T, maxshape: seq[int] = @[]): hid_t =
  # create a simple dataspace with max dimension == current_dimension
  # TODO: rewrite this
  var m_maxshape: seq[hsize_t] = parseMaxShape(maxshape)
  withDebug:
    echo "Creating memory dataspace of shape ", shape
  when T is seq:
    # convert ints to hsize_t (== culonglong) and create mutable copy (need
    # an address to hand it to C function as pointer)
    var mshape = mapIt(shape, hsize_t(it))
    if m_maxshape.len > 0:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), addr(m_maxshape[0]))
    else:
      H5Screate_simple(cint(len(mshape)), addr(mshape[0]), nil)
  elif T is int:
    # in this case 1D
    var mshape = hsize_t(shape)
    # maxshape is still a sequence, so take `0` element as address
    if m_maxshape.len > 0:
      H5Screate_simple(cint(1), addr(mshape), addr(m_maxshape[0]))
    else:
      H5Screate_simple(cint(1), addr(mshape), nil)

proc create_simple_memspace_1d[T](coord: seq[T]): hid_t {.inline.} =
  ## convenience proc to create a simple 1D memory space for N coordinates
  ## in memory
  # get enough space for the N coordinates in coord
  result = simple_dataspace(coord.len)

proc string_dataspace(str: string, dtype: hid_t): hid_t =
  # returns a dataspace of size 1 for a string of length N, by
  # changing the size of the datatype given
  discard H5Tset_size(dtype, len(str))
  # append null termination
  discard H5Tset_strpad(dtype, H5T_STR_NULLTERM)
  # now return dataspace of size 1
  result = simple_dataspace(1)

  
proc parseShapeTuple[T: tuple](dims: T): seq[int] =
  ## parses the shape tuple handed to create_dataset
  ## receives a tuple of one datatype, which was previously
  ## determined using getCtype()
  ## inputs:
  ##    dims: T = tuple of type T for which we need to allocate
  ##              space
  ## outputs:
  ##    seq[int] = seq of int of length len(dims), containing
  ##            the size of each dimension of dset
  ##            Note: H5File needs to be aware of that size!
  # NOTE: previously we returned a seq[hsize_t], but we now perform the
  # conversion from int to hsize_t in simple_dataspace() (which is the
  # only place we use the result of this proc!)
  # TODO: move the when T is int: branch from create_dataset to here
  # to clean up create_dataset!
  
  var n_dims: int
  # count the number of fields in the array, since that is number
  # of dimensions we have
  for field in dims.fields:
    inc n_dims

  result = newSeq[int](n_dims)
  # now set the elements of result to the values in the tuple
  var count: int = 0
  for el in dims.fields:
    # now set the value of each dimension
    # enter the shape in reverse order, since H5 expects data in other notation
    # as we do in Nim
    #result[^(count + 1)] = hsize_t(el)
    result[count] = int(el)
    inc count

proc formatName(name: string): string =
  # this procedure formats a given group / dataset namy by prepending
  # a potentially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  result = "/" & strip(name, chars = ({'/'} + Whitespace + NewLines))

proc createGroupFromParent[T](h5f: var T, group_name: string): H5Group =
  ## procedure to create a group within a H5F
  ## Note: this procedure requires that the parent of the group
  ## to create exists, while the group to be created does not!
  ## i.e. only call this function of you are certain of these two
  ## facts
  ## inputs:
  ##    h5f: H5FilObj = the file in which to create the group
  ##    group_name: string = the name of the group to be created
  ## outputs:
  ##    H5Group = returns a group object with the basic properties set

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
  withDebug:
    echo "Checking for existence of group ", result.name, " ", group_name

  let exists = location_id.existsInFile(result.name)
  if exists > 0:
    # group exists, open it
    result.group_id = H5Gopen2(location_id, result.name, H5P_DEFAULT)
    withDebug:
      echo "Group exists H5Gopen2() returned id ", result.group_id    
  elif exists == 0:
    withDebug:
      echo "Group non existant, creating group ", result.name
    # group non existant, create
    result.group_id = H5Gcreate2(location_id, result.name, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  else:
    #TODO: replace by exception
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

  # create attributes field
  result.attrs = initH5Attributes(result.name, result.group_id, "H5Group")
  
  # now that we have created the group fully (including IDs), we can add it
  # to the H5FileObj
  var grp = new H5Group
  grp[] = result
  withDebug:
    echo "Adding element to h5f groups ", group_name
  h5f.groups[group_name] = grp
  grp.groups = h5f.groups
  
  
proc create_group*[T](h5f: var T, group_name: string): H5Group =
  ## checks whether the given group name already exists or not.
  ## If yes:
  ##   return the H5Group object,
  ## else:
  ##   check the parent of that group recursively as well.
  ##   If parent exists:
  ##     create new group and return it
  ## inputs:
  ##    h5f: H5FileObj = the h5f file object in which to look for the group
  ##    group_name: string = the name of the group to check for in h5f
  ## outputs:
  ##    H5Group = an object containing the (newly) created group in the file
  ## NOTE: the creation of the groups via recusion is not all that nice,
  ##   because it relies heavily on state changes via the h5f object
  ##   Think about a cleaner way?
  when h5f is H5Group:
    # in this case need to modify the path of the group from a relative path to an
    # absolute path in the H5 file
    var group_path: string
    if h5f.name notin group_name and group_name notin h5f.name:
      group_path = joinPath(h5f.name, group_name)
    else:
      group_path = group_name
    withDebug:
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

proc parseChunkSizeAndMaxShape(dset: var H5DataSet, chunksize, maxshape: seq[int]): hid_t =
  ## proc to parse the chunk size and maxhshape arguments handed to the create_dataset()
  ## Takes into account the different possible scenarios:
  ##    chunksize: seq[int] = a sequence containing the chunksize, the dataset should be
  ##            should be chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.
  dset.maxshape = maxshape
  dset.chunksize = chunksize
  if maxshape.len > 0:
    # user wishes to create unlimited sized or limited sized + resizable dataset
    # need to create chunked storage.
    if chunksize.len == 0:
      # no chunksize, but maxshape -> chunksize = shape
      dset.chunksize = dset.shape
    else:
      # chunksize given, use it
      dset.chunksize = chunksize
    result = set_chunk(dset.dcpl_id, dset.chunksize)
    if result < 0:
      raise newException(HDF5LibraryError, "HDF5 library returned error on call to `H5Pset_chunk`")
  #elif maxshape.len == 0:
  else:
    if chunksize.len > 0:
      # chunksize given -> maxshape = shape
      dset.maxshape = dset.shape
      result = set_chunk(dset.dcpl_id, dset.chunksize)
      if result < 0:
        raise newException(HDF5LibraryError, "HDF5 library returned error on call to `H5Pset_chunk`")
    else:
      result = 0
  #elif maxshape.len == 0 and chunksize.len == 0:
    # this is the case of ordinary contiguous memory. In order to simplify our
    # lives, we use this case to set the dataset creation property list back to
    # the default. Somewhat ugly, because we introduce even more weird state changes,
    # which seem unnecessary
    # TODO: think about a better way to deal with creation of datasets either with or
    # without chunked memory
    # NOTE: create_dataset_in_file() should take care of this case.
    #dset.dcpl_id = H5P_DEFAULT


proc create_dataset_in_file(h5file_id: hid_t, dset: H5DataSet): hid_t =
  ## proc to create a given dataset in the H5 file described by `h5file_id`
  if dset.maxshape.len == 0 and dset.chunksize.len == 0:
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dset.dataspace_id,
                         H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  else:
    # in this case we are definitely working with chunked memory of some
    # sorts, which means that the dataset creation property list is set
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dset.dataspace_id,
                         H5P_DEFAULT, dset.dcpl_id, H5P_DEFAULT)

proc create_dataset*[T: (tuple | int)](h5f: var H5FileObj,
                                         dset_raw: string,
                                         shape_raw: T,
                                         dtype: (typedesc | hid_t),
                                         chunksize: seq[int] = @[],
                                         maxshape: seq[int] = @[]): H5DataSet = 
  ## procedure to create a dataset given a H5file object. The shape of
  ## that type is given as a tuple, the datatype as a typedescription
  ## inputs:
  ##    h5file: H5FileObj = the H5FileObj received by H5file() into which the data
  ##                   set belongs
  ##    shape: T = the shape of the dataset, given as a tuple
  ##    dtype = typedesc = a Nim typedesc (e.g. int, float, etc.) for that
  ##            dataset. vlen not yet supported
  ##    chunksize: seq[int] = a sequence containing the chunksize, the dataset should be
  ##            should be chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.
  ## outputs:
  ##    ... some dataset object, part of the file?!
  ## throws:
  ##    ... some H5 C related errors ?!
  var status: hid_t = 0
  when T is int:
    # in case we hand an int as the shape argument, it means we wish to write
    # 1 column data to the file. In this case define the shape from here on
    # as a (shape, 1) tuple instead. 
    var shape = (shape_raw, 1)
  else:
    var shape = shape_raw

  # TODO: before call to create_simple and create2, we need to check whether
  # any such dataset already exists. Could include that in the opening procedure
  # by getting all groups etc in the file (by id, not reading the data)

  # remove any trailing / and insert potential missing root /
  var dset_name = formatName(dset_raw)

  # first get the appropriate datatype for the given Nim type
  when dtype is hid_t:
    let dtype_c = dtype
  else:
    let dtype_c = nimToH5type(dtype)

  # need to deal with the shape of the dataset to be created
  #let shape_ar = parseShapeTuple(shape)
  var shape_seq = parseShapeTuple(shape)

  # set up the dataset object
  var dset = newH5DataSet(dset_name)
  when dtype is hid_t:
    # for now we only support vlen arrays, later we need to
    # differentiate between the different H5T class types
    dset.dtype = "vlen"
  else:
    dset.dtype   = name(dtype)
  dset.dtype_c = dtype_c
  dset.dtype_class = H5Tget_class(dtype_c)
  dset.file    = h5f.name
  dset.parent  = getParent(dset_name)

  # given the full dataset name, we need to check whether the group in which the
  # dataset is supposed to be placed, already exists
  let is_root = isInH5Root(dset_name)
  var group: H5Group
  if is_root == false:
    group = create_group(h5f, dset.parent)
  
  withDebug:
    echo "Getting parent Id of ", dset.name
  dset.parent_id = getParentId(h5f, dset)
  dset.shape = shape_seq
  # dset.parent_id = h5f.file_id


  # create the dataset access property list
  dset.dapl_id = H5Pcreate(H5P_DATASET_ACCESS)
  # create the dataset create property list
  dset.dcpl_id = H5Pcreate(H5P_DATASET_CREATE)

  # in case we wish to use chunked storage (either resizable or unlimited size)
  # we need to set the chunksize on the dataset create property list
  try:
    status = dset.parseChunkSizeAndMaxShape(chunksize, maxshape)
    if status >= 0:
      # check whether there already exists a dataset with the given name
      # first in H5FileObj:
      var exists = hasKey(h5f.datasets, dset_name)
      if exists == false:
        # then check the actual file for a dataset with the given name
        # TODO: FOR NOW the location id given to H5Dopen2 is only the file id
        # once we have the parent properly determined, we can also check for
        # the parent (group) id!
        withDebug:
          echo "Checking if dataset exists via H5Lexists ", dset.name
        let in_file = existsInFile(h5f.file_id, dset.name)
        if in_file > 0:
          # in this case successful, dataset exists already
          exists = true
          # in this case open the dataset to read
          dset.dataset_id   = H5Dopen2(h5f.file_id, dset.name, H5P_DEFAULT)
          dset.dataspace_id = H5Dget_space(dset.dataset_id)
          # TODO: include a check about whether the opened dataset actually conforms
          # to what we wanted to create (e.g. same shape etc.)
          
        elif in_file == 0:
          # does not exist
          # now
          withDebug:
            echo "Does not exist, so create dataspace ", dset.name, " with shape ", shape_seq
          dset.dataspace_id = simple_dataspace(shape_seq, maxshape)
          
          # using H5Dcreate2, try to create the dataset
          withDebug:
            echo "Does not exist, so create dataset via H5create2 ", dset.name
          dset.dataset_id = create_dataset_in_file(h5f.file_id, dset)

        else:
          raise newException(HDF5LibraryError, "Call to HDF5 library failed in `existsInFile` from `create_dataset`")
    else:
      raise newException(UnkownError, "Unkown error occured due to call to `parseChunkSizeAndMaxhShape` returning with status = $#" % $status)
  except HDF5LibraryError:
    #let msg = getCurrentExceptionMsg()
    echo "Call to HDF5 library failed in `parseChunkSizeAndMaxShape` from `create_dataset`"
    raise

  # now create attributes field
  dset.attrs = initH5Attributes(dset.name, dset.dataset_id, "H5DataSet")
  h5f.datasets[dset_name] = dset
  # redundant:
  h5f.dataspaces[dset_name] = dset.dataspace_id

  result = dset

# proc create_dataset*[T: (tuple | int)](h5f: var H5Group, dset_raw: string, shape_raw: T, dtype: typedesc): H5DataSet =
  # convenience wrapper around create_dataset to create a dataset within a group with a
  # relative name
  # TODO: problematic to implement atm, because the function still needs access to the file object
  # Solutions:
  #  - either redefine the code in create_datasets to work on both groups or file object
  #  - or give the H5Group each a reference to the H5FileObj, so that it can access it
  #    by itself. This one feels rather ugly though...
  # Alternative solution:
  #  Instead of being able to call create_dataset on a group, we may simply define an
  #  active group in the H5FileObj, so that we can use relative paths from the last
  #  accessed group. This would complicate the code however, since we'd always have
  #  to check whether a path is relative or not!

template getIndexSeq(ind: int, shape: seq[int]): seq[int] =
  # not used
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

withDebug:
  macro test_access(x: typed): untyped =
    result = newStmtList()
    echo treeRepr(x)
    echo treeRepr(result)
    for el in x:
      echo el
    
  proc getValueFromArrayByIndexTuple[T](x: openArray[T], inds: seq[int]): float64 =
    # not needed
    dumpTree:
      result = x[inds[0]][inds[1]]
      x
    test_access(x)

proc shape[T: (SomeNumber | bool | char | string)](x: T): seq[int] = @[]
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

template toH5vlen[T](data: var seq[T]): untyped =
  when T is seq:
    mapIt(toSeq(0..data.high)) do:
      if data[it].len > 0:
        hvl_t(`len`: csize(data[it].len), p: addr(data[it][0]))
      else:
        hvl_t(`len`: csize(0), p: nil)
  else:
    # this doesn't make sense ?!...
    mapIt(toSeq(0..data.high), hvl_t(`len`: csize(data[it]), p: addr(data[it][0])))
    
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

  var err: herr_t
    
  if ind == RW_ALL:
    let shape = dset.shape
    withDebug:
      echo "shape is ", shape
      echo "shape is a ", type(shape).name, " and data is a ", type(data).name, " and data.shape = "
    # check whether we will write a 1 column dataset. If so, relax
    # requirements of shape check. In this case only compare 1st element of
    # shapes. We compare shape[1] with 1, because atm we demand VLEN data to be
    # a 2D array with one column. While in principle it's a N element vector
    # it is always promoted to a (N, 1) array.
    if (shape.len == 2 and shape[1] == 1 and data.shape[0] == dset.shape[0]) or
      data.shape == dset.shape:
      
      if dset.dtype_class == H5T_VLEN:
        # TODO: should we also check whether data really is 1D? or let user deal with that?
        # will flatten the array anyways, so in case on tries to write a 2D array as vlen,
        # the flattened array will end up as vlen in the file
        # in this case we need to prepare the data further by assigning the data to
        # a hvl_t struct
        when T is seq:
          var mdata = data
          # var data_hvl = newSeq[hvl_t](mdata.len)
          # var i = 0
          # for d in mitems(mdata):
          #   data_hvl[i].`len` = d.len
          #   data_hvl[i].p = addr(d[0])#cast[pointer]()
          #   inc i
          var data_hvl = mdata.toH5vlen
          err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                         addr(data_hvl[0]))
          if err < 0:
            withDebug:
              echo "Trying to write data_hvl ", data_hvl
            raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[All]=`")
        else:
          echo "VLEN datatype does not make sense, if the data is of type seq[$#]" % T.name
          echo "Use normal datatype instead. Or did you only hand a single element"
          echo "of your vlen data?"
      else:
        var data_write = flatten(data) 
        err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                       addr(data_write[0]))
        if err < 0:
          withDebug:
            echo "Trying to write data_write ", data_write
          raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[All]=`")
    else:
      var msg = """
Wrong input shape of data to write in `[]=`. Given shape `$#`, dataspace has shape `$#`"""
      msg = msg % [$data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    echo "Dataset not assigned anything, ind: DsetReadWrite invalid"

proc `[]=`*[T](dset: var H5DataSet, ind: DsetReadWrite, data: AnyTensor[T]) =
  # equivalent of above fn, to support arraymancer tensors as input data
  if ind == RW_ALL:
    let tensor_shape = data.squeeze.shape
    # first check whether number of dimensions is the same
    let dims_fit = if tensor_shape.len == dset.shape.len: true else: false
    if dims_fit == true:
      # check whether each dimension is the same size
      let shape_good = foldl(mapIt(toSeq(0..dset.shape.high), tensor_shape[it] == dset.shape[it]), a == b, true)
      var data_write = data.squeeze.toRawSeq
      let err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                         addr(data_write[0]))
      if err < 0:
        withDebug:
          echo "Trying to write tensor ", data_write
        raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[Tensor]=`")
    else:
      var msg = """
Wrong input shape of data to write in `[]=`. Given shape `$#`, dataspace has shape `$#`"""
      msg = msg % [$data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    # TODO: replace by exception
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
    withDebug:
      echo "shape before is ", data.shape
      echo data
    var data_write = flatten(data) 
    let err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                       addr(data_write[0]))
    if err < 0:
      withDebug:
        echo "Trying to write data_write from slice ", data_write
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[Slice]=`")
  else:
    # TODO: replace by exception
    echo "All bad , shapes are ", data.shape, " ", dset.shape

template getSeq(t: untyped, data: untyped): untyped =
  when t is float64:
    data = newSeq[float64](n_elements)
  elif t is int64:
    data = newSeq[int64](n_elements)
  else:
    discard
  data

template withDset*(h5dset: H5DataSet, actions: untyped) =
  ## convenience template to read a dataset from the file and perform actions
  ## with that dataset, without having to manually check the data type of the
  ## dataset
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
  ## procedure to read the data of an existing dataset into 
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    ind: DsetReadWrite = indicator telling us to read whole dataset,
  ##         used to differentiate from the case in which we only read a hyperslab
  ## outputs:
  ##    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset
  ##         TODO: return the correct data shape!
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  if $t != dset.dtype:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given `$#`, dset is `$#`" % [$t, $dset.dtype])
  let
    shape = dset.shape
    n_elements = foldl(shape, a * b)
  # create a flat sequence of the size of the dataset in the H5 file, then read data
  # cannot use the result sequence, since we need to hand the address of the sequence to
  # the H5 library
  var data = newSeq[T](n_elements)    
  dset.read(data)
  
  result = data

proc select_elements[T](dset: var H5DataSet, coord: seq[T]) {.inline.} =
  ## convenience proc to select specific coordinates in the dataspace of
  ## the given dataset
  # first flatten coord tuples
  var flat_coord = mapIt(coord.flatten, hsize_t(it))
  discard H5Sselect_elements(dset.dataspace_id, H5S_SELECT_SET, csize(coord.len), addr(flat_coord[0]))

proc read*[T: seq, U](dset: var H5DataSet, coord: seq[T], buf: var seq[U]) =
  # proc to read specific coordinates (or single values) from a dataset
  
  # select the coordinates in the dataset
  dset.select_elements(coord)
  let memspace_id = create_simple_memspace_1d(coord)
  # now read the elements
  if buf.len == coord.len:
    discard H5Dread(dset.dataset_id, dset.dtype_c, memspace_id, dset.dataspace_id, H5P_DEFAULT,
                    addr(buf[0]))
    
  else:
    echo "Provided buffer is not of same length as number of points to read"
  # close memspace again
  discard H5Sclose(memspace_id)

proc read*[T](dset: var H5DataSet, buf: var seq[T]) =
  # read whole dataset
  if buf.len == foldl(dset.shape, a * b, 1):
    discard H5Dread(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    addr(buf[0]))
    # now write data back into the buffer
    # for ind in 0..data.high:
    #   let inds = getIndexSeq(ind, shape)
    #   buf.set_element(inds, data[ind])
  else:
    var msg = """
Wrong input shape of buffer to write to in `read`. Buffer shape `$#`, dataset has shape `$#`"""
    msg = msg % [$buf.shape, $dset.shape]
    raise newException(ValueError, msg)

proc write_vlen*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  # check whehter we have data for each coordinate
  var err: herr_t
  when U isnot seq:
    var mdata = @[data]
  else:
    var mdata = data
  let valid_data = if coord.len == mdata.len: true else: false
  if valid_data == true:
    let memspace_id = create_simple_memspace_1d(coord)
    dset.select_elements(coord)
    var data_hvl = mdata.toH5vlen

    # DEBUGGING H5 calls
    withDebug:
      echo "memspace select ", H5Sget_select_npoints(memspace_id)
      echo "dataspace select ", H5Sget_select_npoints(dset.dataspace_id)
      echo "dataspace select ", H5Sget_select_elem_npoints(dset.dataspace_id)
      echo "dataspace is valid ", H5Sselect_valid(dset.dataspace_id)
      echo "memspace is valid ", H5Sselect_valid(memspace_id)    

      var start: seq[hsize_t] = @[hsize_t(999), 999]
      var ending: seq[hsize_t] = @[hsize_t(999), 999]     
      echo H5Sget_select_bounds(dset.dataspace_id, addr(start[0]), addr(ending[0]))
      echo "start and ending ", start, " ", ending
    
    err = H5Dwrite(dset.dataset_id,
                   dset.dtype_c,
                   memspace_id,
                   dset.dataspace_id,
                   H5P_DEFAULT,
                   addr(data_hvl[0]))
    if err < 0:
      withDebug:
        echo "Trying to write data_hvl ", data_hvl
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_vlen`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_vlen`")
    
  else:
    var msg = """
Invalid coordinates or corresponding data to write in `write_vlen`. Coord shape `$#`, data shape `$#`"""
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

proc write_norm*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  ## write procedure for normal (read non-vlen) data based on a set of coordinates 'coord'
  ## to write 'data' to. Need to have one element in data for each coord and
  ## data needs to be of shape corresponding to coord
  # mutable copy
  var err: herr_t
  var mdata = data
  let
    # check if coordinates are valid, i.e. each coordinate has rank of dataset
    # only checked whether dimensions are correct, we do NOT check whehter
    # coordinates are within the dataset!
    valid_coords = if coord[0].len == dset.shape.len: true else: false
    # check whehter we have data for each coordinate
    valid_data = if coord.len == mdata.len: true else: false
  if valid_coords == true and valid_data == true:
    let memspace_id = create_simple_memspace_1d(coord)
    dset.select_elements(coord)
    err = H5Dwrite(dset.dataset_id,
                   dset.dtype_c,
                   memspace_id,
                   dset.dataspace_id,
                   H5P_DEFAULT,
                   addr(mdata[0]))
    if err < 0:
      withDebug:
        echo "Trying to write mdata ", mdata
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_norm`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_norm`")    
  else:
    var msg = """
Invalid coordinates or corresponding data to write in `write_norm`. Coord shape `$#`, data shape `$#`"""
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

  
template write*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  # template around both write fns for normal and vlen data
  if dset.dtype_class == H5T_VLEN:
    dset.write_vlen(coord, data)
  else:
    dset.write_norm(coord, data)

template write*[T: (SomeNumber | bool | char | string), U](dset: var H5DataSet,
                                                           coord: seq[T],
                                                           data: seq[U]) =
  # template around both write fns for normal and vlen data in case the coordinates are given as
  # a seq of numbers (i.e. for 1D datasets!)
  if dset.dtype_class == H5T_VLEN:
    # we convert the list of indices to corresponding (y, x) coordinates, because
    # each VLEN table with 1 column, still is a 2D array, which only has the
    # x == 0 column
    dset.write_vlen(mapIt(coord, @[it, 0]), data)
  else:
    # need to differentiate 2 cases:
    # - either normal data is N dimensional (N > 1) in which case
    #   coord is a SINGLE coordinate for the array
    # - or data is 1D (read (N, 1) dimensional) in which case we have
    #   handed 1 or more indices to write 1 or more elements!
    if dset.shape[1] != 1:
      dset.write_norm(@[coord], data)
    else:
      # in case of 1D data, need to separate each element into 1 element
      dset.write_norm(mapIt(coord, @[it, 0]), data)

template write*[T: (seq | SomeNumber | bool | char | string)](dset: var H5DataSet,
                                                              ind: int,
                                                              data: T,
                                                              column = false) =
  ## template around both write fns for normal and vlen data in case we're dealing with 1D
  ## arrays and want to write a single value at index `ind`. Allows for broadcasting along
  ## row or column
  ## throws:
  ##    ValueError: in case data does not fit to whole row or column, if we want to write
  ##                whole row or column by giving index and broadcasting the indices to
  ##                cover whole row
  
  when T is seq:
    # if this is the case we either want to write a whole row (2D array) or
    # a single value in VLEN data
    if dset.dtype_class == H5T_VLEN:
      # does not make sense for tensor
      dset.write(@[ind], data)
    else:
      # want to write the whole row, need to broadcast the index
      let shape = dset.shape
      if data.len != shape[0] and data.len != shape[1]:
        let msg = """
Cannot broadcast ind to dataset in `write`, because data does not fit into array row / column wise. 
    data.len = $#
    dset.shape = $#""" % [$data.len, $dset.shape]
        raise newException(ValueError, msg)
      # NOTE: currently broadcasting ONLY works on 2D arrays!
      let inds = toSeq(0..<shape[1])
      var coord: seq[seq[int]]
      if column == true:
        # fixed column
        coord = mapIt(inds, @[it, ind])
      else:
        # fixed row
        coord = mapIt(inds, @[ind, it])
      dset.write(coord, data)
  else:
    # in this case we're dealing with a single value for a single element
    # do not have to differentiate between VLEN and normal data
    dset.write(@[ind], @[data])
  
template `[]`*(h5f: H5FileObj, name: dset_str): H5DataSet =
  # a simple wrapper around get for datasets
  h5f.get(name)

template `[]`*(h5f: H5FileObj, name: grp_str): H5Group =
  # a simple wrapper around get for groups
  h5f.get(name)


proc write_attribute*[T](h5attr: var H5Attributes, name: string, val: T, skip_check = false) =
  ## writes the attribute `name` of value `val` to the object `h5o`
  ## NOTE: by defalt this function overwrites an attribute, if an attribute
  ## of the same name already exists!
  ## need to
  ## - create simple dataspace
  ## - create attribute
  ## - write attribute
  ## - add attribute to h5attr
  ## - later close attribute when closing parent of h5attr

  var attr_exists = false
  # the first check is done, since we may be calling this function KNOWING that
  # the attribute does not exist. This should normally not be done by a user,
  # but only in case we have previously succesfully deleted the attribute
  if skip_check == false:
    attr_exists = existsAttribute(h5attr.parent_id, name)
    withDebug:
      echo "Attribute $# exists $#" % [name, $attr_exists]
  if attr_exists == false:
    # create a H5Attr, which we add to the table attr_tab of the given
    # h5attr object once we wrote it to file
    var attr: H5Attr
    
    when T is SomeNumber or T is char:
      let
        dtype = nimToH5type(T)
        # create dataspace for single element attribute
        attr_dspace_id = simple_dataspace(1)
        # create the attribute
        attribute_id = H5Acreate2(h5attr.parent_id, name, dtype, attr_dspace_id, H5P_DEFAULT, H5P_DEFAULT)
        # mutable copy for address
      var mval = val
      # write the value
      discard H5Awrite(attribute_id, dtype, addr(mval))

      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      setAttrAnyKind(attr)
      
    elif T is seq or T is string:
      # NOTE:
      # in principle we need to differentiate between simple sequences and nested
      # sequences. However, for now only support normal seqs.
      # extension to nested seqs should be easy (using shape, handed simple_dataspace),
      # however we still need to have a good function to get the basetype of a nested
      # sequence for that
      when T is seq:
        # take first element of sequence to get the datatype
        let dtype = nimToH5type(type(val[0]))
        # create dataspace for attribute
        # 1D so call simple_dataspace with integer, instead of seq
        let attr_dspace_id = simple_dataspace(len(val))
      else:
        let
          # get copy of string type
          dtype = nimToH5type(type(val))
          # and reserve dataspace for string
          attr_dspace_id = string_dataspace(val, dtype)
      # create the attribute
      let attribute_id = H5Acreate2(h5attr.parent_id, name, dtype, attr_dspace_id, H5P_DEFAULT, H5P_DEFAULT)
      # mutable copy for address
      var mval = val
      # write the value
      discard H5Awrite(attribute_id, dtype, addr(mval[0]))

      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      setAttrAnyKind(attr)
    elif T is bool:
      # NOTE: in order to support booleans, we need to use HDF5 enums, since HDF5 does not support
      # a native boolean type. H5 enums not supported yet though...
      echo "Type `bool` currently not supported as attribute"
      discard
    else:
      echo "Type `$#` currently not supported as attribute" % $T.name
      discard

    # add H5Attr tuple to H5Attributes table
    h5attr.attr_tab[name] = attr
  else:
    # if it does exist, we delete the attribute and call this function again, with
    # exists = true, i.e. without checking again whether element exists. Saves us
    # a call to the hdf5 library
    let success = deleteAttribute(h5attr.parent_id, name)
    if success == true:
      write_attribute(h5attr, name, val, true)
    else:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed on call in `deleteAttribute`")

template `[]=`*[T](h5attr: var H5Attributes, name: string, val: T) =
  # convenience access to write_attribue
  h5attr.write_attribute(name, val)

proc read_attribute*[T](h5attr: var H5Attributes, name: string, dtype: typedesc[T]): T =
  # now implement reading of attributes
  # finally still need a read_all attribute. This function only reads a single one, if
  # it exists.
  # check existence, since we read all attributes upon creation of H5Attributes object
  # (attr as small, so the performance overhead should be minimal), we can just access
  # the attribute table to check for existence

  # TODO: check err values!
  
  let attr_exists = hasKey(h5attr.attr_tab, name)
  var err: herr_t
  if attr_exists:
    # in case of existence, read the data and return
    let attr = h5attr.attr_tab[name]
    when T is SomeNumber or T is char:
      var at_val: T
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(at_val))
      result = at_val
    elif T is seq:
      # determine number of elements in seq
      let npoints = H5Sget_simple_extent_npoints(attr.attr_dspace_id)
      # return correct type based on base kind
      var buf_seq: T = @[]
      buf_seq.setLen(npoints)
      # read data
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(buf_seq[0]))
      result = buf_seq
    elif T is string:
      # in case of string, need to determine size. use:
      let string_len = H5Aget_storage_size(attr.attr_id)
      var buf_string = newString(string_len)
      # read data
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(buf_string[0]))
      result = buf_string
  else:
    # raise error
    discard

template `[]`*[T](h5attr: var H5Attributes, name: string, dtype: typedesc[T]): T =
  # convenience access to read_attribute
  h5attr.read_attribute(name, dtype)

template `[]`*(h5attr: H5Attributes, name: string): AnyKind =
  # accessing H5Attributes by string simply returns the datatype of the stored
  # attribute as an AnyKind value
  h5attr.attr_tab[name].dtypeAnyKind

proc getObjectTypeByName(h5id: hid_t, name: string): H5O_type_t =
  # proc to retrieve the type of an object (dataset or group etc) based on
  # a location in the HDF5 file and a relative name from there
  var h5info: H5O_info_t
  let err = H5Oget_info_by_name(h5id, name, addr(h5info), H5P_DEFAULT)
  withDebug:
    echo "Getting Type of object ", name
  if err >= 0:
    result = h5info.`type`
  else:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getObjectTypeByName`")

proc getObjectIdByName(h5file: var H5FileObj, name: string): hid_t =
  # proc to retrieve the location ID of a H5 object based its relative path
  # to the given id
  let h5type = getObjectTypeByName(h5file.file_id, name)
  # get type
  withDebug:
    echo "Getting ID of object ", name
  if h5type == H5O_TYPE_GROUP:
    if hasKey(h5file.groups, name) == false:
      # in this case we know that the group exists,
      # otherwise we would not be calling this proc,
      # so create the local copy of it
      # TODO: this introduces HUGE problems, if we want to be able
      # to call this function from everywhere, not only create_hardlinks!
      # may not want to create such a group, if it does not exist
      # instead return a not found error!
      discard h5file.create_group(name)
    result = h5file[name.grp_str].group_id
  elif h5type == H5O_TYPE_DATASET:
    result = h5file[name.dset_str].dataset_id

proc create_hardlink*(h5file: var H5FileObj, target: string, link_name: string) =
  # proc to create hardlinks between pointing to an object `target`. Can be either a group
  # or a dataset, defined by its name (full path!)
  # the target has to exist, while the link_name must be free
  var err: herr_t
  if existsInFile(h5file.file_id, target) > 0:
    # get the parent of link name and create that group, in case
    # it does not exist
    let parent = getParent(link_name)
    if existsInFile(h5file.file_id, parent) == 0:
      withDebug:
        echo "Parent does not exist in file, create parent ", parent
      discard h5file.create_group(parent)
    
    if existsInFile(h5file.file_id, link_name) == 0:
      # get the information about the existing link by its name
      let target_id = getObjectIdByName(h5file, target)
      # to get the id of the link name, we need to first determine the parent
      # of the link
      # TODO: create parent groups of `link_name`
      let link_id   = getObjectIdByName(h5file, parent)
      err = H5Lcreate_hard(h5file.file_id, target, link_id, link_name, H5P_DEFAULT, H5P_DEFAULT)
      if err < 0:
        raise newException(HDF5LibraryError, "Call to HDF5 library failed in `create_hardlink` upon trying to link $# -> $#" % [link_name, target])
    else:
      echo "Warning: Did not create hard link $# -> $# in file, already exists in file $#" % [link_name, target, h5file.name]
  else:
    raise newException(KeyError, "Cannot create link to $#, does not exist in file $#" % [$target, $h5file.name])
  
proc resize*[T: tuple](dset: var H5DataSet, shape: T) =
  ## proc to resize the dataset to the new size given by `shape`
  ## inputs:
  ##     dset: var H5DataSet = dataset to be resized
  ##     shape: T = tuple describing the new size of the dataset
  ## Keep in mind:
  ##   - resizing only possible for datasets using chunked storage
  ##     (created with chunksize / maxshape != @[])
  ##   - resizing to smaller size than current size drops data
  ## throws:
  ##   HDF5LibraryError: if a call to the HDF5 library fails
  ##   ImmutableDatasetError: if the given dataset is contiguous memory instead
  ##     of chunked storage, i.e. cannot be resized

  # check if dataset is chunked storage
  if H5Pget_layout(dset.dcpl_id) == H5D_CHUNKED:
    var newshape = mapIt(parseShapeTuple(shape), hsize_t(it))
    # before we resize the dataspace, we get a copy of the
    # dataspace, since this internally refreshes the dataset. Important
    # since the dataset might be opened for reading when this
    # proc is called
    dset.dataspace_id = H5Dget_space(dset.dataset_id)
    let status = H5Dset_extent(dset.dataset_id, addr(newshape[0]))
    # set the shape we just resized to as the current shape
    withDebug:
      echo "Extending the dataspace to ", newshape
    dset.shape = mapIt(newshape, int(it))
    # after all is said and done, refresh again
    dset.dataspace_id = H5Dget_space(dset.dataset_id)
    if status < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed in `resize` calling `H5Dset_extent`")
  else:
    raise newException(ImmutableDatasetError, "Cannot resize a non-chunked (i.e. contiguous) dataset!")

proc select_hyperslab(dset: var H5DataSet, offset, count: seq[int], stride, blk: seq[int] = @[]) =
  # given the dataspace of `dset`, select a hyperslab of it using `offset`, `stride`, `count` and `blk`
  # for which all needs to hold:
  # dset.shape.len == offset.shape.len, i.e. they need to be of the same rank as dset is
  # we currently set the hyperslab selection such that previous selections are overwritten (2nd argument)
  var
    err: herr_t
    moffset = mapIt(offset, hsize_t(it))
    mcount  = mapIt(count, hsize_t(it))
    mstride: seq[hsize_t] = @[]
    mblk: seq[hsize_t] = @[]
  if stride.len > 0:
    mstride = mapIt(stride, hsize_t(it))
  if blk.len > 0:
    mblk    = mapIt(blk, hsize_t(it))

  # in case of empty stride or block seqs, set them to the required definition
  # i.e. values of 1 for each dimension
  if stride.len == 0:
    mstride = mapIt(toSeq(0..offset.high), hsize_t(1))
  if blk.len == 0:
    mblk = mapIt(toSeq(0..offset.high), hsize_t(1))

  withDebug:
    echo "Selecting the following hyperslab"
    echo "offset: ", moffset
    echo "count:  ", mcount
    echo "stride: ", mstride
    echo "block:  ", mblk
    
  # just in case get the most current dataspace
  dset.dataspace_id = H5Dget_space(dset.dataset_id)
  # and perform the selection on this dataspace
  err = H5Sselect_hyperslab(dset.dataspace_id, H5S_SELECT_SET, addr(moffset[0]), addr(mstride[0]), addr(mcount[0]), addr(mblk[0]))
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sselect_hyperslab` in `select_hyperslab`")

proc write_hyperslab*[T](dset: var H5DataSet, data: seq[T], offset, count: seq[int], stride, blk: seq[int] = @[]) =
  # proc to select a hyperslab and write to it
  var err: herr_t

  # flatten the data array to be written
  var mdata = data.flatten

  dset.dataspace_id = H5Dget_space(dset.dataset_id)
  let memspace_id = simple_dataspace(data.shape)
  dset.select_hyperslab(offset, count, stride, blk)

  err = H5Dwrite(dset.dataset_id, dset.dtype_c, memspace_id, dset.dataspace_id, H5P_DEFAULT, addr(mdata[0]))
  if err < 0:
    withDebug:
      echo "Trying to write mdata with shape ", mdata.shape
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_hyperslab`")
  err = H5Sclose(memspace_id)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_vlen`")
