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

import attributes

import json
func `%`(c: char): JsonNode = % $c # for `withAttr` returning a char
iterator attrsJson*(attrs: H5Attributes, withType = false): (string, JsonNode) =
  ## yields all attribute keys and their values as `JsonNode`. This way
  ## we can actually return all values to the user with one iterator.
  ## And for attributes the variant object overhead does not matter anyways.
  attrs.read_all_attributes
  for key, att in pairs(attrs.attr_tab):
    attrs.withAttr(key):
      if not withType:
        yield (key, % attr)
      else:
        yield (key, %* {
          "value" : attr,
          "type" : att.dtypeAnyKind
        })
    att.close()

iterator attrsJson*[T: H5FileObj | H5Group | H5DataSet](h5o: T, withType = false): (string, JsonNode) =
  for key, val in attrsJson(h5o.attrs, withType = withType):
    yield (key, val)

proc attrsToJson*[T: H5Group | H5DataSet](h5o: T, withType = false): JsonNode =
  ## returns all attributes as a json node of kind `JObject`
  result = newJObject()
  for key, jval in h5o.attrsJson(withType = withType):
    result[key] = jval

proc pretty*(att: H5Attr, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}opened: {att.opened},\n"
  result.add &"{fieldInd}dtypeAnyKind: {att.dtypeAnyKind}"
  if full:
    result.add &",\n{fieldInd}attr_id: {att.attr_id},\n"
    result.add &"{fieldInd}dtype_c: {att.dtype_c},\n"
    result.add &"{fieldInd}dtypeBaseKind: {att.dtypeBaseKind},\n"
    result.add &"{fieldInd}attr_dspace_id: {att.attr_dspace_id}"
  result.add repeat(' ', indent) & "\n}"

proc `$`*(att: H5Attr): string =
  result = pretty(att)

proc pretty*(attrs: H5Attributes, indent = 2, full = false): string =
  ## For now this just prints the H5Attributes all as JSON
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}num_attrs: {attrs.num_attrs},\n"
  result.add &"{fieldInd}parent_name: {attrs.parent_name},\n"
  result.add &"{fieldInd}parent_type: {attrs.parent_type}"
  if full:
    result.add &",\n{fieldInd}parent_id: {attrs.parent_id}"
  if attrs.num_attrs > 0:
    result.add &"{fieldInd}attributes: " & "{"
  for name, attr in attrs.attrsJson:
    result.add &"{fieldInd}{name}: {attr},\n"
  if attrs.num_attrs > 0:
    result.add &"{fieldInd}" & "}"
  result.add repeat(' ', indent) & "\n}"

proc `$`*(attrs: H5Attributes): string =
  ## to string conversion for a `H5Attributes` for pretty printing
  result = pretty(attrs, full = false)

proc pretty*(dset: H5DataSet, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {dset.name},\n"
  result.add &"{fieldInd}file: {dset.file},\n"
  result.add &"{fieldInd}parent: {dset.parent},\n"
  result.add &"{fieldInd}shape: {dset.shape},\n"
  result.add &"{fieldInd}dtype: {dset.dtype}"
  if full:
    result.add &",\n{fieldInd}maxshape: {dset.maxshape},\n"
    result.add &"{fieldInd}parent_id: {dset.parent_id},\n"
    result.add &"{fieldInd}chunksize: {dset.chunksize},\n"
    result.add &"{fieldInd}dtypeAnyKind: {dset.dtypeAnyKind},\n"
    result.add &"{fieldInd}dtypeBaseKind: {dset.dtypeBaseKind},\n"
    result.add &"{fieldInd}dtype_c: {dset.dtype_c},\n"
    result.add &"{fieldInd}dtype_class: {dset.dtype_class},\n"
    result.add &"{fieldInd}dataset_id: {dset.dataset_id},\n"
    result.add &"{fieldInd}num_attrs: {dset.attrs.num_attrs},\n"
    result.add &"{fieldInd}dapl_id: {dset.dapl_id},\n"
    result.add &"{fieldInd}dcpl_id: {dset.dcpl_id}"
  result.add repeat(' ', indent) & "\n}"

proc `$`*(dset: H5DataSet): string =
  ## to string conversion for a `H5DataSet` for pretty printing
  result = pretty(dset, full = false)

proc pretty*(grp: H5Group, indent = 2, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {grp.name},\n"
  result.add &"{fieldInd}file: {grp.file},\n"
  result.add &"{fieldInd}parent: {grp.parent}"
  if full:
    result.add &",\n{fieldInd}file_id: {grp.file_id},\n"
    result.add &"{fieldInd}group_id: {grp.group_id},\n"
    result.add &"{fieldInd}parent_id: {grp.parent_id},\n"
    result.add &"{fieldInd}gapl_id: {grp.gapl_id},\n"
    result.add &"{fieldInd}gcpl_id: {grp.gcpl_id}"
  if grp.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{"
  for name, dset in grp.datasets:
    result.add &"{fieldInd}{name}:  " & dset.pretty(indent = indent + 4)
  if grp.datasets.len > 0:
    result.add &"{fieldInd}" & "}"
  if grp.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{"
  for name, subgrp in grp.groups:
    result.add &"{fieldInd}{name},\n"
  if grp.groups.len > 0:
    result.add &"{fieldInd}" & "}"
  result.add repeat(' ', indent) & "\n}"

proc `$`*(grp: H5Group): string =
  ## to string conversion for a `H5Group` for pretty printing
  result = pretty(grp, full = false)

proc pretty*(h5f: H5FileObj, indent = 2, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {h5f.name},\n"
  result.add &"{fieldInd}rw_type: {h5f.rw_type},\n"
  result.add &"{fieldInd}visited: {h5f.visited}"
  if full:
    result.add &",\n{fieldInd}nfile_id: {h5f.file_id},\n"
    result.add &"{fieldInd}err: {h5f.err},\n"
    result.add &"{fieldInd}status: {h5f.status}"
  if h5f.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{"
  for name, dset in h5f.datasets:
    result.add &"{fieldInd}{name}: " & dset.pretty(indent = indent + 4)
  if h5f.datasets.len > 0:
    result.add &"{fieldInd}" & "}"
  if h5f.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{"
  for name, subGrp in h5f.groups:
    result.add &"{fieldInd}{name}: " & subGrp.pretty(indent = indent + 4)
  if h5f.groups.len > 0:
    result.add fieldInd & "}"
  result.add &",\n{fieldInd}attrs: {h5f.attrs}"
  result.add repeat(' ', indent) & "\n}"

proc `$`*(grp: H5FileObj): string =
  ## to string conversion for a `H5FileObj` for pretty printing
  result = pretty(grp, full = false)

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
