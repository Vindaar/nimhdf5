# the procs contained in here are utility procs, which are used
# within the high-level bindings to the H5 library.
# In contrast to the procs defined in util.nim, these procs here
# specifically deal with H5 related datatypes.
# In other cases procs are included for objects / types etc. where
# it is not (yet) warranted to have an individual file for, e.g.
# procs related to general H5 objects.

import strutils, strformat
import ospaths
import options
import tables

# nimhdf5 related libraries
import hdf5_wrapper
import H5nimtypes
import util
import datatypes

proc contains*(h5f: H5File, name: string): bool
proc contains*(grp: H5Group, name: string): bool
proc getObjectTypeByName*(h5id: hid_t, name: string): H5O_type_t

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
  # cast the H5FileObj pointer back
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
      echo "visiting dataset ", name
      h5f.datasets[name] = newH5DataSet(name)

proc visit_file*(h5f: H5FileObj, h5id: hid_t = 0.hid_t) =
  ## this proc iterates over the whole file and reads the complete content
  ## optionally only visits all elements below hid_t
  ## H5Ovisit recursively visits any object (group or dataset + a couple specific
  ## types) and calls a callback function. Depending on the return value of that
  ## callback function, it either continues (proc returns 0), stops early and
  ## returns the value of the callback (proc returns value > 0), stops early
  ## and returns error (proc returns value < 0)
  ## inputs:
  ##   h5f: H5FileObj = file object, which will be visited. The
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
    err = H5Ovisit(h5f.file_id, H5_INDEX_NAME, H5_ITER_NATIVE,
                   cast[H5O_iterate_t](addH5ObjectFromRoot),
                   cast[pointer](h5f))
  if err < 0:
    raise newException(IOError, "Visiting the H5 file failed with an error." &
      "File is possibly corrupted. See the H5 stacktrace.")
  # now set visited flag
  h5f.visited = true

#proc contains*[T: (H5FileObj | H5Group)](h5f: T, name: string): bool =
#  ## proc to check whehther an element named `name` is contained in the
#  ## HDF5 file. Checks for both groups and datasets!
#  ## For groups either a full path or a relative path (relative to the name
#  ## of the group on which `contains` is called) is possible. Note that
#  ## lookups with a depth of more than 1 (subgroups or datasets of groups
#  ## in the group we check) is currently not supported. Call on H5FileObj
#  ## instead.
#  ## Note: we first check for the existence of a group of this name,
#  ## and only if no group of `name` is found, do we check the dataset names
#  ## inputs:
#  ##   h5f: H5FileObj = H5 file to check
#  ##   name: string = the name of the dataset / group to check
#  ## outputs:
#  ##   bool = true if contained, false else
#  ## throws:
#  ##   HDF5LibraryError = in case the call to visit_file fails (only called
#  ##     if the file wasn't visited before)
#
#  # if file not visited yet, do that now
#  when T is H5FileObj:
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

proc isOpen*(h5f: H5File, name: grp_str): bool =
  ## returns if the given group is known and open. Returns false
  ## both if the group is not known as well as if it's known but closed.
  let n = name.string
  result = if h5f.groups.hasKey(n): h5f.groups[n].opened
           else: false

proc isDataset*(h5f: H5FileObj, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a dataset or not
  let target = formatName name
  echo "Checking if target ", name, " in file"
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_DATASET: true else: false
  #else:
  #  echo "it's not in the file what"

proc isGroup*(h5f: H5File, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a group or not
  let target = formatName name
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_GROUP: true else: false

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

proc existsInFile*(h5id: hid_t, name: string): hid_t =
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
    result = H5Lexists(h5id, toCheck, H5P_DEFAULT).hid_t
    if result == 0:
      # does not exist, so break, even if we're not at the deepest level
      break
    elif result < 0:
      raise newException(HDF5LibraryError, "Call to `H5Lexists` failed " &
        "in `existsFile`!")

template getParent*(dset_name: string): string =
  ## given a `dset_name` after formating (!), return the parent name,
  ## simly done by a call to parentDir from ospaths
  var result: string
  result = parentDir(dset_name)
  if result == "":
    result = "/"
  result

proc firstExistingParent*[T](h5f: T, name: string): Option[H5Group] =
  ## proc to find the first existing parent of a given object in H5F
  ## recursively
  ## inputs:
  ##    h5f: H5FileObj: the object in which to look for the parent
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

proc getParentId*[T: (H5FileObj | H5Group), U: (H5DataSet | H5Group)](h5f: T, h5o: U): hid_t =
  ## returns the id of the first existing parent of `h5o` contained in the file
  ## or group `h5f` (f refers to the fact that the object contains the file id
  ## inputs:
  ##  h5f: (H5FileObj | H5Group) = any object that contains the file_id in which
  ##    the `h5o` is contained
  ##  h5o: (H5Group | H5DataSet) = object for which to check the parent id
  ## outputs:
  ##   hid_t = object id of the parent or the file id, if no parent exists besides
  ##     the file root
  let
    parent = getParent(h5o.name)
    p = firstExistingParent(h5f, h5o.name)
  if isSome(p) == true:
    result = getH5Id(unsafeGet(p))
  else:
    # this means the only existing parent is root
    result = h5f.file_id

proc getObjectTypeByName*(h5id: hid_t, name: string): H5O_type_t =
  ## proc to retrieve the type of an object (dataset or group etc) based on
  ## a location in the HDF5 file and a relative name from there
  var h5info: H5O_info_t
  let err = H5Oget_info_by_name(h5id, name, addr(h5info), H5P_DEFAULT)
  withDebug:
    echo "Getting Type of object ", name
  if err >= 0:
    result = h5info.`type`
  else:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getObjectTypeByName`")

proc contains*(h5f: H5FileObj, name: string): bool =
  ## Faster version of `contains` below, simply making use of
  ## `H5Lexists` using `existsInFile`. Does not require us to
  ## traverse our tables
  # format the given name
  # existsInFile will properly format the name
  result = if existsInFile(h5f.file_id, name) > 0: true else: false

proc delete*[T](h5o: T, name: string): bool =
  ## Deletes the object with `name` from the H5 file
  ## If `h5o` is the parent of the object (e.g. `name` is dset in `group`)
  ## a relative name is valid. Else if `h5o` is the file itself, `name` needs
  ## to be the full path. Returns `true` if deletion successful
  let h5id = getH5Id(h5o)
  case h5id.getObjectTypeByName(name)
  of H5O_TYPE_UNKNOWN, H5O_TYPE_NAMED_DATATYPE, H5O_TYPE_NTYPES:
    raise newException(HDF5LibraryError, "Object with name " & $name & " is neither " &
      "a dataset nor a group! Cannot be deleted!")
  of H5O_TYPE_GROUP:
    if name in h5o.groups:
      h5o.groups.del(name)
  of H5O_TYPE_DATASET:
    if name in h5o.datasets:
      h5o.datasets.del(name)
  result = if H5Ldelete(h5id, name, H5P_DEFAULT) >= 0: true else: false

proc copy*[T](h5in: H5FileObj, h5o: T,
              target: Option[string] = none[string](),
              h5out: Option[H5FileObj] = none[H5FileObj]()): bool =
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
      targetId = grp.group_id
    else:
      echo "Target grp ", targetGrp
      echo "Target Name ", targetName
      let grp = h5f.create_group(targetName.parentDir)
      targetId = grp.group_id
  else:
    if target.isSome:
      if targetGrp == "/":
        targetId = h5in.file_id
      else:
        let grp = h5in.create_group(targetGrp)
        targetId = grp.group_id
    else:
      raise newException(HDF5LibraryError, "Cannot copy object " & h5o.name & " to " &
        "same file without target!")

  let err = H5Ocopy(h5o.getH5Id, h5o.name,
                    targetId, targetName,
                    H5P_DEFAULT, H5P_DEFAULT)

  result = if err >= 0: true else: false
