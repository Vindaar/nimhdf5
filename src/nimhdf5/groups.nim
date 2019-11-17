import tables
import options
import ospaths
import strutils

import hdf5_wrapper
import H5nimtypes
import datatypes
import attributes
import h5util
import util
#import datasets
#from h5util import `$`

# get visit_file from files.nim for dataset iterator
from files import visit_file

proc newH5Group*(name: string = ""): H5Group =
  ## default constructor for a H5Group object, for internal use
  let datasets = newTable[string, H5DataSet]()
  let groups = newTable[string, H5Group]()
  let attrs = newH5Attributes()
  result = new H5Group
  result.name = name
  result.parent = ""
  result.parent_id = -1.hid_t
  result.file = ""
  result.file_id = -1.hid_t
  result.file_ref = nil
  result.datasets = datasets
  result.groups = groups
  result.attrs = attrs

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
    result = some(h5f.groups[grp_name])

proc isGroup*(h5f: H5FileObj, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a group or not
  let target = formatName name
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_GROUP: true else: false

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
    group_known = hasKey(h5f.groups, group_name)
  var result: H5Group
  if group_known == false:
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
  result


template isGroup(h5_object: typed): bool =
  # procedure to check whether object is a H5Group
  result: bool = false
  if h5_object is H5Group:
    result = true
  else:
    result = false
  result

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

  # now that we have created the group fully (including IDs), we can add it
  # to the H5FileObj
  var grp = new H5Group
  grp = result
  withDebug:
    debugEcho "Adding element to h5f groups ", group_name
  h5f.groups[group_name] = grp
  grp.groups = h5f.groups


proc create_group*[T](h5f: T, group_name: string): H5Group =
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
      debugEcho "Group path is now ", group_path, " ", h5f.name
  else:
    let group_path = formatName group_name

  let exists = hasKey(h5f.groups, group_path)
  if exists == true:
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

template `[]`*(h5f: H5FileObj, name: grp_str): H5Group =
  # a simple wrapper around get for groups
  h5f.get(name)

# proc openGroupById(h5f: H5FileObj, locaction_id: hid_t, name: string): H5Group =
#   # proc which opens an existing group by its ID
#   var group = newH5Group(name)
#   group.group_id = H5Gopen2(locaction_id, name, H5P_DEFAULT)
#   group.parent = getParent(name)
#   group.parent_id = h5f.getParentId(group)
#   group.file = h5f.name
#   group.file_id = h5f.file_id
#   # create attributes field
#   group.attrs = initH5Attributes(group.name, group.group_id, "H5Group")


# let's try to implement some iterators for H5FileObj and H5Groups

# for H5Groups first implement relative create_group

iterator groups*(group: H5Group, start_path = ".", depth = 1): H5Group =
  ## iterator to return groups below the given group. By default we do not
  ## return groups in subgroups of the given ``group``
  ## NOTE: make sure the file is visited via `files.visit_file` before calling
  ## this iterator!
  var mstart_path = start_path
  # now make sure the start_path is properly formatted
  if start_path != ".":
    mstart_path = formatName start_path
  else:
    # else take this groups name as the starting path, since the table storing the
    # datasets uses full paths as keys!
    mstart_path = group.name
  # number of `/` in start path, needed to calculate at which
  # depth we are from start path
  let n_start = mstart_path.count('/')
  # now loop over all groups, checking for start_path in each group name
  for grp in keys(group.groups):
    if grp.startsWith(mstart_path) == true and grp != mstart_path:
      if depth != 0:
        let n_current = grp.count('/')
        if n_current - n_start > depth:
          # in this case continue without yielding
          continue
      yield group.groups[grp]

iterator items*(group: H5Group, start_path = "."): H5DataSet =
  ## iterator, which returns a non mutable dataset object starting from `start_path` in the
  ## H5 group
  ## TODO: currently start_path has no effect, unless it's the groups name, because
  ## group is only aware of all datasets directly in it, not of any subgroups
  ## -> need to iterate over subgroups and yield those group names as well!
  ## Note: many procs working on datasets need a mutable object!
  ## TODO: mutability often not needed in those procs.. change!
  ## inputs:
  ##    group: H5Group = the H5 group object, over which to iterate
  ##    start_path: string = optional starting location from which to iterate
  ##      default starts at location of group "."
  ## yields:
  ##    H5DataSet, which resides below `start_path`
  ## throws:
  ##    HDF5LibraryError = raised in case a call to the H5 library fails
  var mstart_path = start_path

  # TODO:
  # - iterate over subgroups
  #   - for each subgroup, we might call this proc?
  # - should we include recursive option? only if set iterate over all subgroups as well?
  #   could work together with start_path

  # first check whether we visited the whole file yet
  # how to do that for groups?
  #if h5f.visited == false:
  #  h5f.visit_file

  if group.file_ref.visited == false:
    # call visit file to get info about all groups and dsets
    visit_file(group.file_ref)

  # now make sure the start_path is properly formatted
  if start_path != ".":
    mstart_path = formatName start_path
  else:
    # else take this groups name as the starting path, since the table storing the
    # datasets uses full paths as keys!
    mstart_path = group.name

  # now loop over all groups, checking for start_path in each group name
  for dset in keys(group.datasets):
    if dset.startsWith(mstart_path) == true and dset != mstart_path:
      # means we're reading a fitting dataset, yield
      yield group.datasets[dset]
