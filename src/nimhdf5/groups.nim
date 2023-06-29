import std / [tables, options, strutils]

import hdf5_wrapper, H5nimtypes, datatypes, attributes, h5util, util

when false:
  ## XXX: this was an attempt to add a non raising API, but I never finished it...
  proc getGroup(h5f: H5File, grp_name: string): Option[H5Group] =
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

proc openGroup*(h5f: H5File, group: string): GroupID =
  ## Opens the given `group` in the `h5f` file. Throws `KeyError` if the given
  ## group does not exist.
  if group in h5f and group in h5f.groups and h5f.groups[group].opened: # exists and is open
    # return id from table
    result = h5f.groups[group].group_id
  elif group in h5f: # exists, but not open. `file_id` is the relevant location id
    result = H5Gopen2(h5f.file_id.id, group.cstring, H5P_DEFAULT).toGroupID
    if result.id < 0:
      raise newException(HDF5LibraryError, "call to H5 library failed in " &
        "`createGroupFromParent` trying to open group via `H5Gopen2`!")
    withDebug:
      debugEcho "Group exists H5Gopen2() returned id ", result
  else:
    raise newException(KeyError, "Group with name `" & $group & "` does not " &
      "exist in file `" & $h5f.name & ".")

proc createGroupImpl*(h5f: H5File, group: string): GroupID =
  ## Creates the given group in the file.
  ##
  ## Does not perform any checks on whether the group exists in the file. If this
  ## proc is called for an existing proc, it may fail.
  withDebug:
    if group notin h5f:
      debugEcho "Group non existant, creating group ", group
    else:
      debugEcho "Calling `createGroup` despite ", group, " existing in file!"
  # group non existant, `file_id` is the relevant location id
  result = H5Gcreate2(h5f.file_id.id, group, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT).toGroupID
  if result.id < 0:
    raise newException(HDF5LibraryError, "call to H5 library failed in " &
      "`createGroupFromParent` trying to create group via `H5Gcreate2`!")


when false:
  ## XXX: this is still not properly implemented...
  proc updateGroupInfo(h5f: H5File, grp: var H5Group) =
    ## Updates all information of the given group `grp` by calling into the HDF5 library.
    ##
    ## Note: this procedure raises, if the given group does not yet exist in the
    ## file. Or should it not raise?
    # essentially the body of the below proc

proc createGroupFromParent[T: H5Group | H5File](h5o: T, group_name: string): H5Group =
  ## procedure to create a group within a H5F
  ## Note: this procedure requires that the parent of the group
  ## to create exists, while the group to be created does not!
  ## i.e. only call this function of you are certain of these two
  ## facts
  ## inputs:
  ##    h5o: H5FilObj = the file in which to create the group
  ##    group_name: string = the name of the group to be created
  ## outputs:
  ##    H5Group = returns a group object with the basic properties set
  let file_ref = h5o.getFileRef()
  let exists = group_name in h5o
  # since we know that the parent exists, we can simply use the (recursive!) getParentId
  # to get the id of the parent, without worrying about receiving a parent id of an
  # object, which is in reality not the actual parent
  let parent_id = getParentId(h5o, group_name)
  result = newH5Group(group_name, file_ref = file_ref,
                      parentID = parent_id)

  if exists:
    result.group_id = h5o.openGroup(group_name) # simply open the group
  else:
    result.group_id = h5o.createGroupImpl(group_name)
  result.opened = true # either we have raised or the group is now open

  # create attributes field
  result.attrs = initH5Attributes(ParentID(kind: okGroup,
                                           gid: result.group_id),
                                  result.name, "H5Group")
  result.groups[group_name] = result

  withDebug:
    debugEcho "Adding element to h5f groups ", group_name

proc open*[T: H5Group | H5File](h5o: T, group_name: grp_str) =
  ## Opens the given `group_name` and adds it to the table of opened groups.
  ##
  ## Raises `KeyError` if the given group does not exist.
  let file_ref = h5o.getFileRef()
  let name = formatName(groupName.string)
  let exists = name in h5o
  if exists and not h5o.isOpen(group_name):
    # since we know that the parent exists, we can simply use the (recursive!) getParentId
    # to get the id of the parent, without worrying about receiving a parent id of an
    # object, which is in reality not the actual parent
    let parent_id = getParentId(h5o, name)
    var group = newH5Group(name, file_ref = file_ref,
                           parentID = parent_id)
    group.group_id = h5o.openGroup(name) # simply open the group
    group.opened = true # either we have raised or the group is now open
    # create attributes field
    group.attrs = initH5Attributes(ParentID(kind: okGroup,
                                             gid: group.group_id),
                                    group.name, "H5Group")
    h5o.groups[name] = group
  elif not exists:
    raise newException(KeyError, "The group " & $(name) & " does " &
      "not exist in the file " & $(h5o.getFilename()) & ".")

#proc getGroup[T: H5Group | H5File](h5o: T, group_name: string): H5Group =

proc openAndGetGroup(h5f: H5File, name: string): H5Group =
  ## Opens and returns the group `name` if it exists in the HDF5 file.
  ##
  ## Throws a `KeyError` if it does not exist.
  let nameStr = formatName name
  h5f.open(nameStr.grp_str) # try to open (will fail if it does not exist)
  h5f.groups[nameStr]

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

  let exists = h5f.isGroup(group_path)
  if exists:
    result = h5f.openAndGetGroup(group_path) # just return it
  else:
    # we need to create it. But first check whether the parent
    # group already exists
    # whether such a group already exists
    # in the HDF5 file and h5f is simply not aware of it yet
    if isInH5Root(group_path) == false:
      discard create_group(h5f, getParent(group_path))
      result = createGroupFromParent(h5f, group_path)
    else:
      result = createGroupFromParent(h5f, group_path)

proc `[]`*(h5f: H5File, name: grp_str): H5Group =
  ## Opens and returns the group `name` if it exists in the HDF5 file.
  ##
  ## Throws a `KeyError` if it does not exist.
  h5f.openAndGetGroup(name.string)

proc getOrCreateGroup*(h5f: H5File, name: string): H5Group =
  ## Returns the group `name` if it exists in `h5f`. Else creates it.
  if h5f.isGroup(name):
    result = h5f[name.grp_str]
  else:
    result = h5f.create_group(name)
