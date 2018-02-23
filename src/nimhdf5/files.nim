import tables
import strutils
import options
import os

import hdf5_wrapper
import H5nimtypes
import datatypes

# need to forward declare visit file, due to cyclic import statements
# files -> datasets -> groups -> files
# and
# files -> groups -> files
# so that proc is already known when we encounter the
# from files import visit_files statement in groups.nim
proc visit_file*(h5f: var H5FileObj, name: string = "", h5id: hid_t = 0)

from datasets import `[]`
import attributes
from groups import create_group, `[]`
import h5util
import util

proc newH5File*(): H5FileObj =
  ## default constructor for a H5File object, for internal use
  let dset = newTable[string, ref H5DataSet]()
  let dspace = initTable[string, hid_t]()
  let groups = newTable[string, ref H5Group]()
  let attrs = newH5Attributes()
  result = H5FileObj(name: "",
                     file_id: H5_NOFILE,
                     rw_type: H5F_INVALID_RW,
                     err: -1,
                     status: -1,
                     datasets: dset,
                     dataspaces: dspace,
                     groups: groups,
                     attrs: attrs)

proc nameFirstExistingParent(h5f: H5FileObj, name: string): string =
  # similar to firstExistingParent, except that only the name of
  # the object is returned
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
  # this procedure can be used to get the name of the given object
  # or its first existing parent
  # inputs:
  #    h5f: H5FileObj = the file object in which to check the tables
  #    name: string = name of the object to check for
  # outputs:
  #    string = the name of the given object (if it exists), or the
  #          name of the first existing parent. If root is the only
  #          existing object, empty string is returned
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

proc H5file*(name, rw_type: string): H5FileObj = #{.raises = [IOError].} =
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
      raise newException(IOError, getH5read_non_exist_file())
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
  result.attrs = initH5Attributes("/", result.file_id, "H5FileObj")

proc close*(h5f: H5FileObj): herr_t =
  # this procedure closes all known datasets, dataspaces, groups and the HDF5 file
  # itself to clean up
  # inputs:
  #    h5f: H5FileObj = file object which to close
  # outputs:
  #    hid_t = status of the closing of the file

  # TODO: can we use iterate and H5Oclose to close all this stuff
  # somewhat cleaner?

  for name, dset in pairs(h5f.datasets):
    withDebug:
      discard
      #echo("Closing dset ", name, " with dset ", dset)
    # close attributes
    for attr in values(dset.attrs.attr_tab):
      result = H5Aclose(attr.attr_id)
      result = H5Sclose(attr.attr_dspace_id)
    result = H5Dclose(dset.dataset_id)
    result = H5Sclose(dset.dataspace_id)

  for name, group in pairs(h5f.groups):
    withDebug:
      discard
      #echo("Closing group ", name, " with id ", group)
    # close attributes
    for attr in values(group.attrs.attr_tab):
      result = H5Aclose(attr.attr_id)
      result = H5Sclose(attr.attr_dspace_id)
    result = H5Gclose(group.group_id)

  # close attributes
  for attr in values(h5f.attrs.attr_tab):
    result = H5Aclose(attr.attr_id)
    result = H5Sclose(attr.attr_dspace_id)
  
  result = H5Fclose(h5f.file_id)

template withH5*(h5file, rw_type: string, actions: untyped) =
  ## template to work with a H5 file, taking care of opening
  ## and closing the file
  ## injects the `h5f` variable into the calling space
  var h5f {.inject.} = H5File(h5file, rw_type)

  # perform actions with H5FileObj
  actions

  let err = h5f.close()
  if err != 0:
    echo "Closing of H5 file unsuccessful. Returned code ", err

proc getObjectIdByName(h5file: var H5FileObj, name: string): hid_t =
  # proc to retrieve the location ID of a H5 object based its relative path
  # to the given id
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
proc create_hardlink*(h5file: var H5FileObj, target: string, link_name: string) =
  # proc to create hardlinks between pointing to an object `target`. Can be either a group
  # or a dataset, defined by its name (full path!)
  # the target has to exist, while the link_name must be free
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

proc addH5Object*(location_id: hid_t, name_c: cstring, h5info: H5O_info_t, h5f_p: pointer): herr_t {.cdecl.} =
  # similar proc to processH5ObjectFromRoot, except we do /not/ start at root
  # important distinction to be able to deal with the root group itself
  # Does this make sense? If '.' is handed to us on first call to H5Ovisit anyways,
  # do we ever want to add the object at point? Should this not always already
  # be part of the h5 object, or rather even if it is not, adding it will be
  # difficult anyways, because we only have the location id. Well, we can
  # simply open the object then and there, I suppose...
  # NEED a proper openObjectById function...!
  discard
    
proc addH5ObjectFromRoot*(location_id: hid_t, name_c: cstring, h5info: H5O_info_t, h5f_p: pointer): herr_t {.cdecl.} =
  # this proc is called for each object iterated over in visitFile.
  # we basically just extract the information we want to have from the
  # h5info struct and add it to the h5f file object. Needs to be
  # a pointer here, since it's handed to C
  # this proc is only called in the case where the start from the root group

  # cast the H5FileObj pointer back
  var h5f = cast[var H5FileObj](h5f_p)
  if name_c == ".":
    # in case the location is `.`, we are simply at our starting point (currently
    # means root group), we don't want to do anything here, so continue 
    result = 0
  else:
    let name = formatName($name_c)
    if h5info.`type` == H5O_TYPE_GROUP:
      # we discard the returned group object, don't need it here
      # TODO: change to h5f[name.grp_str], but for that need to modify
      # h5f.get(grp_str) such that it checks in the file for existence
      # or rather create a open group from file proc, where we know that
      # the file exists and we open it by id
      discard h5f.create_group(name)
    elif h5info.`type` == H5O_TYPE_DATASET:
      # misuse `[]` proc for now.
      # TODO: write proc which opens and reads dataset from file by id...
      # see, I'm going to where the HDF5 library is in the first place...
      discard h5f[name.dset_str]
    
proc visit_file*(h5f: var H5FileObj, name: string = "", h5id: hid_t = 0) =
  # this proc iterates over the whole file and reads the complete content
  # optionally only visits all elements below hid_t or the object given by `name`
  # H5Ovisit recursively visits any object (group or dataset + a couple specific
  # types) and calls a callback function. Depending on the return value of that
  # callback function, it either continues (proc returns 0), stops early and
  # returns the value of the callback (proc returns value > 0), stops early
  # and returns error (proc returns value < 0)

  # TODO: write an iterator which makes use of this?
  var err: herr_t
  if h5id != 0:
    err = H5Ovisit(h5id, H5_INDEX_NAME, H5_ITER_NATIVE,
                   cast[H5O_iterate_t](addH5Object),
                   cast[pointer](addr(h5f)))
  else:
    err = H5Ovisit(h5f.file_id, H5_INDEX_NAME, H5_ITER_NATIVE,
                   cast[H5O_iterate_t](addH5ObjectFromRoot),
                   cast[pointer](addr(h5f)))
    
  # now set visited flag
  h5f.visited = true
    

iterator items*(h5f: var H5FileObj, start_path = "/", depth = 0): H5Group =
  ## iterator, which returns a non mutable group objects starting from `start_path` in the
  ## H5 file
  ## Note: many procs working on groups need a mutable object!
  ## TODO: mutability often not needed in those procs.. change!
  ## inputs:
  ##    h5f: H5FileObj = the H5 file object, over which to iterate
  ##    start_path: string = optional starting location from which to iterate
  ##        default starts at root group `/`
  ##    depth: int = depth of subgroups to be returned. Default 0 returns
  ##      all subgroups
  ## yields:
  ##    H5Group, which resides below `start_path`
  ## throws:
  ##    HDF5LibraryError = raised in case a call to the H5 library fails
  var mstart_path = start_path

  # first check whether we visited the whole file yet
  if h5f.visited == false:
    h5f.visit_file

  # number of `/` in start path, needed to calculate at which
  # depth we are from start path
  var n_start = 0

  # now make sure the start_path is properly formatted
  if start_path != "/":
    mstart_path = formatName start_path
    # in this case count number of / 
    n_start = mstart_path.count('/')    
  else:
    # if we start at root group, start with 0
    # otherwise cannot differentiate level 1 from root, since
    # both have exactly 1 `/`
    n_start = 0
    
  # now loop over all groups, checking for start_path in each group name
  for grp in keys(h5f.groups):
    if grp.startsWith(mstart_path) == true and grp != mstart_path:
      # in this case we're neither visiting the group at which we start
      # nor a group, which is not a subgroup
      if depth != 0:
        # check if max search depth reached
        let n_current = grp.count('/')
        if n_current - n_start > depth:
          # in this case continue without yielding
          continue
      yield h5f[grp.grp_str]

  
proc contains*[T: (H5FileObj | H5Group)](h5f: var T, name: string): bool =
  ## proc to check whehther an element named `name` is contained in the
  ## HDF5 file. Checks for both groups and datasets!
  ## For groups either a full path or a relative path (relative to the name
  ## of the group on which `contains` is called) is possible. Note that
  ## lookups with a depth of more than 1 (subgroups or datasets of groups
  ## in the group we check) is currently not supported. Call on H5FileObj
  ## instead.
  ## Note: we first check for the existence of a group of this name,
  ## and only if no group of `name` is found, do we check the dataset names
  ## inputs:
  ##   h5f: var H5FileObj = H5 file to check
  ##   name: string = the name of the dataset / group to check
  ## outputs:
  ##   bool = true if contained, false else
  ## throws:
  ##   HDF5LibraryError = in case the call to visit_file fails (only called
  ##     if the file wasn't visited before)

  # if file not visited yet, do that now
  when T is H5FileObj:
    if h5f.visited == false:
      h5f.visit_file
  else:
    if h5f.file_ref.visited == false:
      visit_file(h5f.file_ref[])

  result = false
  if name in h5f.groups:
    result = true
  else:
    # if no group of said name, check datasets
    if name in h5f.datasets:
      result = true

  if result == false:
    # in case we're checking a group, we should also check whether the given name
    # is relative to this groups basename
    when T is H5Group:
      # check whether `name` contains h5f's name
      if h5f.name notin name:
        # then create full name and call this proc again
        let full_name = h5f.name / name
        result = h5f.contains(full_name)
