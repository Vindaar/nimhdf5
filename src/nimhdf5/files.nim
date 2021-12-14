import tables
import strutils, sequtils
import options
import os

import hdf5_wrapper
import H5nimtypes
import datatypes
import dataspaces

# need to forward declare visit file, due to cyclic import statements
# files -> datasets -> groups -> files
# and
# files -> groups -> files
# so that proc is already known when we encounter the
# from files import visit_files statement in groups.nim

from datasets import `[]`, close
import attributes
from groups import create_group, `[]`, close
import h5util
import util

proc newH5File*(): H5FileObj =
  ## default constructor for a H5File object, for internal use
  let dset = newTable[string, H5DataSet]()
  let dspace = initTable[string, hid_t]()
  let groups = newTable[string, H5Group]()
  let attrs = newH5Attributes()
  result = H5FileObj(name: "",
                     file_id: H5_NOFILE,
                     rw_type: H5F_INVALID_RW,
                     err: -1,
                     status: -1.hid_t,
                     datasets: dset,
                     dataspaces: dspace,
                     groups: groups,
                     attrs: attrs)

proc nameFirstExistingParent(h5f: H5FileObj, name: string): string =
  ## similar to firstExistingParent, except that only the name of
  ## the object is returned
  discard

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

proc nameExistingObjectOrParent(h5f: H5FileObj, name: string): string =
  ## this procedure can be used to get the name of the given object
  ## or its first existing parent
  ## inputs:
  ##    h5f: H5FileObj = the file object in which to check the tables
  ##    name: string = name of the object to check for
  ## outputs:
  ##    string = the name of the given object (if it exists), or the
  ##          name of the first existing parent. If root is the only
  ##          existing object, empty string is returned
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

proc H5open*(name, rw_type: string): H5File =
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
      raise newException(IOError, getH5read_non_exist_file(name))
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
  result.attrs = initH5Attributes(result.file_id, "/", "H5FileObj")

proc H5file*(name, rw_type: string): H5File {.deprecated: "Use `H5open` instead of " &
    "H5file. The datatype was renamed from `H5FileObj` to `H5File`.".} =
  result = H5open(name, rw_type)

proc printOpenObjects*(h5f: H5FileObj) =
  let
    filesOpen = H5Fget_obj_count(h5f.file_id, H5F_OBJ_FILE)
    dsetsOpen = H5Fget_obj_count(h5f.file_id, H5F_OBJ_DATASET)
    groupsOpen = H5Fget_obj_count(h5f.file_id, H5F_OBJ_GROUP)
    typesOpen = H5Fget_obj_count(h5f.file_id, H5F_OBJ_DATATYPE)
    attrsOpen = H5Fget_obj_count(h5f.file_id, H5F_OBJ_ATTR)
  # always printing, regardless of debug
  echo "\t objects open:"
  echo "\t\t files open: ", filesOpen
  echo "\t\t dsets open: ", dsetsOpen
  echo "\t\t groups open: ", groupsOpen
  echo "\t\t types open: ", typesOpen
  echo "\t\t attrs open: ", attrsOpen

type
  ObjectKind* = enum
    okFile, okDset, okGroup, okType, okAttr, okAll

proc parseH5toObjectKind(h5Kind: int): ObjectKind =
  if h5Kind == H5F_OBJ_FILE:
    result = okFile
  elif h5Kind == H5F_OBJ_DATASET:
    result = okDset
  elif h5Kind == H5F_OBJ_GROUP:
    result = okGroup
  elif h5Kind == H5F_OBJ_DATATYPE:
    result = okType
  elif h5Kind == H5F_OBJ_ATTR:
    result = okAttr
  elif h5Kind == H5F_OBJ_ALL:
    result = okAll

proc parseObjectKindToH5(kind: ObjectKind): int =
  case kind
  of okFile:
    result = H5F_OBJ_FILE
  of okDset:
    result = H5F_OBJ_DATASET
  of okGroup:
    result = H5F_OBJ_GROUP
  of okType:
    result = H5F_OBJ_DATATYPE
  of okAttr:
    result = H5F_OBJ_ATTR
  of okAll:
    result = H5F_OBJ_ALL

proc getOpenObjectIds*(h5f: H5FileObj, kind: ObjectKind): seq[hid_t] =
  let h5Kind = parseObjectKindToH5(kind)
  # create buffer size of 1000. Should be plenty for open ids
  # if not, something is wrong anyways (I'd assume?)
  const maxObjects = 1000
  var objList = newSeq[hid_t](maxObjects)
  let objsOpen = H5Fget_obj_ids(h5f.file_id, h5Kind.cuint, 1000, addr objList[0])
  result = objList.filterIt(it > 0)

proc flush*(h5f: H5FileObj, flushKind: FlushKind = fkGlobal) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(h5f.file_id, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(h5f.file_id, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush file " & h5f.name &
      " as " & $flushKind & " failed!")

proc close*(id: hid_t, kind: ObjectKind): herr_t =
  ## calls the correct H5 `close` function for the given object kind
  case kind
  of okFile:
    result = H5Fclose(id)
  of okDset:
    result = H5Dclose(id)
  of okGroup:
    result = H5Gclose(id)
  of okAttr:
    result = H5Aclose(id)
  of okType:
    # no close function?
    discard
  of okAll:
    discard

proc close*(h5f: H5FileObj): herr_t =
  ## this procedure closes all known datasets, dataspaces, groups and the HDF5 file
  ## itself to clean up.
  ## The return value will be non negative if the closing was successful and negative
  ## otherwise.
  ## inputs:
  ##    h5f: H5FileObj = file object which to close
  ## outputs:
  ##    hid_t = status of the closing of the file
  # TODO: can we use iterate and H5Oclose to close all this stuff
  # somewhat cleaner?
  withDebug:
    echo "\n\nBefore closing: \n:"
    h5f.printOpenObjects()
    let objs = h5f.getOpenObjectIds(okAll)
    echo "Objects open are ", objs

  for name, dset in pairs(h5f.datasets):
    withDebug:
      echo("Closing dset ", name, " with dset id ", dset.dataset_id)
    # close attributes
    for attr in values(dset.attrs.attr_tab):
      attr.close()
    dset.close()

  for name, group in pairs(h5f.groups):
    withDebug:
      echo("Closing group ", name, " with id ", group.group_id)
    # close remaining attributes
    for attr in values(group.attrs.attr_tab):
      attr.close()
    group.close()

  # close remaining open attributes
  for attr in values(h5f.attrs.attr_tab):
    attr.close()

  withDebug:
    h5f.printOpenObjects()
  # now close all remaining objects, which we might have missed above
  # TODO: it seems we're missing some attributes. The rest is typically closed
  # find out where we miss them!
  for t in ObjectKind:
    let objsStillOpen = h5f.getOpenObjectIds(t)
    if objsStillOpen.len > 0:
      for id in objsStillOpen:
        # only close non files (file will be closed below)
        case t
        of okFile: discard
        else:
          result = close(id, t)

  withDebug:
    let objsYet = h5f.getOpenObjectIds(okAll)
    h5f.printOpenObjects()
    # should be zero now
    echo "Still open objects are ", objsYet

  # flush the file
  result = H5Fflush(h5f.file_id, H5F_SCOPE_GLOBAL)

  # close the remaining attributes
  result = H5Fclose(h5f.file_id)

template withH5*(h5file, rw_type: string, actions: untyped) =
  ## template to work with a H5 file, taking care of opening
  ## and closing the file
  ## injects the `h5f` variable into the calling space
  block:
    var h5f {.inject.} = H5File(h5file, rw_type)

    # perform actions with H5FileObj
    actions

    let err = h5f.close()
    if err != 0:
      echo "Closing of H5 file unsuccessful. Returned code ", err

proc getObjectIdByName(h5file: H5FileObj, name: string): hid_t =
  ## proc to retrieve the location ID of a H5 object based its relative path
  ## to the given id
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


# TODO: should this remain in files.nim?
proc create_hardlink*(h5file: H5FileObj, target: string, link_name: string) =
  ## proc to create hardlinks between pointing to an object `target`. Can be either a group
  ## or a dataset, defined by its name (full path!)
  ## the target has to exist, while the link_name must be free
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
