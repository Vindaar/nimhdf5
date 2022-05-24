# the procs contained in here are utility procs, which are used
# within the high-level bindings to the H5 library.
# In contrast to the procs defined in util.nim, these procs here
# specifically deal with H5 related datatypes.
# In other cases procs are included for objects / types etc. where
# it is not (yet) warranted to have an individual file for, e.g.
# procs related to general H5 objects.

import std / [strutils, strformat, options, tables, sequtils]
from os import `/`, parentDir, extractFilename

# nimhdf5 related libraries
import hdf5_wrapper, H5nimtypes, util, datatypes

proc contains*(h5f: H5File, name: string): bool
proc contains*(grp: H5Group, name: string): bool
proc getObjectTypeByName*(h5id: FileID | GroupID | DatasetID, name: string): H5O_type_t

proc addH5Object*(location_id: hid_t, name_c: cstring, h5info: H5O_info_t, h5f_p: pointer): herr_t {.cdecl.} =
  ## similar proc to processH5ObjectFromRoot, except we do /not/ start at root
  ## important distinction to be able to deal with the root group itself
  ## Does this make sense? If '.' is handed to us on first call to H5Ovisit anyways,
  ## do we ever want to add the object at point? Should this not always already
  ## be part of the h5 object, or rather even if it is not, adding it will be
  ## difficult anyways, because we only have the location id. Well, we can
  ## simply open the object then and there, I suppose...
  ## NEED a proper openObjectById function...!
  discard

proc addH5ObjectFromRoot*(location_id: hid_t, name_c: cstring, h5info: H5O_info_t, h5f_p: pointer): herr_t {.cdecl.} =
  ## this proc is called for each object iterated over in visitFile.
  ## we basically just extract the information we want to have from the
  ## h5info struct and add it to the h5f file object. Needs to be
  ## a pointer here, since it's handed to C
  ## this proc is only called in the case where the start from the root group
  doAssert not h5f_p.isNil, "Memory corruption detected. Pointer to H5 file is nil!" # this should really never happen
  # cast the H5File pointer back
  var h5f = cast[H5File](h5f_p)
  if name_c == ".":
    # in case the location is `.`, we are simply at our starting point (currently
    # means root group), we don't want to do anything here, so continue
    result = 0
  else:
    let name = formatName($name_c)
    if h5info.`type` == H5O_TYPE_GROUP:
      h5f.groups[name] = newH5Group(name)
    elif h5info.`type` == H5O_TYPE_DATASET:
      h5f.datasets[name] = newH5Dataset(name)

proc visit_file*(h5f: H5File, h5id: hid_t = 0.hid_t) =
  ## this proc iterates over the whole file and reads the complete content
  ## optionally only visits all elements below hid_t
  ## H5Ovisit recursively visits any object (group or dataset + a couple specific
  ## types) and calls a callback function. Depending on the return value of that
  ## callback function, it either continues (proc returns 0), stops early and
  ## returns the value of the callback (proc returns value > 0), stops early
  ## and returns error (proc returns value < 0)
  ## inputs:
  ##   h5f: H5File = file object, which will be visited. The
  ##     object's group information will be updated.
  ##   name: string = name of the starting location from which to visit the file
  ##   h5id: hid_t = optional identifier id, from which to start visiting the
  ##     file
  ## throws:
  ##   IOError: in case the object visit fails. This is most likely due to
  ##     a corrupted H5 file.
  # TODO: add version which uses `name` as a starting location?
  # TODO: write an iterator which makes use of this?
  var err: herr_t
  if h5id != 0:
    err = H5Ovisit(h5id, H5_INDEX_NAME, H5_ITER_NATIVE,
                   cast[H5O_iterate_t](addH5Object),
                   cast[pointer](h5f))
  else:
    err = H5Ovisit(h5f.file_id.hid_t, H5_INDEX_NAME, H5_ITER_NATIVE,
                   cast[H5O_iterate_t](addH5ObjectFromRoot),
                   cast[pointer](h5f))
  if err < 0:
    raise newException(IOError, "Visiting the H5 file failed with an error." &
      "File is possibly corrupted. See the H5 stacktrace.")
  # now set visited flag
  h5f.visited = true

#proc contains*[T: (H5File | H5Group)](h5f: T, name: string): bool =
#  ## proc to check whehther an element named `name` is contained in the
#  ## HDF5 file. Checks for both groups and datasets!
#  ## For groups either a full path or a relative path (relative to the name
#  ## of the group on which `contains` is called) is possible. Note that
#  ## lookups with a depth of more than 1 (subgroups or datasets of groups
#  ## in the group we check) is currently not supported. Call on H5File
#  ## instead.
#  ## Note: we first check for the existence of a group of this name,
#  ## and only if no group of `name` is found, do we check the dataset names
#  ## inputs:
#  ##   h5f: H5File = H5 file to check
#  ##   name: string = the name of the dataset / group to check
#  ## outputs:
#  ##   bool = true if contained, false else
#  ## throws:
#  ##   HDF5LibraryError = in case the call to visit_file fails (only called
#  ##     if the file wasn't visited before)
#
#  # if file not visited yet, do that now
#  when T is H5File:
#    if h5f.visited == false:
#      h5f.visit_file
#  else:
#    if h5f.file_ref.visited == false:
#      visit_file(h5f.file_ref)
#
#  result = false
#  if name in h5f.groups:
#    result = true
#  else:
#    # if no group of said name, check datasets
#    if name in h5f.datasets:
#      result = true
#
#  if result == false:
#    # in case we're checking a group, we should also check whether the given name
#    # is relative to this groups basename
#    when T is H5Group:
#      # check whether `name` contains h5f's name
#      if h5f.name notin name:
#        # then create full name and call this proc again
#        let full_name = h5f.name / name
#        result = h5f.contains(full_name)

proc isOpen*(h5f: H5File, name: dset_str): bool =
  ## returns if the given dataset is known and open. Returns false
  ## both if the dataset is not known as well as if it's known but closed.
  let n = name.string
  result = if h5f.datasets.hasKey(n): h5f.datasets[n].opened
           else: false

proc isOpen*[T: H5Group | H5File](h5o: T, name: grp_str): bool =
  ## returns if the given group is known and open. Returns false
  ## both if the group is not known as well as if it's known but closed.
  let n = name.string
  when T is H5Group:
    let h5f = h5o.file_ref
  else:
    let h5f = h5o
  result = if h5f.groups.hasKey(n): h5f.groups[n].opened
           else: false

proc isDataset*(h5f: H5File, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a dataset or not
  let target = formatName name
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_DATASET: true else: false

proc isGroup*(h5f: H5File, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a group or not
  let target = formatName name
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_GROUP: true else: false

proc getFilename*[T: H5Group | H5File](h5o: T): string =
  ## Returns the filename of the file the group is in / the name of the given file.
  when T is H5Group:
    result = h5o.file
  else:
    result = h5o.name

proc getFileRef*[T: H5Group | H5File](h5o: T): H5File =
  ## Returns the file ref of the given group or the file itself
  when T is H5Group:
    result = h5o.file_ref
  else:
    result = h5o

proc isInH5Root*(name: string): bool =
  ## this procedure returns whether the given group or dataset is in a group
  ## or in the root of the HDF5 file.
  ## NOTE: make sure the name is a formated string via formatName!
  ##       otherwise the result may be completely wrong
  let n_slash = count(name, '/')
  assert n_slash > 0
  if n_slash > 1:
    result = false
  elif n_slash == 1:
    result = true

proc existsInFile*(h5id: FileID, name: string): hid_t =
  ## convenience function to check whether a given object `name` exists
  ## in another H5 object given by the id `h5id`
  if name == "/":
    # the root group always exists, hence return early
    return 1.hid_t
  # NOTE: we have to make sure to only check for existence up to one level
  # below what exists, i.e. we have to check iteratively for existence of
  # `name`. E.g. checking for
  # "/group/nested/dset"
  # is invalid if `nested` does not exist!
  # https://support.hdfgroup.org/HDF5/doc/RM/RM_H5L.html#Link-Exists
  let target = formatName name
  var toCheck: string
  for part in split(target, '/'):
    if part.len > 0:
      toCheck = toCheck / part
    else:
      continue
    # need to convert result of H5Lexists to hid_t, because return type is
    # `htri_t` from the H5 wrapper
    result = H5Lexists(h5id.hid_t, toCheck.cstring, H5P_DEFAULT).hid_t
    if result == 0:
      # does not exist, so break, even if we're not at the deepest level
      break
    elif result < 0:
      raise newException(HDF5LibraryError, "Call to `H5Lexists` failed " &
        "in `existsFile`!")

proc firstExistingParent*[T](h5f: T, name: string): Option[H5Group] =
  ## proc to find the first existing parent of a given object in H5F
  ## recursively
  ## inputs:
  ##    h5f: H5File: the object in which to look for the parent
  ##    name: string: name of object from which to start looking upwards
  ## outputs:
  ##    Option[H5Group] = if an existing H5Group is found recursively an
  ##      optional type is returned with some(result), while none(H5Group)
  ##      is returned in case the root is the first existing parent
  if name != "/":
    # in this case we're not at the root, so check whether name exists
    let exists = hasKey(h5f.groups, name)
    if exists == true:
      result = some(h5f.groups[name])
    else:
      result = firstExistingParent(h5f, getParent(name))
  else:
    # no parent found, first existing parent is root
    result = none(H5Group)

proc getParentId*[T: (H5File | H5Group)](h5f: T, name: string): ParentID =
  ## returns the id of the first existing parent of `name` contained in the file
  ## or group `h5f` (f refers to the fact that the object contains the file id
  ## inputs:
  ##  h5f: (H5File | H5Group) = any object that contains the file_id in which
  ##    the `h5o` is contained
  ##  name: Name to check the parent for.
  ## outputs:
  ##   hid_t = object id of the parent or the file id, if no parent exists besides
  ##     the file root
  let p = firstExistingParent(h5f, name)
  if isSome(p) == true:
    result = getH5Id(unsafeGet(p))
  else:
    # this means the only existing parent is root
    result = ParentID(kind: okFile, fid: h5f.file_id)

proc getParentId*[T: (H5File | H5Group), U: (H5DataSet | H5Group)](h5f: T, h5o: U): ParentID =
  ## Overload of `getParentID` taking a `string` for the second argument for convenience when
  ## already having a dataset or group.
  result = getParentID(h5f, h5o.name)

proc getObjectTypeByName*(h5id: FileID | GroupID | DatasetID, name: string): H5O_type_t =
  ## proc to retrieve the type of an object (dataset or group etc) based on
  ## a location in the HDF5 file and a relative name from there
  var h5info: H5O_info_t
  let err = H5Oget_info_by_name(h5id.hid_t, name, addr(h5info), H5P_DEFAULT)
  withDebug:
    echo "Getting Type of object ", name
  if err >= 0:
    result = h5info.`type`
  else:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getObjectTypeByName`")

proc getObjectInfo*(h5id: FileID | GroupID | DatasetID): H5O_info_t =
  ## Returns the object info for a single object in the H5 file
  let err = H5Oget_info(h5id.hid_t, addr result)
  if err >= 0:
    echo result
  else:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getObjectInfo`")

proc getObjectTypeByName*(h5id: ParentID, name: string): H5O_type_t =
  case h5id.kind
  of okFile: result = getObjectTypeByName(h5id.fid, name)
  of okGroup: result = getObjectTypeByName(h5id.gid, name)
  of okDataset: result = getObjectTypeByName(h5id.did, name)
  #of okAttr: result = getObjectTypeByName(h5id.attrId, name)
  #of okType: result = getObjectTypeByName(h5id.typId, name)
  else:
    raise newException(ValueError, "Cannot determine object type of an " & $h5id.kind &
      " id!")

proc printOpenObjects*(h5f: H5File) =
  ## Prints all objects that are still open in the given H5 file.
  let
    filesOpen = H5Fget_obj_count( h5f.file_id.hid_t, H5F_OBJ_FILE)
    dsetsOpen = H5Fget_obj_count( h5f.file_id.hid_t, H5F_OBJ_DATASET)
    groupsOpen = H5Fget_obj_count(h5f.file_id.hid_t, H5F_OBJ_GROUP)
    typesOpen = H5Fget_obj_count( h5f.file_id.hid_t, H5F_OBJ_DATATYPE)
    attrsOpen = H5Fget_obj_count( h5f.file_id.hid_t, H5F_OBJ_ATTR)
  # always printing, regardless of debug
  echo "\t objects open:"
  echo "\t\t files open: ", filesOpen
  echo "\t\t dsets open: ", dsetsOpen
  echo "\t\t groups open: ", groupsOpen
  echo "\t\t types open: ", typesOpen
  echo "\t\t attrs open: ", attrsOpen

proc getNumberOpenObject*(h5id: FileID, objectKinds: set[ObjectKind]): int =
  ## Returns the number of open objects in the given file.
  ##
  ## If `okLocal` is part of the `objectKinds` set, the number will only refer
  ## to the number of open objects as opened by the given `FileID`! This is
  ## relevant when opening a file from two threads / processes to distinguish
  ## / get all open objects between all IDs.
  if okNone in objectKinds: return 0
  let err = H5Fget_obj_count(h5id.hid_t, objectKinds.toH5())
  if err < 0:
    raise newException(HDF5LibraryError, "Call to `H5get_obj_count` failed in `getNumberOpenObjects`.")

proc getOpenObjectIds*(h5id: FileID, objectKinds: set[ObjectKind]): seq[hid_t] =
  ## Return all IDs of objects of `kind` that are still open in the file.
  ##
  ## If you ask for multiple types at the same time, you may use `getType` on the
  ## identifier to separate the different IDs (keep in mind `getType` returns an
  ## element of the `H5I_type_t` enum!).
  ##
  ## If `okLocal` is part of the `objectKinds` set, the number will only refer
  ## to the number of open objects as opened by the given `FileID`! This is
  ## relevant when opening a file from two threads / processes to distinguish
  ## / get all open objects between all IDs.
  if okNone in objectKinds: return @[]
  let numObjects = getNumberOpenObject(h5id, objectKinds)
  if numObjects > 0:
    var objList = newSeq[hid_t](numObjects)
    let err = H5Fget_obj_ids(h5id.hid_t,
                             objectKinds.toH5(), numObjects.csize_t, addr objList[0])
    if err < 0:
      raise newException(HDF5LibraryError, "Call to `H5get_obj_ids` failed in `getOpenObjectsIds`.")
    result = objList.filterIt(it > 0)

proc getOpenObjectIds*(h5f: H5File, objectKinds: set[ObjectKind]): seq[hid_t] =
  ## Overload of the above for a `H5File` as an input.
  result = h5f.file_id.getOpenObjectIds(objectKinds)

proc isValidID*(h5id: hid_t): bool {.inline.} =
  ## This is essentially just an alias to `isObjectOpen` as that is the original use
  ## case of the underlying procedure. In some cases it may be logical to check for
  ## valid-ness of an ID instead of whether an object is open (for clarity in code)
  result = h5id.isObjectOpen

proc getRefcount*(h5id: hid_t): int {.inline.} =
  if h5id.isObjectOpen:
    let err = H5Iget_ref(h5id)
    if err >= 0:
      result = err.int
    else:
      raise newException(HDF5LibraryError, "Call to `H5Iget_ref` failed trying to determine reference " &
        "count to id: " & $h5id)
  else:
    result = 0

proc getRefCount*[T: H5File | H5Group | H5GroupObj | H5Dataset | H5DatasetObj](h5o: T): int {.inline.} =
  ## Returns the reference count to the given object. This tells us how many instances of the
  ## object are still open in memory.
  result = h5o.getH5ID.to_hid_t.getRefCount()

proc getFileID*(h5id: hid_t): FileID =
  ## Returns the `FileID` of the file the given object is associated to.
  ##
  ## TODO: this could replace us keeping track of the file id in groups!
  ##
  ## Keep in mind this note from the docs:
  ##
  ## ..note::
  ##   Note that the HDF5 library permits an application to close a file
  ##   while objects within the file remain open. If the file containing
  ##   the object id is still open, H5Iget_file_id() will retrieve the
  ##   existing file identifier. If there is no existing file identifier
  ##   for the file, i.e., the file has been closed, H5Iget_file_id() will
  ##   reopen the file and return a new file identifier. In either case,
  ##   the file identifier must eventually be released using H5Fclose().
  let err = H5Iget_file_id(h5id)
  if err > 0:
    result = err.FileID
  elif err == -1.hid_t:
    raise newException(HDF5LibraryError, "Could not determine the file ID associated with " &
      $h5id & ". Invalid ID according to call to `H5Iget_file_id`.")
  else:
    doAssert err != 0, "`H5Iget_file_id` returned ambiguous ID 0."
    raise newException(HDF5LibraryError, "Call to `H5Iget_file_id` failed determining the file " &
      "associated with the ID: " & $h5id)

proc getFileID*[T: H5Dataset | H5DatasetObj | H5Group | H5GroupObj | H5Attr | H5AttrObj](h5o: T): FileID =
  ## Returns the `FileID` associated with the given H5 object.
  when T is H5Attr or T is H5AttrObj:
    let id = h5o.attr_id.hid_t
  else:
    let id = h5o.getH5ID.to_hid_t
  result = id.getFileID()

proc getType*(h5id: hid_t): H5I_type_t =
  ## Returns the type associated with an arbitrary H5 identifier.
  ##
  ## Might return `H5I_BADID` (field of the enum) if the ID does not match
  ## any known identifier.
  result = H5Iget_type(h5id)

when false:
  ## this is also super helpful
  proc getName*(h5id: hid_t): string =
    ## Returns the name associated with the given ID.
    ##
    ## NOTE: this procedure may only be called, if the given ID is still valid!
    ## Needs to be wrapped in something
    var size = H5Iget_name(h5id, nil, 0)
    result = newString(size) # nim strings are already zero terminated
    let err = H5Iget_name(h5id, result, size + 1) # +1 for zero termination
    if err < 0:
      raise newException(HDF5LibraryError, "Call to `H5Iget_name` failed trying to determine " &
        "name of object with ID: " & $h5id)

proc contains*(h5f: H5File, name: string): bool =
  ## Checks if the given `name` is contained in the H5 file.
  ##
  ## Uses `H5Lexists` using `existsInFile`. Does not require us to traverse our tables.
  # existsInFile will properly format the name
  let fileId = h5f.file_id
  result = existsInFile(fileId, name) > 0

proc formatMaybeRelativeName*[T](h5o: T, name: string): string =
  ## Formats the given `name` taking into account that it may be a relative name
  ## starting from the given `h5o` or may be an absolute path.
  when T is H5File:
    # must be absolute
    result = name.formatName() # possibly prepend `/`
  else:
    # 1. if starts with `/`, treat as absolute
    if name.startsWith("/"):
      result = name.formatName()
    else:
      # check if relative
      let n = name.formatName()
      if n.startsWith(h5o.name):
        # is absolute
        result = n
      else:
        # is relative, prepend object name
        result = formatName(h5o.name / name)

proc contains*(grp: H5Group, name: string): bool =
  ## Checks if the given `name` is a subgroup or dataset in `grp` or its groups.
  ## nIt takes a parent-child relationship for groups into account, i.e. if called
  ## on a group, it's only true, if the element is a child of the group (or of a subgroup).
  ##
  ## Uses `H5Lexists` using `existsInFile`. Does not require us to traverse our tables.
  let fileId = grp.file_ref.file_id
  # maybe `name` is a subgroup or absolute, fix up name
  let name = formatMaybeRelativeName(grp, name)
  result = existsInFile(fileId, name) > 0

proc delete*[T](h5o: T, name: string): bool =
  ## Deletes the object with `name` from the H5 file
  ## If `h5o` is the parent of the object (e.g. `name` is dset in `group`)
  ## a relative name is valid. Else if `h5o` is the file itself, `name` needs
  ## to be the full path. Returns `true` if deletion successful
  let h5id = getH5Id(h5o)
  let name = formatMaybeRelativeName(h5o, name)
  case h5id.getObjectTypeByName(name)
  of H5O_TYPE_UNKNOWN, H5O_TYPE_NAMED_DATATYPE, H5O_TYPE_NTYPES:
    raise newException(HDF5LibraryError, "Object with name " & $name & " is neither " &
      "a dataset nor a group! Cannot be deleted!")
  of H5O_TYPE_GROUP:
    if name in h5o.groups:
      h5o.groups.del(name)
    # now remove all datasets in the group
    var toDelete = newSeq[string]()
    for dset in keys(h5o.datasets):
      if dset.startsWith(name):
        toDelete.add dset
    for dset in toDelete:
      h5o.datasets.del(dset)
  of H5O_TYPE_DATASET:
    if name in h5o.datasets:
      h5o.datasets.del(name)
  result = if H5Ldelete(h5id.to_hid_t, name, H5P_DEFAULT) >= 0: true else: false

proc copy*[T](h5in: H5File, h5o: T,
              target: Option[string] = none[string](),
              h5out: Option[H5File] = none[H5File]()): bool =
  ## Copies the object `h5o` from `source` to `target`.
  ## `Target` may be in a separate file, indicated by `h5out`.
  ## Returns `true` if the object was copied successfully.
  var tgt = ""
  if target.isSome:
    tgt = target.get

  var targetGrp = if target.isSome: target.get.parentDir: else: "/"
  if targetGrp.len == 0:
    targetGrp = "/"
  var targetName = if target.isSome:
                     target.get.extractFileName:
                   else:
                     h5o.name

  var targetId: hid_t

  echo "Copying ", h5o.name
  echo "To grp ", targetGrp
  echo "With name ", targetName

  if h5out.isSome:
    # copy to separete file
    var h5f = h5out.get
    if target.isSome:
      let grp = h5f.create_group(targetGrp)
      targetId = grp.group_id.hid_t
    else:
      echo "Target grp ", targetGrp
      echo "Target Name ", targetName
      let grp = h5f.create_group(targetName.parentDir)
      targetId = grp.group_id.hid_t
  else:
    if target.isSome:
      if targetGrp == "/":
        targetId = h5in.file_id.hid_t
      else:
        let grp = h5in.create_group(targetGrp)
        targetId = grp.group_id.hid_t
    else:
      raise newException(HDF5LibraryError, "Cannot copy object " & h5o.name & " to " &
        "same file without target!")

  let err = H5Ocopy(h5o.getH5Id.to_hid_t, h5o.name,
                    targetId, targetName,
                    H5P_DEFAULT, H5P_DEFAULT)

  result = if err >= 0: true else: false
