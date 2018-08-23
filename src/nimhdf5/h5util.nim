# the procs contained in here are utility procs, which are used
# within the high-level bindings to the H5 library.
# In contrast to the procs defined in util.nim, these procs here
# specifically deal with H5 related datatypes.
# In other cases procs are included for objects / types etc. where
# it is not (yet) warranted to have an individual file for, e.g.
# procs related to general H5 objects.

import strutils
import ospaths
import options
import tables

# nimhdf5 related libraries
import hdf5_wrapper
import H5nimtypes
import util
import datatypes

proc `$`*(dset: ref H5DataSet): string =
  ## implementation of to string conversion of a `ref H5DataSet` such
  ## that we can e.g. echo it. Restricts the string to the name of the
  ## object
  result = dset.name

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
  # need to convert result of H5Lexists to hid_t, because return type is
  # `htri_t` from the H5 wrapper
  result = H5Lexists(h5id, name, H5P_DEFAULT).hid_t

template getH5Id*(h5o: typed): hid_t =
  ## this template returns the correct location id of either
  ## - a H5FileObj
  ## - a H5DataSet
  ## - a H5Group
  ## given as `h5o`
  # var result: hid_t = -1
  when h5o is H5FileObj:
    let result = h5o.file_id
  elif h5o is H5DataSet:
    let result = h5o.dataset_id
  elif h5o is H5Group:
    let result = h5o.group_id
  result

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
      result = some(h5f.groups[name][])
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

proc contains*(h5f: var H5FileObj, name: string): bool =
  ## faster version of `contains` below, simply making use of
  ## `H5Lexists` using `existsInFile`. Does not require us to
  ## traverse our tables
  # format the given name
  let target = formatName name
  result = if existsInFile(h5f.file_id, target) > 0: true else: false
