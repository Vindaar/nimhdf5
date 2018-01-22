import tables
import options
import ospaths

import hdf5_wrapper
import H5nimtypes
import datatypes
import attributes
import h5util
import util
#import datasets
#from h5util import `$`

proc `$`*(dset: ref H5DataSet): string =
  result = dset.name

proc newH5Group*(name: string = ""): ref H5Group =
  ## default constructor for a H5Group object, for internal use
  let datasets = newTable[string, ref H5DataSet]()
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

  
template isGroup(h5_object: typed): bool =
  # procedure to check whether object is a H5Group
  result: bool = false
  if h5_object is H5Group:
    result = true
  else:
    result = false
  result

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

template `[]`*(h5f: H5FileObj, name: grp_str): H5Group =
  # a simple wrapper around get for groups
  h5f.get(name)

# proc openGroupById(h5f: H5FileObj, locaction_id: hid_t, name: string): ref H5Group =
#   # proc which opens an existing group by its ID
#   var group = newH5Group(name)
#   group.group_id = H5Gopen2(locaction_id, name, H5P_DEFAULT)
#   group.parent = getParent(name)
#   group.parent_id = h5f.getParentId(group)
#   group.file = h5f.name
#   group.file_id = h5f.file_id
#   # create attributes field
#   group.attrs = initH5Attributes(group.name, group.group_id, "H5Group")

