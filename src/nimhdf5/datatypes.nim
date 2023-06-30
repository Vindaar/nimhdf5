import std / [strutils, tables, strformat, macros, typetraits]

import hdf5_wrapper, H5nimtypes, util
from type_utils import needsCopy, genCompatibleTuple, offsetStr, offsetTup, typeName


# add an invalid rw code to handle wrong inputs in parseH5rw_type
const H5F_INVALID_RW* = cuint(0x00FF)

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

  ## Controls the different options with which one can open files.
  AccessKind* = enum
    akRead = H5F_ACC_RDONLY          ## open for read only
    akReadWrite = H5F_ACC_RDWR       ## open for read and write. File can exist, will "append" to file
    akTruncate = H5F_ACC_TRUNC       ## overwrite existing files
    akExclusive = H5F_ACC_EXCL       ## open in read and write mode, but fail if file already exists
    akCreate = H5F_ACC_CREAT         ## create non-existing files;
                                     ## NOTE: I don't understand what this means. Apparently this is deprecated
    akWriteSWMR = H5F_ACC_SWMR_WRITE ## open file in SWMR mode as the writing process (see SWMR note in README)
    akReadSWMR = H5F_ACC_SWMR_READ   ## open file in SWMR mode as a reading process
    akInvalid = H5F_INVALID_RW       ## invalid opening mode (can appear as a return value)

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
    file_id*: FileId
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
    # stores the access flags (read, read/write, SWMR, ...)
    accessFlags*: set[AccessKind]
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
  # raised for generic exceptions in context of filters
  HDF5FilterError* = object of HDF5LibraryError
  # raised if decompression call fails
  HDF5DecompressionError* = object of HDF5FilterError

  # enum which determines how the given H5 object should be flushed
  # corresponds to the H5F_SCOPE flags
  FlushKind* = enum
    fkLocal, fkGlobal

  ## An enum that maps different H5 object kind values to more readable names
  ## Mainly these specify different objects that may be using `H5Fget_*` functions.
  ObjectKind* = enum
    okNone = 0,
    okFile = H5F_OBJ_FILE
    okDataset = H5F_OBJ_DATASET
    okGroup = H5F_OBJ_GROUP
    okType = H5F_OBJ_DATATYPE
    okAttr = H5F_OBJ_ATTR
    # okAll not needed anymore, as we will use a set
    okLocal = H5F_OBJ_LOCAL ## Restricts to objects opened via the given file ID and not
                            ## given file (opening a file twice yields different file IDs!)

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
    of okNone, okLocal: discard # all cannot be a parent

  ## `H5Id` is a wrapper around `hid_t` identifiers of the H5 library. By wrapping it
  ## in a `ref` we can use an RAII approach to closing identifiers once they go out
  ## of scope for us (which in 99% of the cases is what we want).
  CloseKind = enum
    ckFile, ckGroup, ckDataset, ckAttribute, ckDataspace, ckDatatype, ckProperty # ... the close function to call

  H5IdObj = object
    kind*: CloseKind
    id*: hid_t
  H5Id = ref H5IdObj

  FileID* = distinct H5Id
  DatasetID* = distinct H5Id
  GroupID* = distinct H5Id
  AttributeID* = distinct H5Id
  SomeH5ObjectID* = FileID | DatasetID | GroupID | AttributeID

  DatatypeID* = distinct H5Id
  DataspaceID* = distinct H5Id
  MemspaceId* = distinct H5Id
  HyperslabId* = distinct H5Id

  FileAccessPropertyListID* = distinct H5Id
  FileCreatePropertyListID* = distinct H5Id

  GroupAccessPropertyListID* = distinct H5Id
  GroupCreatePropertyListID* = distinct H5Id

  DatasetAccessPropertyListID* = distinct H5Id
  DatasetCreatePropertyListID* = distinct H5Id

  FilePropIds* = FileAccessPropertyListID | FileCreatePropertyListID
  GroupPropIds* = GroupAccessPropertyListID | GroupCreatePropertyListID
  DatasetPropIds* = DatasetAccessPropertyListID | DatasetCreatePropertyListID

  PropertyIDs* = FilePropIds | GroupPropIds | DatasetPropIds

  DspaceIDs* = DataspaceID | MemspaceID | HyperslabID

  AllH5Ids* = DatatypeID | DspaceIDs | PropertyIDs

const AllObjectKinds* = {okFile, okDataset, okGroup, okType, okAttr}

proc `$`*(x: hid_t): string {.borrow.}

proc `$`*(h5id: H5Id): string =
  result = "(kind: " & $h5id.kind & ", id: " & $h5id.id & ")"

proc close*(h5id: H5Id | H5IdObj, msg = "")
proc `=copy`*(target: var H5IdObj, source: H5IdObj) {.error: "H5Id identifiers cannot be copied.".}
proc `=destroy`*(h5id: var H5IdObj) = # {.error: "`=destroy` of a raw `H5Id` is not a valid operation.".}
  h5id.close()
  `=destroy`(h5id.kind)
  `=destroy`(h5id.id)

proc isValidID*(h5id: hid_t): bool
proc close*(h5id: H5Id | H5IdObj, msg = "") =
  ## calls the correct H5 `close` function for the given object kind
  ##
  ## Note: Ideally, this should not be used
  if h5id.id != 0.hid_t and h5id.id.isValidID():
    var err: herr_t
    case h5id.kind
    of ckFile:
      err = H5Fclose(h5id.id)
    of ckDataset:
      err = H5Dclose(h5id.id)
    of ckGroup:
      err = H5Gclose(h5id.id)
    of ckAttribute:
      err = H5Aclose(h5id.id)
    of ckDatatype:
      err = H5Tclose(h5id.id)
    of ckDataspace:
      err = H5Sclose(h5id.id)
    of ckProperty:
      err = H5Pclose(h5id.id)
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing " & $h5id & " of dataset!" & msg)

proc newH5Id(x: hid_t, kind: CloseKind): H5Id =
  result = H5Id(id: x, kind: kind)

template genHelpers(typ: untyped, k: untyped): untyped =
  ## in 1.6 still we cannot define a `ref type` destructor. There is some bug on devel *without this*
  ## that causes invalid `free()` calls :(
  when (NimMajor, NimMinor, NimPatch) > (1, 7, 0):
    proc `=destroy`*(x: typ) = `=destroy`(cast[H5Id](x))
  proc `new typ`*(x: hid_t): typ =
    result = typ(newH5Id(x, k))

  proc close*(x: typ, msg = "") = distinctBase(x).close(msg)
  template `to typ`*(x: hid_t): typ = `new typ`(x)
  template id*(x: typ): hid_t = distinctBase(x).id
  #converter toInt*(x: `typ Obj`): int = x.hid_t.int
  proc `$`*(x: typ): string = $typ & "(" & $id(x).int & ")"


genHelpers(FileID, ckFile)
genHelpers(GroupID, ckGroup)
genHelpers(DatasetID, ckDataset)
genHelpers(AttributeID, ckAttribute)

genHelpers(DatatypeID, ckDatatype)
genHelpers(DataspaceID, ckDataspace)
genHelpers(MemspaceID, ckDataspace)
func toMemspaceID*(x: DataspaceID): MemspaceID = MemspaceID(x)#.toMemspaceID
genHelpers(HyperslabID, ckDataspace)
template toHyperslabID*(x: DataspaceID): HyperslabID = HyperslabID(x)

genHelpers(FileAccessPropertyListID, ckProperty)
genHelpers(FileCreatePropertyListID, ckProperty)

genHelpers(GroupAccessPropertyListID, ckProperty)
genHelpers(GroupCreatePropertyListID, ckProperty)

genHelpers(DatasetAccessPropertyListID, ckProperty)
genHelpers(DatasetCreatePropertyListID, ckProperty)

func toH5*(flags: set[AccessKind]): cuint =
  ## Performs a bitwise `or` of all flags in the set to generate the correct
  ## value for the H5 library
  if flags.card == 0: return akInvalid.ord
  for fl in iterateEnumSet(flags):
    result = result or fl.ord.cuint

func toH5*(flags: set[ObjectKind]): cuint =
  ## Performs a bitwise `or` of all flags in the set to generate the correct
  ## value for the H5 library
  if flags.card == 0: return okNone.ord
  for fl in iterateEnumSet(flags):
    result = result or fl.ord.cuint

## NOTE: the following two `dataspace_id` procs ``*really*`` do not belong here. But the problem is
## we need them for `close` of `H5DataSet`. Those shouldn't be here either, but they are needed
## for `=destroy`, which must be here close to the type definition... This is a bit dumb.
proc dataspace_id*(dataset_id: DatasetID): DataspaceID {.inline.} =
  ## convenienve wrapper around H5Dget_space proc, which returns the dataspace
  ## id of the given dataset_id
  result = H5Dget_space(dataset_id.id).toDataspaceID()

proc dataspace_id*(dset: H5DataSet): DataspaceID =
  ## convenienve wrapper around H5Dget_space proc, which returns the dataspace
  ## id of the given dataset_id
  ## same as above, but works on the `H5DataSet` directly and gets the dataset
  ## id from it
  result = dset.dataset_id.dataspace_id

proc to_hid_t*(p: ParentID): hid_t =
  case p.kind
  of okFile: result = p.fid.id
  of okDataset: result = p.did.id
  of okGroup: result = p.gid.id
  of okType: result = p.typId.id
  of okAttr: result = p.attrId.id
  of okNone, okLocal:
    result = -1.hid_t

func getH5Id*[T: H5File | H5DataSet | H5DatasetObj | H5Group | H5GroupObj | H5Attr | H5AttrObj](h5o: T): ParentID =
  ## this func returns the ID of the given object as a `ParentID`
  ## of the correct kind.
  result = ParentID(kind: okNone)
  when h5o is H5File:
    if not h5o.fileId.distinctBase.isnil:
      result = ParentID(kind: okFile, fid: h5o.file_id)
  elif h5o is H5Group or h5o is H5GroupObj:
    if not h5o.groupId.distinctBase.isnil:
      result = ParentID(kind: okGroup, gid: h5o.group_id)
  elif h5o is H5DataSet or h5o is H5DatasetObj:
    if not h5o.datasetId.distinctBase.isnil:
      result = ParentID(kind: okDataset, did: h5o.dataset_id)
  elif h5o is H5AttrObj or h5o is H5Attr:
    if not h5o.attrId.distinctBase.isnil:
      result = ParentID(kind: okAttr, attrId: h5o.attr_id)
  else:
    {.error: "Invalid branch!".}

proc isValidID*(h5id: hid_t): bool =
  ## Determines whether the given ID is still valid.
  ##
  ## This procedure is valid for *any* H5 identifier, including attributes, dataspaces
  ## access property lists, etc.
  let err = H5Iis_valid(h5id)
  if err > 0:
    result = true
  elif err == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "Call to `H5Iis_valid` failed calling with identifier: " &
      $h5id)

proc isValidID*[T: AllH5Ids | AttributeID](h5id: T): bool =
  ## Determines whether the given ID is still valid.
  result = h5id.id.isValidID()

proc isValidID*(h5id: ParentID): bool {.inline.} =
  ## Determines whether the ID is still valid.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5id.to_hid_t.isValidID()

proc isValidID*[T: H5File | H5Group | H5GroupObj | H5Dataset | H5DatasetObj](h5o: T): bool {.inline.} =
  ## Determines whether the ID of the given object is still valid.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5o.getH5ID.isValidID()

proc getRefCount*(h5id: hid_t): int =
  ## Returns the reference count on the object associated with the given ID.
  ##
  ## This procedure is valid for *any* H5 identifier, including attributes, dataspaces
  ## access property lists, etc.
  if h5id.isValidID:
    result = H5Iget_ref(h5id).int

proc getRefCount*(h5id: ParentID): int {.inline.} =
  ## Returns the reference count on the object associated with the given ID.
  result = h5id.to_hid_t.getRefCount()

proc getRefCount*[T: H5File | H5Group | H5GroupObj | H5Dataset | H5DatasetObj](h5o: T): int {.inline.} =
  ## Returns the reference count on the object associated with the given ID.
  result = h5o.getH5ID.getRefCount()

proc isObjectOpen*(h5id: hid_t): bool =
  ## Determines whether the object associated with the given ID is still open.
  ##
  ## This procedure is valid for *any* H5 identifier, including attributes, dataspaces
  ## access property lists, etc.
  result = h5id.getRefCount() > 0

proc isObjectOpen*(h5id: ParentID): bool {.inline.} =
  ## Determines whether the object associated with the given `ParentID` still open.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5id.to_hid_t.isObjectOpen()

proc isObjectOpen*[T: H5File | H5Group | H5GroupObj | H5Dataset | H5DatasetObj | H5Attr | H5AttrObj](h5o: T): bool {.inline.} =
  ## Determines whether the given object is still open.
  ##
  ## See the docs of the overload taking a `hid_t` for more information.
  result = h5o.getH5ID.isObjectOpen()


proc getDatasetType*(dset_id: DatasetID): DatatypeID =
  result = H5Dget_type(dset_id.id).toDatatypeID

proc getNativeType*(dtype_id: DatatypeID): DatatypeID =
  result = H5Tget_native_type(dtype_id.id, H5T_DIR_ASCEND).toDatatypeID

proc getSuperType*(dtype_id: DatatypeID): DatatypeID =
  result = H5Tget_super(dtype_id.id).toDatatypeID

proc copyType*(typ: hid_t): DatatypeID =
  result = H5Tcopy(typ).toDatatypeID

proc close*(attr: var H5AttrObj) =
  ## closes the attribute and the corresponding dataspace
  if attr.isObjectOpen():
    attr.attr_dspace_id.close(msg = "Dataspace of attribute: " & $attr.attr_id)
    let err = H5Aclose(attr.attr_id.id)
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing attribute with id " &
        $(attr.attr_id.id) & "!")
    withDebug:
      echo "Closed attribute with status ", err
    attr.opened = false

proc close*(attr: H5Attr) = attr[].close()

proc flush*(group: H5Group, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(group.group_id.id, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(group.group_id.id, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush group " & group.name &
      " as " & $flushKind & " failed!")

proc close*(group: var H5GroupObj) =
  if group.isObjectOpen():
    let err = H5Gclose(group.group_id.id)
    if err != 0:
      raise newException(HDF5LibraryError, "Failed to close group " & group.name & "!")
    group.opened = false

proc close*(group: H5Group) = group[].close()

proc flush*(dset: H5DataSetObj, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(dset.dataset_id.id, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(dset.dataset_id.id, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush dataset " & dset.name &
      " as " & $flushKind & " failed!")

proc flush*(dset: H5DataSet, flushKind: FlushKind) = dset[].flush(flushKind)

proc close*(dset: var H5DataSetObj) =
  if dset.isObjectOpen():
    # close the dataset creation property list, important if filters are used
    dset.dcpl_id.close(msg = "dcpl associated with dataset: " & $dset.name)
    dset.dapl_id.close(msg = "dapl associated with dataset: " & $dset.name)
    withDebug:
      # by calling flush here, depending on the status of the library
      # this might be the place where the actual writing to file takes place
      echo "Flushing dataset during `close` of: ", dset.name
    ## XXX: Flushing is problematic it turns out
    #dset.flush(fkLocal) # flush the dataset before we close it, if refcount is exactly 1
    withDebug:
      echo "...done"
    ## TODO: is this ever required? Or on the other hand is it sane to have a `=destroy` hook
    ## that calls `close` on a dataspace when it goes out of scope?
    dset.dataset_id.dataspace_id().close(msg = "Dataspace associated with dataset: " & $dset.name)
    let err = H5Dclose(dset.dataset_id.id) # now the *actual* closing of the dataset
    if err < 0:
      raise newException(HDF5LibraryError, "Error closing dataset " & $(dset.name) & "!")
    dset.opened = false

proc close*(dset: H5DataSet) = dset[].close()

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
  proc `=destroy`*(attr: var H5AttrObj) =
    ## Closes the given attribute.
    attr.close()
    for name, field in fieldPairs(attr):
      when typeof(field).distinctBase() isnot H5Id:
        `=destroy`(field)
      else:
        if cast[pointer](field) != nil:
          `=destroy`(field)

  proc `=destroy`*(attrs: var H5AttributesObj) =
    ## Closes all attributes that are stored in this `H5Attributes` table.
    if attrs.attr_tab != nil:
      `=destroy`(attrs.attr_tab)
    for name, field in fieldPairs(attrs):
      when typeof(field).distinctBase() isnot H5Id:
        if name.normalize != "attrtab":
          `=destroy`(field)
      else:
        if cast[pointer](field) != nil:
          `=destroy`(field)

  proc `=destroy`*(dset: var H5DataSetObj) =
    ## Closes the dataset and resets all references to nil.
    dset.close() # closes its dataspace etc. as well
    dset.opened = false
    if dset.attrs != nil:
      `=destroy`(dset.attrs)
    for name, field in fieldPairs(dset):
      if name != "attrs":
        when typeof(field).distinctBase() is H5Id:
          if cast[pointer](field) != nil:
            `=destroy`(field)
        else:
          `=destroy`(field)


  proc `=destroy`*(grp: var H5GroupObj) =
    ## Closes the group and resets all references to nil.
    if grp.file_ref != nil:
      `=destroy`(grp.file_ref) # only destroy the `ref` to the file!
    grp.close()
    grp.opened = false
    if grp.datasets != nil:
      `=destroy`(grp.datasets)
    if grp.groups != nil:
      `=destroy`(grp.groups)
    if grp.attrs != nil:
      `=destroy`(grp.attrs)
    for name, field in fieldPairs(grp):
      when typeof(field).distinctBase() isnot H5Id:
        if name notin ["attrs", "groups", "datasets", "file_ref"]:
          `=destroy`(field)
      else:
        if cast[pointer](field) != nil:
          `=destroy`(field)

  when false:
    ## currently these are problematic, as we're allowed to just copy these IDs in Nim land,
    ## and for each copy going out of scope `=destroy` would be called. Can cause double free.
    ## We could wrap them in a `ref` or disallow `=copy`.
    ##
    ## The other issue is that while we can ask the H5 library for a reference count
    ## to only close in case of a single reference, the question is whether that is the
    ## desired behavior or not. I.e. if the first instance of an ID goes out of scope,
    ## should the ID be closed immediately?
    ## Alternatively we could define a `=copy` hook that increases the reference count
    ## to the dataspace id.
    proc `=copy`*(target: var DataspaceID, source: DataspaceID) {.error: "Dataspace identifiers cannot be copied.".}
    proc `=copy`*(target: var MemspaceID, source: MemspaceID) {.error: "Memspace identifiers cannot be copied.".}
    proc `=copy`*(target: var HyperslabID, source: HyperslabID) {.error: "Hyperslab identifiers cannot be copied.".}

    proc `=destroy`*(dspace_id: var DataspaceID) =
      ## Closes the dataspace when it goes out of scope
      dspace_id.close()

    proc `=destroy`*(mspace_id: var MemspaceID) =
      ## Closes the memspace when it goes out of scope
      mspace_id.close()

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

proc initH5Attributes*(p_id: sink ParentID, p_name: string = "", p_type: string = ""): H5Attributes =
  let attr = newTable[string, H5Attr]()
  doAssert p_id.kind notin {okNone, okLocal}, "parent id must exist!"
  var h5attr = H5Attributes(attr_tab: attr,
                            num_attrs: -1,
                            parent_name: p_name,
                            parent_id: p_id,
                            parent_type: p_type)
  h5attr.num_attrs = h5attr.getNumAttrs
  # read_all_attributes(h5attr)
  result = h5attr

proc newH5Attr*(): H5Attr = H5Attr(opened: false)
proc newH5DataSet*(name: string = "",
                   file: string = "",
                   file_id: FileID = -1.hid_t.toFileId(),
                   parent: string = "",
                   parentID: sink ParentID = ParentID(kind: okNone),
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
  result.dtype_c = -1.hid_t.toDatatypeID
  result.parent = parent
  result.parentID = parentID
  result.file = file
  result.file_id = file_id
  result.dataset_id = -1.hid_t.toDatasetID()
  result.all = RW_ALL
  result.shape = shape
  result.attrs = attrs

proc newH5Group*(name: string = "",
                 file_ref: H5File = nil,
                 parentID: sink ParentID = ParentID(kind: okNone)): H5Group =
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
  result.group_id = -1.hid_t.toGroupId()
  if file_ref.isNil:
    result.file = ""
    result.file_id = -1.hid_t.toFileID()
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

macro isAnyArray(dtype: typed, innerDtype: typed): untyped =
  ## Returns `true` if the given type is an *array* (not a seq!) of type `innerDtype`
  ## of any size.
  doAssert dtype.typeKind == ntyTypeDesc
  let typ = dtype.getType
  result = newLit false
  if typ[1].kind == nnkBracketExpr:
    let arTyp = typ[1]
    if arTyp[0].strVal == "array":
      if arTyp[1].kind == nnkBracketExpr:
        let innerTyp = arTyp[arTyp.len-1]
        if innerTyp.strVal == innerDtype.strVal:
          result = newLit true

proc getArraySize[N: static int; T](ar: typedesc[array[N, T]]): int = N

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
  of dkString:
    when isAnyArray(dtype, char) or dtype is string:
      result = true
    elif dtype is cstring:
      result = true
    else:
      result = false
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
  let dtypeHid_t = dtype_id.id
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
      "$# of class $#" % [$(dtype_id.id), $(H5Tget_class(dtypeHid_t))])

proc nimToH5type*(dtype: typedesc, variableString = false, parentCopies: static bool = false): DatatypeID
proc special_type*(dtype: typedesc): DatatypeID =
  ## calls the H5Tvlen_create() to create a special datatype
  ## for variable length data
  ## XXX: I *think* `parentCopies` is not needed here. The types need to be copied anyway!
  when dtype isnot string:
    result = H5Tvlen_create(nimToH5type(dtype).id).toDatatypeID
  elif dtype is string:
    let strType = nimToH5type(dtype, variableString = true).id
    result = H5Tvlen_create(strType).toDatatypeID
  else:
    {.error: """To read/write a string as variable length data, treat it
as a `char` dataset, i.e. `special_type(char)` during construction. Writing a `seq[string]`
will work as expected. However, better simply create a regular dataset of type string
`special_type` call, i.e. a '1D string' dataset.\n

```nim
let size = ... # some int size
var dset = h5f.create_dataset("foo", size, special_type(char))
dset[dset.all] = bar # some @["hello", "world", ...] `seq[string]`
# or better
var dset = h5f.create_dataset("foo", size, string)
dset[dset.all] = bar # some @["hello", "world", ...] `seq[string]`
```

Also see the `twrite_string.nim` test case.
""".}
template insertType(res, nameStr, offset, fieldTyp, variableStr, parentCopies: untyped): untyped =
  when false: # fieldTyp is string:
    let startOffset = offset.csize_tn
    H5Tinsert(res, "len".cstring, startOffset, nimToH5type(fieldTyp, variableStr, parentCopies).id)
  else:
    H5Tinsert(res, nameStr.cstring, offset.csize_t, nimToH5type(fieldTyp, variableStr, parentCopies).id)

proc walkObjectAndInsert[T](_: typedesc[T],
                            parentCopies: static bool): hid_t =
  ## simple macro similar to `fieldPairs` which walks an object type. It creates
  ## an `discard insertType(`res`, `nStr`, `n`, `dtype`)` line for each field
  ## in an object to construct a compound datatype for the object

  # Determine if we need to copy: either parent was already copied, then we do too
  # (e.g. tuple like `(int, string, (float32, int))`. Outer tuple needs copy, inner `(float, int)`
  # does not. Still treat it as such.
  const NeedsCopy = T.needsCopy() or parentCopies

  when NeedsCopy:
    var tmpAlign: genCompatibleTuple(T, replaceVlen = true)
    let size = sizeOf(typeof(tmpAlign))
  else:
    let size = sizeOf(T) # use custom size of calc to handle field sizes as expected by H5

  result = H5Tcreate(H5T_COMPOUND, size.csize_t)
  var offset = 0
  var tmp: T = default(T)
  for field, val in fieldPairs(tmp):
    when NeedsCopy: # use tuple based offset logic
      offset = offsetTup(tmpAlign, field)
    else: # if type won't be copied, use `offsetOf` logic
      when T is object:
        offset = offsetStr(T, field)
      elif T is tuple:
        offset = offsetTup(tmp, field)
      else:
        {.error: "Invalid type: " & $T.}
    let err = insertType(result, field, offset, typeof(val), true, NeedsCopy)
    if err < 0:
      raise newException(Defect, "Could not insert type " & $typeof(val) & " into H5 compound type for full type " & typeName(T))

proc nimToH5type*(dtype: typedesc, variableString = false,
                  parentCopies: static bool = false): DatatypeID =
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

  result = newDatatypeID(-1.hid_t)
  when dtype is SomeInteger:
    when dtype is int8:
      # for 8 bit int we take the STD LE one, since there is no
      # native type available (besides char)
      # TODO: are we doing this the correct way round? maybe only relevant, if
      # we read data, as the data is STORED in some byte order...!
      when cpuEndian == littleEndian:
        result = H5T_STD_I8LE.toDatatypeID()
      else:
        result = H5T_STD_I8BE.toDatatypeID()
    elif dtype is int16:
      result = H5T_NATIVE_SHORT.toDatatypeID()
    elif dtype is int32:
      result = H5T_NATIVE_INT.toDatatypeID() # H5T_STD_I32LE
    when sizeOf(int) == 8:
      if dtype is int:
        result = H5T_NATIVE_LONG.toDatatypeID()
    else:
      if dtype is int:
        result = H5T_NATIVE_INT.toDatatypeID()
    when dtype is int64:
      result = H5T_NATIVE_LONG.toDatatypeID()
    elif dtype is uint8:
      # for 8 bit int we take the STD LE one, since there is no
      # native type available (besides char)
      when cpuEndian == littleEndian:
        result = H5T_STD_U8LE.toDatatypeID()
      else:
        result = H5T_STD_U8BE.toDatatypeID()
    elif dtype is uint16:
      result = H5T_NATIVE_USHORT.toDatatypeID()
    elif dtype is uint32:
      result = H5T_NATIVE_UINT.toDatatypeID() # H5T_STD_I32LE
    elif dtype is uint or dtype is uint64:
      result = H5T_NATIVE_ULLONG.toDatatypeID() # H5T_STD_I64LE
  elif dtype is float32:
    result = H5T_NATIVE_FLOAT.toDatatypeID() # H5T_STD_
  elif dtype is float or dtype is float64:
    result = H5T_NATIVE_DOUBLE.toDatatypeID() # H5T_STD_
  elif dtype is char:
    # Nim's char is an unsigned char!
    result = H5T_NATIVE_UCHAR.toDatatypeID()
  elif isAnyArray(dtype, char): ## check if `dtype` is any `array[N, char]`
    result = copyType(H5T_C_S1)
    # now get the size of the `array` and set it accordingly
    if H5Tset_size(result.id, getArraySize(dtype).csize_t) < 0:
      raise newException(HDF5LibraryError, "Call to `H5Tset_size` attempting to set " &
        "fixed length string size to " & $getArraySize(dtype) & " failed.")
  elif dtype is string | ptr char:
    # NOTE: in case a string is desired, we still have to prepare it later, because
    # a normal string will end up as a sequence of characters otherwise. Instead
    # to get a continous string, need to set the size of the individual string
    # datatype (the result of this), to the size of the string and instead set
    # the size of the dataspace we reserve back to 1!
    # Also we need to copy the datatype, in order to be able to change its size
    # later
    result = copyType(H5T_C_S1)
    if variableString:
      ## Instead of the above comment, generate a variable length string. This is used to
      ## write a dataset of type `string`.
      if H5Tset_size(result.id, H5T_VARIABLE) < 0:
        raise newException(HDF5LibraryError, "Call to H5Tset_size` attempting to define " &
          "a variable length string failed.")
    # -> call string_dataspace(str: string, dtype: hid_t) with
    # `result` as the second argument and the string you wish to
    # write as 1st after the call to this fn
  elif dtype is object or dtype is tuple:
    result = walkObjectAndInsert(dtype, parentCopies).toDatatypeID
  elif dtype is seq:
    result = special_type(getInnerType(dtype)) ## NOTE: back conversion to hid_t
  elif dtype is bool:
    when sizeof(bool) == 1:
      result = H5T_NATIVE_UCHAR.toDatatypeID()
    else:
      ## XXX: handle bool IN OTHER CASES
      raise newException(ValueError, "Boolean types cannot be stored in HDF5 yet unless it is of size 1 byte.")
  elif dtype is distinct:
    return nimToH5Type(distinctBase(dtype), variableString, parentCopies)
  else:
    {.error: "Invalid type `" & $dtype & "` for `nimToH5Type`.".}

template anyTypeToString*(dtype: DtypeKind): string =
  ## return a datatype string from an DtypeKind object
  strip($dtype, chars = {'d', 'k'}).toLowerAscii

proc getDtypeString*(dset_id: DatasetID): string =
  ## using a dataset id `dset_id`, return the name of the datatype by a call
  ## to the H5 library to get the datatype of that dataset
  result = anyTypeToString(h5ToNimType(dset_id.getDatasetType()))

## XXX: in addition to SWMR opening flag there is the proc
## ` H5Fstart_swmr_write()`
## which apparently can be used to activate it after the file has been opened
## already!

proc parseH5rwType*(rwType: string, exists: bool,
                    swmr: bool = false): set[AccessKind] =
  ## this proc simply acts as a parser for the read/write
  ## type string handed to the H5file() proc.
  ## inputs:
  ##    rwType: string = the identifier string, which sets the
  ##            read / write options for a HDF5 file
  ##    exits: bool = a bool to tell whether the file for which
  ##          we need to parse r/w already exists. Changes
  ##          potential return values
  ##    swmr: bool = determines whether we open the file in Single Writer /
  ##          Multiple Reader (SWMR) mode.
  ## outputs:
  ##    cuint = returns a C uint, since that is the datatype of
  ##            the constans defined in H5Fpublic.nim. These can be
  ##            handed directly to the low level C functions
  ## throws:
  ##
  if rwType == "w" or
     rwType == "rw" or
     rwType == "write":
    if exists and swmr:
      result = {akReadWrite, akWriteSWMR}
    elif exists:
      result = {akReadWrite}
    else:
      result = {akExclusive} # open in exclusive mode to make sure our notion of `exists` doesn't cause
                             # data loss
  elif rwType == "r" or
       rwType == "read":
    if swmr:
      result = {akRead, akReadSWMR}
    else:
      result = {akRead}
  else:
    result = {akInvalid}

template getH5rw_invalid_error*(): string =
  """
  The given r/w type is invalid. Make sure to use one of the following:
  - {'r', 'read'} = read access
  - {'w', 'write', 'rw'} =  read/write access

  """

proc getH5read_non_exist_file*(filename: string): string =
  result = &"Cannot open a non-existing file {filename} with read only access. Write " &
    "access will create the file for you."

proc isVariableString*(dtype: DatatypeID): bool =
  ## checks whether the datatype given by `hid_t` is in the string class of
  ## types and a variable length string.
  ## Returns true if the string is a variable length string, false if it's a
  ## static length string. Raises if it's neither a string (ValueError) or
  ## if the library call fails (HDF5LibraryError).
  let class = H5Tget_class(dtype.id)
  if class != H5T_STRING:
    raise newException(ValueError, "Given `dtype` is not a string, but of class " &
      $class & "!")
  let res = H5Tis_variable_str(dtype.id)
  if res < 0:
    raise newException(HDF5LibraryError, "Call to `H5Tis_variable_str` failed in " &
      "`isVariableString`!")
  result = res > 0
