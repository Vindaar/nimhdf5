import std / [strutils, tables]

import datatypes, h5util, util, groups, datasets

iterator items*(h5f: H5File, start_path = "/", depth = -1): H5Group =
  ## iterator, which returns a non mutable group objects starting from `start_path` in the
  ## H5 file
  ## inputs:
  ##    h5f: H5File = the H5 file object, over which to iterate
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
    if grp.startsWith(mstart_path) and grp != mstart_path and
      not (mstart_path != "/" and # if not start at root
           grp.len > mstart_path.len and # check grp longer than start path
           grp[mstart_path.len] != '/'): # and if this isn't a another group starting same name
                                         # e.g. start path: /group/foo
                                         #      current: /group/fooBar
                                         # If next character after start_path is not `/` means this is a group
                                         # with a similar name
      # in this case we're neither visiting the group at which we start
      # nor a group, which is not a subgroup
      if depth >= 0:
        # check if max search depth reached
        let n_current = grp.count('/')
        if n_current - n_start > depth:
          # in this case continue without yielding
          continue
      yield h5f[grp.grp_str]

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
  # We want the root group to be treated as _not_ having a `/` so that any datasets at the
  # root level count as `depth == 1`
  let n_start = if mstart_path == "/": 0 else: mstart_path.count('/')
  # now loop over all groups, checking for start_path in each group name
  for grp in keys(group.groups):
    if grp.startsWith(mstart_path) == true and grp != mstart_path:
      if depth != 0:
        let n_current = grp.count('/')
        if n_current - n_start > depth:
          # in this case continue without yielding
          continue
      yield group.groups[grp]

iterator items*(group: H5Group, start_path = ".", depth = 1): H5DataSet =
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

  # number of `/` in start path, needed to calculate at which
  # depth we are from start path
  var n_start = 0

  # now make sure the start_path is properly formatted
  if start_path != ".":
    mstart_path = formatName start_path
  else:
    mstart_path = group.name
  # We want the root group to be treated as _not_ having a `/` so that any datasets at the
  # root level count as `depth == 1`
  n_start = if mstart_path == "/": 0 else: mstart_path.count('/')

  # now loop over all groups, checking for start_path in each group name
  for dset in keys(group.datasets):
    if dset.startsWith(mstart_path) and dset != mstart_path: # and
      #not (mstart_path != "/" and # if not start at root
      #     dset.len > mstart_path.len and # check dset longer than start path
      #     dset[mstart_path.len] != '/'): # and if this isn't a another group starting same name
      #                                   # e.g. start path: /group/foo
      #                                   #      current: /group/fooBar
      #                                   # If next character after start_path is not `/` means this is a group
      #                                   # with a similar name
      # in this case we're neither visiting the group at which we start
      # nor a group, which is not a subgroup
      if depth >= 0:
        # check if max search depth reached
        let n_current = dset.count('/')
        if n_current - n_start > depth:
          # in this case continue without yielding
          continue
      # means we're reading a fitting dataset, yield
      let dsetObj = group.datasets[dset]
      if dsetObj.opened:
        yield dsetObj
      else:
        yield group.file_ref.get(dset.dset_str)

from hdf5_wrapper import H5Rdereference2, H5P_DEFAULT, H5R_OBJECT, H5I_GROUP, H5I_DATASET
iterator references*(h5f: H5File, d: H5Dataset): H5Reference =
  ## Iterator which yields each element that is referenced by the given dataset as
  ## a `H5Reference`. Can be either a group or a dataset.
  ##
  ## ``Still experimental!``
  # Read the references as uint64. Each element points to some other element in the HDF5 file
  let data = d[uint64]
  for id in data:
    ## XXX: this is currently hardcoded to `dereference2`! Should depend on `H5_LEGACY, H5_FUTURE`
    let obj = H5Rdereference2(d.datasetId.id, H5PDefault, H5R_Object, addr id) # this is actually a `ptr haddr_t`
    let typ = getType(obj) # get type of H5 object
    let name = getName(obj)
    case typ
    of H5I_GROUP:   yield H5Reference(kind: rkGroup,   g: h5f[name.grp_str])
    of H5I_DATASET: yield H5Reference(kind: rkDataset, d: h5f[name.dset_str])
    else: doAssert false, "Not possible!"
