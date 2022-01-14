import strutils
import tables
import strformat
import macros

import hdf5_wrapper, H5nimtypes, util

type
  # based on `typeinfo.AnyKind` enum
  DtypeKind* = enum  ## what kind of ``dtype`` it is
    dkNone,        ## invalid any
    dkBool,        ## represents a ``bool``
    dkChar,        ## represents a ``char``
    dkEnum,        ## represents an enum
    dkArray,       ## represents an array
    dkObject,      ## represents an object
    dkTuple,       ## represents a tuple ``NOTE``: not used. Tuples are represented as dkObject!
    dkSet,         ## represents a set
    dkRange,       ## represents a range
    dkPtr,         ## represents a ptr
    dkRef,         ## represents a ref
    dkSequence,    ## represents a sequence
    dkProc,        ## represents a proc
    dkPointer,     ## represents a pointer
    dkString,      ## represents a string
    dkCString,     ## represents a cstring
    dkInt,         ## represents an int
    dkInt8,        ## represents an int8
    dkInt16,       ## represents an int16
    dkInt32,       ## represents an int32
    dkInt64,       ## represents an int64
    dkFloat,       ## represents a float
    dkFloat32,     ## represents a float32
    dkFloat64,     ## represents a float64
    dkFloat128,    ## represents a float128
    dkUInt,        ## represents an unsigned int
    dkUInt8,       ## represents an unsigned int8
    dkUInt16,      ## represents an unsigned in16
    dkUInt32,      ## represents an unsigned int32
    dkUInt64,      ## represents an unsigned int64

  # these distinct types provide the ability to distinguish the `[]` function
  # acting on H5File between a dataset and a group, s.t. we can access groups
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
  DsetReadWrite* = enum
    RW_ALL

  # object which stores information about the attributes of a H5 object
  # each dataset, group etc. has a field .attr, which contains a H5Attributes
  # object
  H5AttributesObj = object
    # attr_tab is a table containing names and corresponding
    # H5 info
    attr_tab*: TableRef[string, H5Attr]
    num_attrs*: int
    parent_name*: string
    parent_id*: ParentID
    parent_type*: string
  H5Attributes* = ref H5AttributesObj

  # stores information about a single attribute
  H5AttrObj* = object
    opened*: bool # flag which indicates whether attribute is opened
    attr_id*: AttributeID
    dtype_c*: DatatypeID
    dtypeAnyKind*: DtypeKind
    # BaseKind contains the type within a (nested) seq iff
    # dtypeAnyKind is dkSequence
    dtypeBaseKind*: DtypeKind
    attr_dspace_id*: DataspaceID
  H5Attr* = ref H5AttrObj

  # an object to store information about a hdf5 dataset. It is a combination of
  # an HDF5 dataspace and dataset id (contains both of them)
  H5DataSetObj* = object
    name*: string
    # datasets may not be open (in that case only the name is really valid!)
    opened*: bool
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
    dtypeAnyKind*: DtypeKind
    # BaseKind contains the type within a (nested) seq iff
    # dtypeAnyKind is dkSequence (i.e. of variable length type)
    dtypeBaseKind*: DtypeKind
    # actual HDF5 datatype used as a hid_t, this can be handed to functions needing
    # its datatype
    dtype_c*: DatatypeID
    # H5 datatype class, useful to check what kind of data we're dealing with (VLEN etc.)
    dtype_class*: H5T_class_t
    # parent string, which contains the name of the group in which the
    # dataset is located
    parent*: string
    # the id of the parent (location id in HDF5 lang). Either file id or group ID
    parent_id*: ParentID
    # filename string, in which the dataset is located
    file*: string
    # reference to the file object, in which dataset resides. Important to perform checks
    # in procs, which should not depend explicitly on H5File, but necessarily depend
    # implicitly on it, e.g. create_dataset (called from group) etc.
    # TODO: is this needed for dataset?
    # file_ref*: ref H5File
    # the id of the dataset
    dataset_id*: DatasetID
    # `all` index, to indicate that we wish to set the whole dataset to the
    # value on the RHS (has to be exactly the same shape!)
    all*: DsetReadWrite
    # attr stores information about attributes
    attrs*: H5Attributes
    # property list identifiers, which stores information like "is chunked storage" etc.
    # here we store H5P_DATASET_ACCESS property list
    dapl_id*: DatasetAccessPropertyListID
    # here we store H5P_DATASET_CREATE property list
    dcpl_id*: DatasetCreatePropertyListID
  H5DataSet* = ref H5DataSetObj

  # an object to store information about a HDF5 group
  H5GroupObj* = object
    name*: string
    # groups may not be open (in that case only the name is really valid!)
    opened*: bool
    # # parent string, which contains the name of the group in which the
    # # dataset is located
    parent*: string
    # # the id of the parent (location id in HDF5 lang). Either file id or group ID
    parent_id*: ParentID
    # filename string, in which the dataset is located
    file*: string
    # file id of the file in which group is stored
    file_id*: FileID
    # reference to the file object, in which group resides. Important to perform checks
    # in procs, which should not depend explicitly on H5File, but necessarily depend
    # implicitly on it, e.g. create_group, iterator items etc.
    file_ref*: H5File
    # the id of the HDF5 group (its location id)
    group_id*: GroupID
    # table of all datasets in the file
    datasets*: TableRef[string, H5DataSet]
    # each group may have subgroups itself, keep table of these
    groups*: TableRef[string, H5Group]
    # attr stores information about attributes
    attrs*: H5Attributes
    # property list identifier, which stores information like "is chunked storage" etc.
    # here we store H5P_GROUP_ACCESS property list
    gapl_id*: GroupAccessPropertyListID
    # here we store H5P_GROUP_CREATE property list
    gcpl_id*: GroupCreatePropertyListID
  H5Group* = ref H5GroupObj

  H5FileObj* {.deprecated: "Use `H5File` instead. This is a leftover naming scheme " &
    "from when the H5 objects were not ref objects. This is an alias for H5File.".} = H5File
  H5FileObjImpl = object
    name*: string
    # the file_id is the unique identifier of the opened file. Each
    # low level C call uses this file_id to idenfity the file to work
    # on. Should only be used if you need to access functions for which
    # no high level equivalent exists.
    file_id*: FileID
    # var which stores access type. For internal use. Might be needed
    # for access to low level C calls, which have no high level equiv.
    rw_type*: cuint
    # var to store error codes of called C functions
    err*: herr_t
    # var to store status of C calls
    status*: hid_t
    # groups is a table, which stores the names of groups stored in the file
    groups*: TableRef[string, H5Group]
    # datasets is a table, which stores the names of datasets by string
    # while keeping the hid_t dataset_id as the value
    datasets*: TableRef[string, H5DataSet]
    # attr stores information about attributes
    attrs*: H5Attributes
    # flag to be aware if we visited the whole file yet (discovered groups and dsets)
    visited*: bool
    # property list identifier, which stores information like "is chunked storage" etc.
    # here we store H5P_FILE_ACCESS property list
    fapl_id*: FileAccessPropertyListID
    # here we store H5P_FILE_CREATE property list
    fcpl_id*: FileCreatePropertyListID
  H5File* = ref H5FileObjImpl

  # this exception is used in cases where all conditional cases are already thought
  # to be covered to annotate (hopefully!) unreachable branches
  UnkownError* = object of Defect
  # raised if a call to a HDF5 library function returned with an error
  # (typically result < 0 means error)
  HDF5LibraryError* = object of CatchableError
  # raised if the user tries to change the size of an immutable dataset, i.e. non-chunked storage
  ImmutableDatasetError* = object of CatchableError
  # raised if the user tries to change to write to a file opened with read only access
  ReadOnlyError* = object of CatchableError
  # raised if some part of code that is not yet implemented (but planned) is being called
  NotImplementedError* = object of Defect

  # enum which determines how the given H5 object should be flushed
  # corresponds to the H5F_SCOPE flags
  FlushKind* = enum
    fkLocal, fkGlobal

  # An enum that maps different H5 object kind values to more readable names
  ## TODO: we could map these values directly?
  ObjectKind* = enum
    okNone, okFile, okDataset, okGroup, okType, okAttr, okAll

  ParentID* = object
    case kind*: ObjectKind
    of okFile:
      fid*: FileID
    of okDataset:
      did*: DatasetID
    of okGroup:
      gid*: GroupID
    of okType:
      typId*: DatatypeID
    of okAttr:
      attrId*: AttributeID
    of okAll, okNone: discard # all cannot be a parent

const
  H5_NOFILE* = hid_t(-1)
  H5_OPENFILE* = hid_t(1)

# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW* = cuint(0x00FF)

## NOTE: the following two `dataspace_id` procs ``*really*`` do not belong here. But the problem is
## we need them for `close` of `H5DataSet`. Those shouldn't be here either, but they are needed
## for `=destroy`, which must be here close to the type definition... This is a bit dumb.
proc dataspace_id*(dataset_id: DatasetID): DataspaceID {.inline.} =
  ## convenienve wrapper around H5Dget_space proc, which returns the dataspace
  ## id of the given dataset_id
  result = H5Dget_space(dataset_id.hid_t).DataspaceID

proc dataspace_id*(dset: H5DataSet): DataspaceID =
  ## convenienve wrapper around H5Dget_space proc, which returns the dataspace
  ## id of the given dataset_id
  ## same as above, but works on the `H5DataSet` directly and gets the dataset
  ## id from it
  result = dset.dataset_id.dataspace_id

proc to_hid_t*(p: ParentID): hid_t =
  case p.kind
  of okFile: result = p.fid.hid_t
  of okDataset: result = p.did.hid_t
  of okGroup: result = p.gid.hid_t
  of okType: result = p.typId.hid_t
  of okAttr: result = p.attrId.hid_t
  of okAll, okNone:
    raise newException(ValueError, "Cannot convert ParentID of kind " & $p.kind &
      " to a `hid_t` value.")

func getH5Id*[T: H5File | H5DataSet | H5DatasetObj | H5Group | H5GroupObj](h5o: T): ParentID =
  ## this func returns the ID of the given object as a `ParentID`
  ## of the correct kind.
  when h5o is H5File:
    result = ParentID(kind: okFile, fid: h5o.file_id)
  elif h5o is H5Group or h5o is H5GroupObj:
    result = ParentID(kind: okGroup, gid: h5o.group_id)
  elif h5o is H5DataSet or h5o is H5DatasetObj:
    result = ParentID(kind: okDataset, did: h5o.dataset_id)
  else:
    {.error: "Invalid branch!".}

proc isObjectOpen*(h5id: hid_t): bool =
  ## Determines whether the object associated with the given ID is still open.
  ##
  ## This procedure is valid for *any* H5 identifier, including attributes, dataspaces
  ## access property lists, etc.
  ##
  ## This is achieved by checking if the identifier is valid. An identifier is valid only
  ## as long as the object is open. Note: this is sane, because we assign the ID fields
  ## of the objects only based on calls to the H5 library, so we know these IDs are
  ## valid at some point.
  let err = H5Iis_valid(h5id)
  if err > 0:
    result = true
  elif err == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "Call to `H5Iis_valid` failed calling with identifier: " &
      $h5id)

proc isObjectOpen*(h5id: ParentID): bool {.inline.} =
  ## Determines whether the object associated with the given `ParentID` still open.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5id.to_hid_t.isObjectOpen

proc isObjectOpen*[T: H5File | H5Group | H5GroupObj | H5Dataset | H5DatasetObj](h5o: T): bool {.inline.} =
  ## Determines whether the given object is still open.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5o.getH5ID.isObjectOpen()

proc close*[T: DataspaceID | MemspaceID | HyperslabID](space_id: T, msg = "") =
  ## Closes the dataspace / memspace and raises `HDF5LibraryError` in case closing fails.
  ##
  ## `msg` can be handed for additional information in the exception.
  let err = H5Sclose(space_id.hid_t)
  if err < 0:
    when T is DataspaceID:
      let typ = "dataspace"
    elif T is MemspaceID:
      let typ = "memspace"
    else:
      let typ = "hyperslab"
    raise newException(HDF5LibraryError, "Error closing " & typ & " of dataset!" & msg)

proc close*(dpl_id: DatasetCreatePropertyListID | DatasetAccessPropertyListID,
            msg = "") =
  ## Closes the dataset access/create property list (`dapl/dcpl`) of a dataset
  ## and raises `HDF5LibraryError` in case closing fails.
  ##
  ## `msg` can be handed for additional information in the exception.
  let err = H5Pclose(dpl_id.hid_t)
  if err < 0:
    raise newException(HDF5LibraryError, "Error closing create property list of dataset." & msg)

proc close*(dtype_id: DatatypeID) =
  ## Closes the given datatype.
  let status = H5Tclose(dtype_id.hid_t)
  if status < 0:
    raise newException(HDF5LibraryError, "Status of H5Tclose() returned non-negative value. " &
      "Call to HDF5 library failed in `close` of a datatype.")

proc close*(attr: var H5AttrObj) =
  ## closes the attribute and the corresponding dataspace
  if attr.opened and attr.attr_id.hid_t.isObjectOpen:
    var err = H5Aclose(attr.attr_id.hid_t)
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing attribute with id " &
        $(attr.attr_id.hid_t) & "!")
    withDebug:
      echo "Closed attribute with status ", err
    err = H5Sclose(attr.attr_dspace_id.hid_t)
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing dataspace of attribute with id" &
        $(attr.attr_id.hid_t) & "!")
    attr.opened = false

proc close*(attr: H5Attr) = attr[].close()

proc flush*(group: H5Group, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(group.group_id.hid_t, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(group.group_id.hid_t, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush group " & group.name &
      " as " & $flushKind & " failed!")

proc close*(group: var H5GroupObj) =
  if group.opened and group.isObjectOpen():
    let err = H5Gclose(group.group_id.hid_t)
    if err != 0:
      raise newException(HDF5LibraryError, "Failed to close group " & group.name & "!")
    group.opened = false

proc close*(group: H5Group) = group[].close()

proc flush*(dset: H5DataSetObj, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(dset.dataset_id.hid_t, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(dset.dataset_id.hid_t, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush dataset " & dset.name &
      " as " & $flushKind & " failed!")

proc flush*(dset: H5DataSet, flushKind: FlushKind) = dset[].flush(flushKind)

proc close*(dset: var H5DataSetObj) =
  if dset.opened and dset.isObjectOpen():
    # close the dataset creation property list, important if filters are used
    dset.dcpl_id.close(msg = "dcpl associated with dataset: " & $dset.name)
    withDebug:
      # by calling flush here, depending on the status of the library
      # this might be the place where the actual writing to file takes place
      echo "Flushing dataset during `close` of: ", dset.name
    dset.flush(fkLocal) # flush the dataset before we close it!
    withDebug:
      echo "...done"
    ## TODO: is this ever required? Or on the other hand is it sane to have a `=destroy` hook
    ## that calls `close` on a dataspace when it goes out of scope?
    dset.dataset_id.dataspace_id().close(msg = "Dataspace associated with dataset: " & $dset.name)
    let err = H5Dclose(dset.dataset_id.hid_t) # now the *actual* closing of the dataset
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing dataset " & $(dset.name) & "!")
    dset.opened = false

proc close*(dset: H5DataSet) = dset[].close()

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
  proc `=destroy`*(attr: var H5AttrObj) =
    ## Closes the given attribute.
    attr.close()
    for name, field in fieldPairs(attr):
      `=destroy`(field)

  proc `=destroy`*(attrs: var H5AttributesObj) =
    ## Closes all attributes that are stored in this `H5Attributes` table.
    if attrs.attr_tab != nil:
      for name, attr in mpairs(attrs.attr_tab):
        if attr != nil:
          `=destroy`(attr)
      `=destroy`(attrs.attr_tab)
    for name, field in fieldPairs(attrs):
      if name != "attr_tab":
        when typeof(field) is string or typeof(field) is seq:
          `=destroy`(field)

  proc `=destroy`*(dset: var H5DataSetObj) =
    ## Closes the dataset and resets all references to nil.
    dset.close() # closes its dataspace etc. as well
    dset.opened = false
    if dset.attrs != nil:
      `=destroy`(dset.attrs)
    for name, field in fieldPairs(dset):
      if name != "attrs":
        when typeof(field) is string or typeof(field) is seq:
          `=destroy`(field)

  proc `=destroy`*(grp: var H5GroupObj) =
    ## Closes the group and resets all references to nil.
    grp.file_ref = nil
    grp.file_id = -1.FileID
    grp.parent_id = ParentID(kind: okNone)
    grp.close()
    grp.opened = false
    if grp.datasets != nil:
      `=destroy`(grp.datasets)
    if grp.groups != nil:
      `=destroy`(grp.groups)
    if grp.attrs != nil:
      `=destroy`(grp.attrs)
    for name, field in fieldPairs(grp):
      if name notin ["attrs", "groups", "datasets", "file_ref"]:
        when typeof(field) is string or typeof(field) is seq:
          `=destroy`(field)

  #proc `=destroy`*(grp: var H5Group) =
  #  ## Closes the group and resets all references to nil.
  #  grp.file_ref = nil
  #  grp.file_id = -1.FileID
  #  grp.parent_id = ParentID(kind: okNone)
  #  grp.close()
  #  grp.opened = false

  when false:
    ## currently these are problematic, as we're allowed to just copy these IDs in Nim land,
    ## and for each copy going out of scope `=destroy` would be called. Can cause double free.
    ## We could wrap them in a `ref` or disallow `=copy`.
    proc `=destroy`*(dspace_id: var DataspaceID) =
      ## Closes the dataspace when it goes out of scope
      dspace_id.close()

    proc `=destroy`*(mspace_id: var MemspaceID) =
      ## Closes the memspace when it goes out of scope
      mspace_id.close()

proc parseH5toObjectKind*(h5Kind: int): ObjectKind =
  if h5Kind == H5F_OBJ_FILE:
    result = okFile
  elif h5Kind == H5F_OBJ_DATASET:
    result = okDataset
  elif h5Kind == H5F_OBJ_GROUP:
    result = okGroup
  elif h5Kind == H5F_OBJ_DATATYPE:
    result = okType
  elif h5Kind == H5F_OBJ_ATTR:
    result = okAttr
  elif h5Kind == H5F_OBJ_ALL:
    result = okAll

proc parseObjectKindToH5*(kind: ObjectKind): int =
  case kind
  of okFile:
    result = H5F_OBJ_FILE
  of okDataset:
    result = H5F_OBJ_DATASET
  of okGroup:
    result = H5F_OBJ_GROUP
  of okType:
    result = H5F_OBJ_DATATYPE
  of okAttr:
    result = H5F_OBJ_ATTR
  of okAll:
    result = H5F_OBJ_ALL
  of okNone:
    raise newException(ValueError, "ObjectKind `okNone` cannot be " &
      "converted to a HDF5 corresponding value.")

proc newH5Attributes*(): H5Attributes =
  let attr = newTable[string, H5Attr]()
  result = H5Attributes(attr_tab: attr,
                        num_attrs: -1,
                        parent_name: "",
                        parent_id: ParentID(kind: okNone),
                        parent_type: "")

proc getNumAttrs*(h5attr: H5Attributes): int =
  ## proc to get the number of attributes of the parent
  ## uses H5Oget_info, which returns a struct containing the
  ## metadata of the object (incl type etc.). Might be useful
  ## at other places too?
  ## reserve space for the info object
  var h5info: H5O_info_t
  let err = H5Oget_info(h5attr.parent_id.to_hid_t, addr(h5info))
  if err >= 0:
    # successful
    withDebug:
      debugEcho "getNumAttrs(): ", h5attr
    result = int(h5info.num_attrs)
  else:
    withDebug:
      debugEcho "getNumAttrs(): ", h5attr
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getNumAttr` when reading $#" % $h5attr.parent_name)

proc initH5Attributes*(p_id: ParentID, p_name: string = "", p_type: string = ""): H5Attributes =
  let attr = newTable[string, H5Attr]()
  doAssert p_id.kind notin {okNone, okAll}, "parent id must exist!"
  var h5attr = H5Attributes(attr_tab: attr,
                            num_attrs: -1,
                            parent_name: p_name,
                            parent_id: p_id,
                            parent_type: p_type)
  h5attr.num_attrs = h5attr.getNumAttrs
  # read_all_attributes(h5attr)
  result = h5attr

proc newH5DataSet*(name: string = "",
                   file: string = "",
                   parent: string = "",
                   parentID: ParentID = ParentID(kind: okNone),
                   shape: seq[int] = @[]): H5DataSet =
  ## default constructor for a H5File object, for internal use
  let maxshape: seq[int] = @[]
  let attrs = newH5Attributes()
  result = new H5DataSet
  result.name = name
  result.opened = false
  result.shape = shape
  result.maxshape = maxshape
  result.dtype = ""
  result.dtype_c = -1.DatatypeID
  result.parent = parent
  result.parentID = parentID
  result.file = file
  result.dataset_id = -1.DatasetID
  result.all = RW_ALL
  result.shape = shape
  result.attrs = attrs

proc newH5Group*(name: string = "",
                 file_ref: H5File = nil,
                 parentID: ParentID = ParentID(kind: okNone)): H5Group =
  ## default constructor for a H5Group object, for internal use.
  ##
  ## If a `file_ref` is already given, it will fill all relevant fields.
  ##
  ## If the group is checked to exist, we also fill the parent field.
  # better leave the tables as `nil`?
  let datasets = newTable[string, H5DataSet]()
  let groups = newTable[string, H5Group]()
  let attrs = newH5Attributes()
  result = new H5Group
  result.name = name
  result.opened = false
  result.parent = name.getParent
  result.attrs = attrs
  result.parent_id = parentID
  if file_ref.isNil:
    result.file = ""
    result.file_id = -1.FileID
    result.file_ref = nil
    result.datasets = datasets
    result.groups = groups
  else:
    result.file_ref = file_ref
    result.file = file_ref.name
    result.file_id = file_ref.file_id
    result.datasets = file_ref.datasets
    result.groups = file_ref.groups

proc getTypeNoSize(x: DtypeKind): DtypeKind =
  ## returns the datatype without size information
  case x
  of dkNone .. dkCString:
    result = x
  of dkInt .. dkInt64:
    result = dkInt
  of dkFloat .. dkFloat128:
    result = dkFloat
  of dkUint .. dkUint64:
    result = dkUint

macro name*(t: typed): untyped =
  ## returns name of given data type
  result = getTypeInst(t)[1].getType.toStrLit

proc typeMatches*(dtype: typedesc, dstr: string): bool =
  ## returns true, if the given ``typedesc`` matches the descriptor in
  ## string
  ## ``dstr`` should always contain the number in bytes of the type!
  ## (if it is of int | float | uint that is)
  ## This is the case for datatypes stored as strings in the datasets within
  ## a H5 file
  # create an ``DtypeKind`` from given dtype and remove potential size information
  let dAnyKind = parseEnum[DtypeKind]("dk" & name(dtype), dkNone).getTypeNoSize
  # get the string datatypes `DtypeKind` without size information
  let dstrAnyKind = parseEnum[DtypeKind]("dk" & dstr, dkNone).getTypeNoSize
  case dstrAnyKind
  of dkInt .. dkUint64:
    let expectedSize = dstr.strip(chars = Letters).parseInt div 8
    result = if expectedSize == sizeof(dtype) and
                dAnyKind == dstrAnyKind:
               true
             else:
               false
  of dkObject:
    result = dtype is object or dtype is tuple
  else:
    # no size check necessary
    result = if dAnyKind == dstrAnyKind: true else: false

proc h5ToNimType*(dtype_id: DatatypeID): DtypeKind =
  ## proc to return a type descriptor (via DtypeKind) describing the given
  ## H5 type. From the return value, we can set the data type in the H5DataSet obj
  ## inputs:
  ##     dtype_id: hid_t = datatype id returned by the H5 library about the datasets' type
  ## outputs:
  ##     DtypeKind = enum value corresponding to a Nim datatype. We use the
  ##            string representation of it to set the H5DataSet.dtype: string to its
  ##            correct value
  ## throws:
  ##    KeyError: if the given H5 data type is currently not mapped to a Nim type
  ##              (see src/nimhdf5/H5Tpublic.nim for a list of *all* H5 types...)

  # TODO: we may can seperate the dtypes by class using H5Tget_class, which returns a value
  # of the H5T_class_t enum (e.g. H5T_FLOAT)
  let dtypeHid_t = dtype_id.hid_t
  withDebug:
    echo "dtype is ", dtypeHid_t
    echo "native is ", H5Tget_native_type(dtypeHid_t, H5T_DIR_ASCEND)
  if H5Tequal(H5T_NATIVE_DOUBLE, dtypeHid_t) == 1:
    result = dkFloat64
  elif H5Tequal(H5T_NATIVE_FLOAT, dtypeHid_t) == 1:
    result = dkFloat32
  elif H5Tequal(H5T_NATIVE_LONG, dtypeHid_t) == 1:
    # maps to `long`
    case sizeof(clong)
    of 4: result = dkInt32
    of 8: result = dkInt64
    else: doAssert false, "`long` of size other than 4, 8 bytes?"
  elif H5Tequal(H5T_NATIVE_INT, dtypeHid_t) == 1:
    # maps to `int`
    doAssert sizeof(cint) == 4
    result = dkInt32
  elif H5Tequal(H5T_NATIVE_LLONG, dtypeHid_t) == 1:
    # maps to `long long`
    doAssert sizeof(clonglong) == 8
    result = dkInt64
  elif H5Tequal(H5T_NATIVE_UINT, dtypeHid_t) == 1:
    # maps to `unsigned`
    doAssert sizeof(cuint) == 4
    result = dkUint32
  elif H5Tequal(H5T_NATIVE_ULONG, dtypeHid_t) == 1:
    case sizeof(culong)
    of 4: result = dkUint32
    of 8: result = dkUint64
    else: doAssert false, "`unsigned long` of size other than 4, 8 bytes?"
  elif H5Tequal(H5T_NATIVE_ULLONG, dtypeHid_t) == 1:
    doAssert sizeof(culonglong) == 8
    result = dkUint64
  elif H5Tequal(H5T_NATIVE_SHORT, dtypeHid_t) == 1:
    result = dkInt16
  elif H5Tequal(H5T_NATIVE_USHORT, dtypeHid_t) == 1:
    result = dkUint16
  elif H5Tequal(H5T_NATIVE_CHAR, dtypeHid_t) == 1:
    result = dkInt8
  elif H5Tequal(H5T_NATIVE_UCHAR, dtypeHid_t) == 1:
    result = dkUint8
  elif H5Tget_class(dtypeHid_t) == H5T_STRING:
    result = dkString
  elif H5Tget_class(dtypeHid_t) == H5T_VLEN:
    # represent vlen types as sequence for any kind
    result = dkSequence
  elif H5Tget_class(dtypeHid_t) == H5T_COMPOUND:
    result = dkObject
  else:
    raise newException(KeyError, "Warning: the following H5 type could not be converted: " &
      "$# of class $#" % [$(dtype_id.hid_t), $(H5Tget_class(dtypeHid_t))])

proc special_type*(dtype: typedesc): DatatypeID =
  ## calls the H5Tvlen_create() to create a special datatype
  ## for variable length data
  when dtype isnot string:
    result = H5Tvlen_create(nimToH5type(dtype).hid_t).DatatypeID
  else:
    raise newException(ValueError, "Currently not implemented to create variable string datatype." &
      " This does not raise at CT to avoid CT errors when using `withDset`.")

template insertType(res, nameStr, name, val: untyped): untyped =
  H5Tinsert(res, nameStr.cstring, offsetOf(val, name).csize_t,
            nimToH5type(typeof(val.name)).hid_t)

macro walkObjectAndInsert(dtype: typed,
                          res: untyped): untyped =
  ## simple macro similar to `fieldPairs` which walks an object type. It creates
  ## an `discard insertType(`res`, `nStr`, `n`, `dtype`)` line for each field
  ## in an object to construct a compound datatype for the object
  result = newStmtList()
  let typ = dtype.getTypeImpl
  doAssert typ.kind in {nnkObjectTy, nnkTupleTy}
  let implNode = if typ.kind == nnkObjectTy: typ[2] else: typ
  for ch in implNode:
    let nStr = ch[0].strVal
    let n = ch[0]
    result.add quote do:
      discard insertType(`res`, `nStr`, `n`, `dtype`)

proc nimToH5type*(dtype: typedesc): DatatypeID =
  ## given a typedesc, we return a corresponding
  ## H5 data type. This is a template, since we
  ## the compiler won't be able to determine
  ## the generic return type by the given typedesc
  ## inputs:
  ##    dtype: typedesc = a typedescription of the data type for the dataset
  ##          which we want to store
  ## outputs:
  ##    hid_t = the identifier int value of the HDF5 library for the data types

  # TODO: this still seems to be very much wrong and it's only valid for my machine
  # (64 bit) anyways.

  var res = -1.hid_t
  when dtype is int8:
    # for 8 bit int we take the STD LE one, since there is no
    # native type available (besides char)
    # TODO: are we doing this the correct way round? maybe only relevant, if
    # we read data, as the data is STORED in some byte order...!
    when cpuEndian == littleEndian:
      res = H5T_STD_I8LE
    else:
      res = H5T_STD_I8BE
  elif dtype is int16:
    res = H5T_NATIVE_SHORT
  elif dtype is int32:
    res = H5T_NATIVE_INT # H5T_STD_I32LE
  when sizeOf(int) == 8:
    if dtype is int:
      res = H5T_NATIVE_LONG
  else:
    if dtype is int:
      res = H5T_NATIVE_INT
  when dtype is int64:
    res = H5T_NATIVE_LONG
  elif dtype is uint8:
    # for 8 bit int we take the STD LE one, since there is no
    # native type available (besides char)
    when cpuEndian == littleEndian:
      res = H5T_STD_U8LE
    else:
      res = H5T_STD_U8BE
  elif dtype is uint16:
    res = H5T_NATIVE_USHORT
  elif dtype is uint32:
    res = H5T_NATIVE_UINT # H5T_STD_I32LE
  elif dtype is uint or dtype is uint64:
    res = H5T_NATIVE_ULLONG # H5T_STD_I64LE
  elif dtype is float32:
    res = H5T_NATIVE_FLOAT # H5T_STD_
  elif dtype is float or dtype is float64:
    res = H5T_NATIVE_DOUBLE # H5T_STD_
  elif dtype is char:
    # Nim's char is an unsigned char!
    res = H5T_NATIVE_UCHAR
  elif dtype is string:
    # NOTE: in case a string is desired, we still have to prepare it later, because
    # a normal string will end up as a sequence of characters otherwise. Instead
    # to get a continous string, need to set the size of the individual string
    # datatype (the result of this), to the size of the string and instead set
    # the size of the dataspace we reserve back to 1!
    # Also we need to copy the datatype, in order to be able to change its size
    # later
    res = H5Tcopy(H5T_C_S1)
    # -> call string_dataspace(str: string, dtype: hid_t) with
    # `result` as the second argument and the string you wish to
    # write as 1st after the call to this fn
  elif dtype is object or dtype is tuple:
    var tmpH5: dtype
    res = H5Tcreate(H5T_COMPOUND, sizeof(dtype).csize_t)
    walkObjectAndInsert(tmpH5, res)
  elif dtype is seq:
    res = special_type(getInnerType(dtype))
  result = res.DatatypeID

template anyTypeToString*(dtype: DtypeKind): string =
  ## return a datatype string from an DtypeKind object
  strip($dtype, chars = {'d', 'k'}).toLowerAscii

proc getDatasetType*(dset_id: DatasetID): DatatypeID =
  result = H5Dget_type(dset_id.hid_t).DatatypeID

proc getDtypeString*(dset_id: DatasetID): string =
  ## using a dataset id `dset_id`, return the name of the datatype by a call
  ## to the H5 library to get the datatype of that dataset
  result = anyTypeToString(h5ToNimType(dset_id.getDatasetType()))

proc parseH5rw_type*(rw_type: string, exists: bool): cuint =
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

template getH5rw_invalid_error*(): string =
  """
  The given r/w type is invalid. Make sure to use one of the following:
  - {'r', 'read'} = read access
  - {'w', 'write', 'rw'} =  read/write access
  """

proc getH5read_non_exist_file*(filename: string): string =
  result = &"Cannot open a non-existing file {filename} with read only access. Write " &
    "access will create the file for you."

template toH5vlen*[T](data: var seq[T]): untyped =
  when T is seq:
    mapIt(toSeq(0..data.high)) do:
      if data[it].len > 0:
        hvl_t(`len`: csize_t(data[it].len), p: addr(data[it][0]))
      else:
        hvl_t(`len`: csize_t(0), p: nil)
  else:
    # this doesn't make sense ?!...
    static:
      warning("T is " & T.name)
      warning("Cannot be converted to VLEN data!")
    #mapIt(toSeq(0 .. data.high), hvl_t(`len`: csize_t(data[it]), p: addr(data[it][0])))

proc vlenToSeq*[T](data: seq[hvl_t]): seq[seq[T]] =
  # converting the raw data from the C library to a Nim sequence is sort of ugly, but
  # here it goes...
  # number of elements we read
  result = newSeq[seq[T]](data.len)
  # iterate over every element of the pointer we have with data
  for i in 0 ..< data.len:
    let elem_len = data[i].len
    # create corresponding sequence for the size of this element
    result[i] = newSeq[T](elem_len)
    # now we need to cast the data, which is a pointer, to a ptr of an unchecked
    # array of our datatype
    let data_seq = cast[ptr UncheckedArray[T]](data[i].p)
    # now assign each element of the unckecked array to our sequence
    for j in 0 ..< elem_len:
      result[i][j] = data_seq[j]

proc isVariableString*(dtype: DatatypeID): bool =
  ## checks whether the datatype given by `hid_t` is in the string class of
  ## types and a variable length string.
  ## Returns true if the string is a variable length string, false if it's a
  ## static length string. Raises if it's neither a string (ValueError) or
  ## if the library call fails (HDF5LibraryError).
  let class = H5Tget_class(dtype.hid_t)
  if class != H5T_STRING:
    raise newException(ValueError, "Given `dtype` is not a string, but of class " &
      $class & "!")
  let res = H5Tis_variable_str(dtype.hid_t)
  if res < 0:
    raise newException(HDF5LibraryError, "Call to `H5Tis_variable_str` failed in " &
      "`isVariableString`!")
  result = res > 0
