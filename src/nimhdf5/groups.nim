proc flush*(group: H5Group, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(group.group_id, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(group.group_id, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush group " & group.name &
      " as " & $flushKind & " failed!")

proc close*(group: H5Group) =
  if group.opened:
    let err = H5Gclose(group.group_id)
    if err != 0:
      raise newException(HDF5LibraryError, "Failed to close group " & group.name & "!")
    group.opened = false

proc getGroup(h5f: H5FileObj, grp_name: string): Option[H5Group] =
import std / [tables, options, strutils]

import hdf5_wrapper, H5nimtypes, datatypes, attributes, h5util, util

  ## convenience proc to return the group with name grp_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5File = the file object from which to get the group
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
    result = some(h5f.groups[grp_name])

proc create_group*[T](h5f: T, group_name: string): H5Group
proc get(h5f: H5File, group_in: grp_str): H5Group =
  ## convenience proc to return the group with name group_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5File = the file object from which to get the dset
  ##    obj_name: string = name of the dset to get
  ## outputs:
  ##    H5Group = if group is found
  ## throws:
  ##    KeyError: if group could not be found
  let
    group_name = string(group_in)
    group_open = h5f.isOpen(group_in)
  if not group_open:
    # if group not known (potentially the case if:
    # - no call to visit_file (read all grps / dsets)
    # - not created individually directly / indirectly
    # check for existence in file
    let exists = existsInFile(h5f.file_id, group_name)
    if exists > hid_t(0):
      # get group from file
      result = h5f.create_group(group_name)
    else:
      # does not exists, raise exception
      raise newException(KeyError, "Group with name: " & group_name & " not found in file " & h5f.name)
  else:
    result = h5f.groups[group_name]
    doAssert result.opened

func isGroup[T: H5File | H5Group | H5DataSet](h5_object: T): bool =
  # procedure to check whether object is a H5Group
  if h5_object is H5Group:
    result = true
  else:
    result = false

proc createGroupFromParent[T](h5f: T, group_name: string): H5Group =
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
  result = newH5Group(group_name)
  # the location id (id of group or the root) at which to create the group
  let location_id = h5f.file_id
  let exists = location_id.existsInFile(result.name)

  # set the parent name
  result.parent = getParent(result.name)

  if exists > 0:
    # group exists, open it
    result.group_id = H5Gopen2(location_id, result.name, H5P_DEFAULT)
    if result.group_id < 0:
      raise newException(HDF5LibraryError, "call to H5 library failed in " &
        "`createGroupFromParent` trying to open group via `H5Gopen2`!")
    withDebug:
      debugEcho "Group exists H5Gopen2() returned id ", result.group_id
  elif exists == 0:
    withDebug:
      debugEcho "Group non existant, creating group ", result.name
    # group non existant, create
    result.group_id = H5Gcreate2(location_id, result.name, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
    if result.group_id < 0:
      raise newException(HDF5LibraryError, "call to H5 library failed in " &
        "`createGroupFromParent` trying to create group via `H5Gcreate2`!")
  else:
    raise newException(HDF5LibraryError, "call to H5 library failed in " &
      "`createGroupFromParent` trying to create group: " & group_name &
      ". Such a group exists? " & $exists)
  result.opened = true # either we have raised or the group is now open
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
  result.attrs = initH5Attributes(result.group_id, result.name, "H5Group")

  # finally add reference to H5FileObj to group
  when h5f is H5FileObj:
    # if called by file obj itself, create new reference and
    # assign that to file reference
    var h5ref = new H5FileObj
    h5ref = h5f
    result.file_ref = h5ref
  else:
    # else use the ref of the parent creating this object
    result.file_ref = h5f.file_ref

  withDebug:
    debugEcho "Adding element to h5f groups ", group_name
  h5f.groups[result.name] = result
  result.groups = h5f.groups
  result.datasets = h5f.datasets

proc create_group*[T](h5f: T, group_name: string): H5Group =
  ## checks whether the given group name already exists or not.
  ## If yes:
  ##   return the H5Group object,
  ## else:
  ##   check the parent of that group recursively as well.
  ##   If parent exists:
  ##     create new group and return it
  ## inputs:
  ##    h5f: H5File = the h5f file object in which to look for the group
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
      debugEcho "Group path is now ", group_path, " ", h5f.name
  else:
    let group_path = formatName group_name

  let isOpen = h5f.isOpen(group_path.grp_str)
  if isOpen:
    # then we return the object
    result = h5f.groups[group_path]
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

proc `[]`*(h5f: H5File, name: grp_str): H5Group =
  # a simple wrapper around get for groups
  h5f.get(name)

# proc openGroupById(h5f: H5File, locaction_id: hid_t, name: string): H5Group =
#   # proc which opens an existing group by its ID
#   var group = newH5Group(name)
#   group.group_id = H5Gopen2(locaction_id, name, H5P_DEFAULT)
#   group.parent = getParent(name)
#   group.parent_id = h5f.getParentId(group)
#   group.file = h5f.name
#   group.file_id = h5f.file_id
#   # create attributes field
#   group.attrs = initH5Attributes(group.name, group.group_id, "H5Group")


# let's try to implement some iterators for H5File and H5Groups

# for H5Groups first implement relative create_group
