#[
This file contains all procedures related to datasets.

The H5DataSet type is defined in the datatypes.nim file.
]#

## TODO: this is only a workaround, because `choosenim` devel on travis
## has a nim version from `19/04/20`, which was before the `parseEnum`
## PR was merged
template tryExport(body: untyped): untyped =
  when compiles(body):
    discard

import options
import tables
import strutils
tryExport:
  export nimIdentNormalize
import sequtils
import seqmath
import macros

import hdf5_wrapper
import H5nimtypes
import datatypes
import dataspaces
import attributes
import filters
import util
import h5util

from groups import create_group, isGroup

proc newH5DataSet*(name: string = ""): H5DataSet =
  ## default constructor for a H5File object, for internal use
  let shape: seq[int] = @[]
  let maxshape: seq[int] = @[]
  let attrs = newH5Attributes()
  result = new H5DataSet
  result.name = name
  result.shape = shape
  result.maxshape = maxshape
  result.dtype = ""
  result.dtype_c = -1.hid_t
  result.parent = ""
  result.file = ""
  result.dataset_id = -1.hid_t
  result.all = RW_ALL
  result.attrs = attrs

proc flush*(dset: H5DataSet, flushKind: FlushKind) =
  ## wrapper around H5Fflush for convenience
  var err: herr_t
  case flushKind
  of fkGlobal:
      err = H5Fflush(dset.dataset_id, H5F_SCOPE_GLOBAL)
  of fkLocal:
      err = H5Fflush(dset.dataset_id, H5F_SCOPE_LOCAL)
  if err < 0:
    raise newException(HDF5LibraryError, "Trying to flush dataset " & dset.name &
      " as " & $flushKind & " failed!")

proc getDset(h5f: H5FileObj, dset_name: string): Option[H5DataSet] =
  ## convenience proc to return the dataset with name dset_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5FileObj = the file object from which to get the dset
  ##    obj_name: string = name of the dset to get
  ## outputs:
  ##    H5DataSet = if dataset is found
  ## throws:
  ##    KeyError: if dataset could not be found
  let dset_exist = hasKey(h5f.datasets, dset_name)
  if dset_exist == false:
    #raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
    result = none(H5DataSet)
  else:
    result = some(h5f.datasets[dset_name])

proc isDataset*(h5f: H5FileObj, name: string): bool =
  ## checks for existence of object in file. If it exists checks whether
  ## object is a dataset or not
  let target = formatName name
  if target in h5f:
    let objType = getObjectTypeByName(h5f.file_id, target)
    result = if objType == H5O_TYPE_DATASET: true else: false

proc readShape(dspace_id: hid_t): tuple[shape, maxshape: seq[int]] =
  ## read the shape and maxshape of a dataset
  ## inputs:
  ##   dspace_id: hid_t = the dataspace id corresponding to the
  ##     dataset for which we read the shape and maxshape
  ## outputs:
  ##   tuple[shape, maxshape: seq[int]] = a tuple of a seq containing the
  ##     size of each dimension (shape) and a seq containing the maximum allowed
  ##     size of each dimension (maxshape).
  ## throws:
  ##   HDF5LibraryError = if a call to the H5 library fails
  let ndims = H5Sget_simple_extent_ndims(dspace_id)
  # given ndims, create a seq in which to store the dimensions of
  # the datase
  var
    shape = newSeq[hsize_t](ndims)
    maxshape = newSeq[hsize_t](ndims)
  let sdims = H5Sget_simple_extent_dims(dspace_id, addr(shape[0]), addr(maxshape[0]))
  # now replace max shape values == `H5S_UNLIMITED` by `int.high`
  maxshape = maxshape.mapIt(
    if it == H5S_UNLIMITED: # == -1
      hsize_t(int.high)
    else:
      hsize_t(it))
  if sdims >= 0:
    doAssert(sdims == ndims)
  else:
    raise newException(HDF5LibraryError,
                       "Call to HDF5 library failed in `readShape` " &
                       "after a call to `H5Sget_simple_extent_dims` with return code " &
                       "$#" % $sdims)
  result = (mapIt(shape, int(it)), mapIt(maxshape, int(it)))

proc readDsetShape(dspace_id: hid_t): seq[int] =
  ## read the shape of the dataset
  ## inputs:
  ##   dspace_id: hid_t = the dataspace id corresponding to the
  ##     dataset for which we read the shape
  ## outputs:
  ##   seq[int] = a sequence containing one element (the size) for each dimension
  ##     in the dataset
  ## throws:
  ##   HDF5LibraryError = if a call to the H5 library fails
  let (shape, maxshape) = readShape(dspace_id)
  result = shape

proc readMaxShape(dspace_id: hid_t): seq[int] =
  ## read the maximum shape of a dataset
  ## inputs:
  ##   dspace_id: hid_t = the dataspace id corresponding to the
  ##     dataset for which we the maximum shape for each dim
  ## outputs:
  ##   seq[int] = a sequence containing one element (the maximum size) for each
  ##     dimension in the dataset
  ## throws:
  ##   HDF5LibraryError = if a call to the H5 library fails
  let (shape, maxshape) = readShape(dspace_id)
  result = maxshape

proc get(h5f: H5FileObj, dset_in: dset_str): H5DataSet =
  ## convenience proc to return the dataset with name dset_name
  ## if it does not exist, KeyError is thrown
  ## inputs:
  ##    h5f: H5FileObj = the file object from which to get the dset
  ##    obj_name: string = name of the dset to get
  ## outputs:
  ##    H5DataSet = if dataset is found
  ## throws:
  ##    KeyError: if dataset could not be found
  var status: cint

  let dset_name = formatName(string(dset_in))
  let dset_exist = hasKey(h5f.datasets, dset_name)

  result = newH5DataSet(dset_name)
  if dset_exist == false:
    # before we raise an exception, because the dataset does not yet exist,
    # check whether such a dataset exists in the file we're not aware of yet
    withDebug:
      echo "file id is ", h5f.file_id
      echo "name is ", result.name
    let dsetInFile = h5f.isDataset(result.name)
    if dsetInFile:
      result.dataset_id   = H5Dopen2(h5f.file_id, result.name, H5P_DEFAULT)
      # get the dataspace id of the dataset
      let dataspace_id = result.dataspace_id
      # does exist, add to H5FileObj
      let datatype_id = H5Dget_type(result.dataset_id)
      let f = h5ToNimType(datatype_id)
      if f == dkSequence:
        # dkSequence == VLEN type
        # in this case this only determines dtypeAnyKind, but we don't
        # know the basetype. Set that by another call of the super of
        # the datatype
        result.dtypeBaseKind = h5ToNimType(H5Tget_super(datatype_id))
        result.dtype = "vlen"
      else:
        # get the dtype string from AnyKind
        result.dtype = anyTypeToString(f)
      result.dtypeAnyKind = f
      result.dtype_c = H5Tget_native_type(datatype_id, H5T_DIR_ASCEND)
      result.dtype_class = H5Tget_class(datatype_id)

      # get the dataset access property list
      result.dapl_id = H5Dget_access_plist(result.dataset_id)
      # get the dataset create property list
      result.dcpl_id = H5Dget_create_plist(result.dataset_id)
      withDebug:
        echo "ACCESS PROPERTY LIST IS ", result.dapl_id
        echo "CREATE PROPERTY LIST IS ", result.dcpl_id
        echo H5Tget_class(datatype_id)

      (result.shape, result.maxshape) = readShape(dataspace_id)
      # still need to determine the parents of the dataset
      result.parent = getParent(result.name)
      var parent = create_group(h5f, result.parent)
      result.parent_id = getH5Id(parent)
      result.file = h5f.name

      # create attributes field
      result.attrs = initH5Attributes(result.dataset_id, result.name, "H5DataSet")

      # need to close the datatype again, otherwise cause resource leak
      status = H5Tclose(datatype_id)
      if status < 0:
        #TODO: replace by exception
        echo "Status of H5Tclose() returned non-negative value."
        echo "H5 will probably complain now..."

      # now that we have created the group fully (including IDs), we can add it to the file and
      # the parent
      var dset_ref = new H5DataSet
      dset_ref = result
      parent.datasets[result.name] = dset_ref
      h5f.datasets[result.name] = dset_ref
    else:
      # check whether there exists a group of same name?
      let groupOfName = h5f.isGroup(result.name)
      if groupOfName:
        raise newException(ValueError, "Dataset with name: " & dset_name &
          " not found in file " & h5f.name & ". Instead found a group " &
          "of the same name")
      else:
        raise newException(KeyError, "Dataset with name: " & dset_name &
          " not found in file " & h5f.name)
  else:
    result = h5f.datasets[dset_name]
    # in this case we still need to update e.g. shape
    # TODO: think about what else we might have to update!
    let dataspace_id = result.dataset_id.dataspace_id
    (result.shape, result.maxshape) = readShape(dataspace_id)
    # TODO: also read maxshape and chunksize if any

template isDataSet(h5_object: typed): bool =
  ## procedure to check whether object is a H5DataSet
  result: bool = false
  if h5_object is H5DataSet:
    result = true
  else:
    result = false
  result

proc parseShapeTuple[T: tuple](dims: T): seq[int] =
  ## parses the shape tuple handed to create_dataset
  ## receives a tuple of one datatype, which was previously
  ## determined using getCtype()
  ## inputs:
  ##    dims: T = tuple of type T for which we need to allocate
  ##              space
  ## outputs:
  ##    seq[int] = seq of int of length len(dims), containing
  ##            the size of each dimension of dset
  ##            Note: H5File needs to be aware of that size!
  for el in dims.fields:
    result.add int(el)

proc parseChunkSizeAndMaxShape(dset: H5DataSet, chunksize, maxshape: seq[int]): hid_t =
  ## proc to parse the chunk size and maxhshape arguments handed to the create_dataset()
  ## Takes into account the different possible scenarios:
  ##    chunksize: seq[int] = a sequence containing the chunksize: the dataset should be
  ##            chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.

  template invalidSize(s: seq[int]) =
    if s.len > 0:
      let invalid = s.anyIt(it == 0) or s.len != dset.shape.len
      if invalid:
        raise newException(ValueError, "Invalid value (dimension of size 0 " &
          "or missing dimension) in chunksize " & $chunksize & " or maxshape " &
          $maxshape & " while trying to create dataset: " & dset.name)
  # first of all check whether any dimension is given size 0 for chunksize or
  # maxshape. Invalid, raise exception
  maxshape.invalidSize
  chunksize.invalidSize

  template check(actions: untyped) =
    actions
    if result < 0:
      raise newException(HDF5LibraryError, "HDF5 library returned error on " &
        "call to `H5Pset_chunk`")

  if chunksize.len == 0 and maxshape.len == 0:
    # if neither given, maxshape will be current shape
    # and return 0
    dset.maxshape = dset.shape
    result = 0.hid_t
  # handle case where maxshape.len == 0 while chunksize.len > 0
  # issue #17
  elif chunksize.len > 0 and maxshape.len == 0:
    # in this case set maxshape to the larger of (dset.shape, chunksize)
    # element wise
    dset.maxshape = newSeq[int](dset.shape.len)
    for i in 0 ..< dset.shape.len:
      dset.maxshape[i] = max(dset.shape[i], chunksize[i])

    # user wishes to create unlimited sized or limited sized + resizable dataset
    # need to create chunked storage
    dset.chunksize = chunksize
    check:
      result = set_chunk(dset.dcpl_id, chunksize)
  elif chunksize.len > 0 and maxshape.len > 0:
    # check whether maxshape >= as chunksize
    if zip(chunksize, maxshape).anyIt(it[0] > it[1]):
      raise newException(ValueError, "Maxshape " & $maxshape & " needs to be " &
        ">= chunksize " & $chunksize & " in every dimension! Tried to create " &
        "dataset: " & $dset.name)
    else:
      # got chunksize and maxshape, checked if valid, so use them
      dset.maxshape = maxshape
      dset.chunksize = chunksize
      check:
        result = set_chunk(dset.dcpl_id, chunksize)
  elif chunksize.len == 0:
    # final case if chunksize not given, maxshape is given, else we would
    # be in the first branch. maxshape.len > 0 means user wants to cap
    # dataset size.
    if zip(dset.shape, maxshape).anyIt(it[0] > it[1]):
      raise newException(ValueError, "Maxshape " & $maxshape & " must not be " &
        "smaller than dataset shape " & $dset.shape & " for dataset " & $dset.name)
    else:
      dset.maxshape = maxshape
      # we chunk to the size of maxshape
      #dset.chunksize = maxshape
      #check:
      #  result = set_chunk(dset.dcpl_id, dset.chunksize)

proc create_dataset_in_file(h5file_id: hid_t, dset: H5DataSet): hid_t =
  ## proc to create a given dataset in the H5 file described by `h5file_id`

  # TODO: I think the first if branch is never used, because `maxshape` is always
  # set to the `shape` (if no maxshape is given) or the given max shape. Therefore
  # the check can never succeed. Ok if we only check for chunksize?
  let dataspace_id = simple_dataspace(dset.shape, dset.maxshape)
  if dset.maxshape.len == 0 and dset.chunksize.len == 0:
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dataspace_id,
                         H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  else:
    # in this case we are definitely working with chunked memory of some
    # sorts, which means that the dataset creation property list is set
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dataspace_id,
                         H5P_DEFAULT, dset.dcpl_id, H5P_DEFAULT)

proc create_dataset*[T: (tuple | int | seq)](
    h5f: H5FileObj,
    dset_raw: string,
    shape_raw: T,
    dtype: (typedesc | hid_t),
    chunksize: seq[int],
    maxshape: seq[int],
    filter: H5Filter,
    overwrite = false): H5DataSet =
  ## procedure to create a dataset given a H5file object. The shape of
  ## that type is given as a tuple, the datatype as a typedescription
  ## inputs:
  ##    h5file: H5FileObj = the H5FileObj received by H5file() into which the data
  ##                   set belongs
  ##    shape: T = the shape of the dataset, given as:
  ##           `int`: for 1D datasets
  ##           `tuple` / `seq`: for N dim. datasets
  ##    dtype = typedesc = a Nim typedesc (e.g. int, float, etc.) for that
  ##            dataset. If a sequence type is given it will create a variable length
  ##            dataset.
  ##    chunksize: seq[int] = a sequence containing the chunksize, the dataset should be
  ##            should be chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.
  ## outputs:
  ##    ... some dataset object, part of the file?!
  ## throws:
  ##    ... some H5 C related errors ?!
  if h5f.rw_type notin {H5F_ACC_EXCL, H5F_ACC_RDWR}:
    raise newException(ReadOnlyError, "Cannot create a dataset in " & $h5f.name &
      ", because the file is opened with read-only access!")

  var status: hid_t = hid_t(0)
  when T is int:
    # in case we hand an int as the shape argument, it means we wish to write
    # 1 column data to the file. In this case define the shape from here on
    # as a (shape, 1) tuple instead.
    var shape = (shape_raw, 1)
    # need to deal with the shape of the dataset to be created
    let shape_seq = parseShapeTuple(shape)
  elif T is tuple:
    var shape = shape_raw
    # need to deal with the shape of the dataset to be created
    let shape_seq = parseShapeTuple(shape)
  elif T is seq:
    let shape_seq = shape_raw

  # TODO: before call to create_simple and create2, we need to check whether
  # any such dataset already exists. Could include that in the opening procedure
  # by getting all groups etc in the file (by id, not reading the data)

  # remove any trailing / and insert potential missing root /
  var dset_name = formatName(dset_raw)

  # set up the dataset object
  var dset = newH5DataSet(dset_name)
  dset.file    = h5f.name
  dset.parent  = getParent(dset_name)

  # given the full dataset name, we need to check whether the group in which the
  # dataset is supposed to be placed, already exists
  let is_root = isInH5Root(dset_name)
  var group: H5Group
  if is_root == false:
    group = create_group(h5f, dset.parent)

  withDebug:
    echo "Getting parent Id of ", dset.name
  dset.parent_id = getParentId(h5f, dset)
  dset.shape = shape_seq
  # dset.parent_id = h5f.file_id

  # first get the appropriate datatype for the given Nim type
  when dtype is hid_t:
    let dtype_c = dtype
  else:
    let dtype_c = nimToH5type(dtype)
  # set the datatype as H5 type here, as its needed to create the dataset
  # the Nim dtype descriptors are set below from the data in the file
  dset.dtype_c = dtype_c
  dset.dtype_class = H5Tget_class(dtype_c)


  # create the dataset access property list
  dset.dapl_id = H5Pcreate(H5P_DATASET_ACCESS)
  # create the dataset create property list
  dset.dcpl_id = H5Pcreate(H5P_DATASET_CREATE)

  # in case we wish to use chunked storage (either resizable or unlimited size)
  # we need to set the chunksize on the dataset create property list
  try:
    status = dset.parseChunkSizeAndMaxShape(chunksize, maxshape)
    if status >= 0:
      # potentially apply filters
      dset.setFilters(filter)

      # check whether there already exists a dataset with the given name
      # first in H5FileObj:
      var exists = hasKey(h5f.datasets, dset_name)
      if exists == false or overwrite:
        # then check the actual file for a dataset with the given name
        # TODO: FOR NOW the location id given to H5Dopen2 is only the file id
        # once we have the parent properly determined, we can also check for
        # the parent (group) id!
        let in_file = existsInFile(h5f.file_id, dset.name)
        withDebug:
          echo "Checking if dataset exists via H5Lexists ", dset.name
          echo "Does exists ? ", in_file
        if overwrite or in_file == 0:
          # does not exist in file, so create
          withDebug:
            echo "Does not exist, so create dataset via H5create2 ", dset.name
            echo "with shape ", dset.shape
          if in_file != 0:
            # delete the element in the group
            discard group.delete(dset.name)
          dset.dataset_id = create_dataset_in_file(h5f.file_id, dset)
        elif in_file > 0:
          # in this case successful, dataset exists already
          exists = true
          # in this case open the dataset to read
          dset.dataset_id = H5Dopen2(h5f.file_id, dset.name, H5P_DEFAULT)
          # TODO: include a check about whether the opened dataset actually conforms
          # to what we wanted to create (e.g. same shape etc.)
        else:
          raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
            "in `existsInFile` from `create_dataset`")
      else:
        # else the dataset is already known and in the table, get it
        dset = h5f[dset.name.dset_str]
    else:
      raise newException(UnkownError, "Unkown error occured due to call to " &
        "`parseChunkSizeAndMaxhShape` returning with status = $#" % $status)
  except HDF5LibraryError:
    #let msg = getCurrentExceptionMsg()
    echo "Call to HDF5 library failed in `parseChunkSizeAndMaxShape` from `create_dataset`"
    raise

  # set the dtype fields of the object
  when dtype is hid_t:
    # for now we only support vlen arrays, later we need to
    # differentiate between the different H5T class types
    dset.dtype = "vlen"
    dset.dtypeAnyKind = dkSequence
  else:
    # in case of non vlen datatypes, don't take the immediate string of the datatype
    # but instead get it from the H5 datatype to conform to the same datatype, which
    # we read back from the file after writing
    dset.dtype = getDtypeString(dset.dataset_id)
    dset.dtypeAnyKind = parseEnum[DtypeKind]("dk" & dset.dtype, dkNone)
  # now get datatype base kind if vlen datatype
  if dset.dtypeAnyKind == dkSequence:
    # need to get datatype id (id specific to this dataset describing type),
    # then super, which is the base type of a VLEN type and finally convert
    # that to a AnyKind type
    dset.dtypeBaseKind = h5ToNimType(H5Tget_super(H5Dget_type(dset.dataset_id)))

  # now create attributes field
  dset.attrs = initH5Attributes(dset.dataset_id, dset.name, "H5DataSet")
  var dset_ref = new H5DataSet
  dset_ref = dset
  h5f.datasets[dset_name] = dset_ref
  # redundant:
  h5f.dataspaces[dset_name] = dset.dataspace_id

  result = dset

proc create_dataset*[T: (tuple | int | seq)](
    h5f: H5FileObj,
    dset_raw: string,
    shape_raw: T,
    dtype: (typedesc | hid_t),
    chunksize: seq[int] = @[],
    maxshape: seq[int] = @[],
    overwrite = false): H5DataSet {.inline.} =
  ## Wrapper around full `create_dataset` proc if no filter is being used.
  ## In this case chunksize and maxshape are optional
  let filter = H5Filter(kind: fkNone)
  result = h5f.create_dataset(dset_raw,
                              shape_raw,
                              dtype,
                              chunksize,
                              maxshape,
                              filter,
                              overwrite = overwrite)

proc write_dataset*[TT](h5f: H5FileObj, name: string, data: TT): H5DataSet =
  ## convenience proc to create a dataset and write data it immediately
  type T = getInnerType(TT)
  result = h5f.create_dataset(name, data.shape, T)
  result[result.all] = data

# proc create_dataset*[T: (tuple | int)](h5f: var H5Group, dset_raw: string, shape_raw: T, dtype: typedesc): H5DataSet =
  # convenience wrapper around create_dataset to create a dataset within a group with a
  # relative name
  # TODO: problematic to implement atm, because the function still needs access to the file object
  # Solutions:
  #  - either redefine the code in create_datasets to work on both groups or file object
  #  - or give the H5Group each a reference to the H5FileObj, so that it can access it
  #    by itself. This one feels rather ugly though...
  # Alternative solution:
  #  Instead of being able to call create_dataset on a group, we may simply define an
  #  active group in the H5FileObj, so that we can use relative paths from the last
  #  accessed group. This would complicate the code however, since we'd always have
  #  to check whether a path is relative or not!
  #elif maxshape.len == 0 and chunksize.len == 0:
    # this is the case of ordinary contiguous memory. In order to simplify our
    # lives, we use this case to set the dataset creation property list back to
    # the default. Somewhat ugly, because we introduce even more weird state changes,
    # which seem unnecessary
    # TODO: think about a better way to deal with creation of datasets either with or
    # without chunked memory
    # NOTE: create_dataset_in_file() should take care of this case.
    #dset.dcpl_id = H5P_DEFAULT

proc unsafeWrite*[T](dset: H5DataSet, data: ptr T, length: int) =
  ## procedure to write a raw `ptr T` to the H5 file.
  ## Note: we cannot do any checks on the given size of the `data` buffer,
  ## i.e. this is an unsafe proc!
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to write to
  ##    data: ptr[T] = A raw `ptr T` pointing to the first element of a buffer of
  ##         `T` values of `length`.
  ##    length: int = Length of the `data` buffer. We check whether the `length`
  ##         fits into the `shape` of the dataset we write to.

  var err: herr_t
  let shape = dset.shape
  withDebug:
    echo "shape is ", shape, " of dset ", dset.name
    echo "data is of " type(data).name, " and length = ", length

  # only write pointer data if shorter than size of dataset
  if dset.shape.foldl(a * b) <= length:
    if dset.dtype_class == H5T_VLEN:
      raise newException(ValueError, "Cannot write variable length data " &
        "using `unsafeWrite`!")
    else:
      err = H5Dwrite(dset.dataset_id,
                     dset.dtype_c,
                     H5S_ALL,
                     H5S_ALL,
                     H5P_DEFAULT,
                     data)
      if err < 0:
        withDebug:
          echo "Trying to write data_write ", data_write
        raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
          "while calling `H5Dwrite` in `unsafeWrite`")
  else:
    var msg = "Length of `data` in `unsafeWrite` exceeds size of dataset " &
     "Length: $#, Dataset: $#, Dataset shape: $#"
    msg = msg % [$length, $dset.name, $dset.shape]
    raise newException(ValueError, msg)

proc write_vlen*[T: seq, U](dset: H5DataSet, coord: seq[T], data: seq[U]) =
  ## check whether we have data for each coordinate

  var err: herr_t
  when U isnot seq:
    var mdata = @[data]
  else:
    var mdata = data
  let valid_data = if coord.len == mdata.len: true else: false
  if valid_data == true:
    let memspace_id = create_simple_memspace_1d(coord)
    # TODO: !!! check if selection of `coord` actually works correctly!!
    dset.select_elements(coord)
    var data_hvl = mdata.toH5vlen

    # DEBUGGING H5 calls
    withDebug:
      echo "memspace select ", H5Sget_select_npoints(memspace_id)
      echo "dataspace select ", H5Sget_select_npoints(dset.dataspace_id)
      echo "dataspace select ", H5Sget_select_elem_npoints(dset.dataspace_id)
      echo "dataspace is valid ", H5Sselect_valid(dset.dataspace_id)
      echo "memspace is valid ", H5Sselect_valid(memspace_id)

      var start: seq[hsize_t] = @[hsize_t(999), 999]
      var ending: seq[hsize_t] = @[hsize_t(999), 999]
      echo H5Sget_select_bounds(dset.dataspace_id, addr(start[0]), addr(ending[0]))
      echo "start and ending ", start, " ", ending

    err = H5Dwrite(dset.dataset_id,
                   dset.dtype_c,
                   memspace_id,
                   dset.dataspace_id,
                   H5P_DEFAULT,
                   addr(data_hvl[0]))
    if err < 0:
      withDebug:
        echo "Trying to write data_hvl ", data_hvl
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dwrite` in `write_vlen`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Sclose` in `write_vlen`")

  else:
    var msg = "Invalid coordinates or corresponding data to write in " &
      "`write_vlen`. Coord shape `$#`, data shape `$#`"
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

proc write_norm*[T: seq, U](dset: H5DataSet, coord: seq[T], data: seq[U]) =
  ## write procedure for normal (read non-vlen) data based on a set of coordinates 'coord'
  ## to write 'data' to. Need to have one element in data for each coord and
  ## data needs to be of shape corresponding to coord

  var err: herr_t
  # mutable copy
  var mdata = data
  let
    # check if coordinates are valid, i.e. each coordinate has rank of dataset
    # only checked whether dimensions are correct, we do NOT check whehter
    # coordinates are within the dataset!
    valid_coords = if coord[0].len == dset.shape.len: true else: false
    # check whehter we have data for each coordinate
    valid_data = if coord.len == mdata.len: true else: false
  if valid_coords == true and valid_data == true:
    let memspace_id = create_simple_memspace_1d(coord)
    # TODO: !!! check if selection of `coord` actually works correctly!!
    dset.select_elements(coord)
    err = H5Dwrite(dset.dataset_id,
                   dset.dtype_c,
                   memspace_id,
                   dset.dataspace_id,
                   H5P_DEFAULT,
                   addr(mdata[0]))
    if err < 0:
      withDebug:
        echo "Trying to write mdata ", mdata
      raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
        "while calling `H5Dwrite` in `write_norm`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
        "while calling `H5Sclose` in `write_norm`")
  else:
    var msg = "Invalid coordinates or corresponding data to write in " &
      "`write_norm`. Coord shape `$#`, data shape `$#`"
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)


template write*[T: seq, U](dset: H5DataSet, coord: seq[T], data: seq[U]) =
  ## template around both write fns for normal and vlen data
  if dset.dtype_class == H5T_VLEN:
    dset.write_vlen(coord, data)
  else:
    dset.write_norm(coord, data)

template write*[T: (SomeNumber | bool | char | string), U](dset: H5DataSet,
                                                           coord: seq[T],
                                                           data: seq[U]) =
  ## template around both write fns for normal and vlen data in case
  ## the coordinates are given as a seq of numbers (i.e. for 1D datasets!)
  if dset.dtype_class == H5T_VLEN:
    # we convert the list of indices to corresponding (y, x) coordinates, because
    # each VLEN table with 1 column, still is a 2D array, which only has the
    # x == 0 column
    dset.write_vlen(mapIt(coord, @[it, 0]), data)
  else:
    # need to differentiate 2 cases:
    # - either normal data is N dimensional (N > 1) in which case
    #   coord is a SINGLE coordinate for the array
    # - or data is 1D (read (N, 1) dimensional) in which case we have
    #   handed 1 or more indices to write 1 or more elements!
    if dset.shape[1] != 1:
      dset.write_norm(@[coord], data)
    else:
      # in case of 1D data, need to separate each element into 1 element
      dset.write_norm(mapIt(coord, @[it, 0]), data)

template write*[T: (seq | SomeNumber | bool | char | string)](dset: H5DataSet,
                                                              ind: int,
                                                              data: T,
                                                              column = false) =
  ## template around both write fns for normal and vlen data in case we're dealing with 1D
  ## arrays and want to write a single value at index `ind`. Allows for broadcasting along
  ## row or column
  ## throws:
  ##    ValueError: in case data does not fit to whole row or column, if we want to write
  ##                whole row or column by giving index and broadcasting the indices to
  ##                cover whole row
  when T is seq:
    # if this is the case we either want to write a whole row (2D array) or
    # a single value in VLEN data
    if dset.dtype_class == H5T_VLEN:
      # does not make sense for tensor
      dset.write(@[ind], data)
    else:
      # want to write the whole row, need to broadcast the index
      let shape = dset.shape
      if data.len != shape[0] and data.len != shape[1]:
        let msg = "Cannot broadcast ind to dataset in `write`, because " &
          "data does not fit into array row / column wise. data.len = $# " &
          "dset.shape = $#" % [$data.len, $dset.shape]
        raise newException(ValueError, msg)
      # NOTE: currently broadcasting ONLY works on 2D arrays!
      let inds = toSeq(0..<shape[1])
      var coord: seq[seq[int]]
      if column == true:
        # fixed column
        coord = mapIt(inds, @[it, ind])
      else:
        # fixed row
        coord = mapIt(inds, @[ind, it])
      dset.write(coord, data)
  else:
    # in this case we're dealing with a single value for a single element
    # do not have to differentiate between VLEN and normal data
    dset.write(@[ind], @[data])

proc `[]=`*[T](dset: H5DataSet, ind: DsetReadWrite, data: seq[T]) =
  ## procedure to write a sequence of array to a dataset
  ## will be given to HDF5 library upon call, H5DataSet object
  ## does not store the data
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##          about dataset shape, dtype etc. to write to
  ##    ind: DsetReadWrite = indicator telling us to write whole dataset,
  ##         used to differentiate from the case in which we only write a hyperslab
  ##    data: openArray[T] = any array type containing the data to be written
  ##         needs to be of the same size as the shape given during creation of
  ##         the dataset or smaller
  ## throws:
  ##    ValueError: if the shape of the input dataset is different from the reserved
  ##         size of the dataspace on which we wish to write in the H5 file
  ##         TODO: create an appropriate Exception for this case!
  # TODO: IMPORTANT: think about whether we should be using array types instead
  # of a dataspace of certain dimensions for arrays / nested seqs we're handed

  var err: herr_t

  if ind == RW_ALL:
    let shape = dset.shape
    withDebug:
      echo "shape is ", shape, " of dset ", dset.name
      echo "shape is a ", type(shape).name, " and data is a "
      echo type(data).name, " and data.shape = ", data.shape
    # check whether we will write a 1 column dataset. If so, relax
    # requirements of shape check. In this case only compare 1st element of
    # shapes. We compare shape[1] with 1, because atm we demand VLEN data to be
    # a 2D array with one column. While in principle it's a N element vector
    # it is always promoted to a (N, 1) array.
    if (shape.len == 2 and shape[1] == 1 and shape(data)[0] == dset.shape[0]) or
      data.shape == dset.shape:

      if dset.dtype_class == H5T_VLEN:
        # TODO: should we also check whether data really is 1D? or let user
        # deal with that? will flatten the array anyways, so in case on tries
        # to write a 2D array as vlen, the flattened array will end up as vlen
        # in the file in this case we need to prepare the data further by
        # assigning the data to a hvl_t struct
        when T is seq:
          var mdata = data
          var data_hvl = mdata.toH5vlen
          err = H5Dwrite(dset.dataset_id,
                         dset.dtype_c,
                         H5S_ALL,
                         H5S_ALL,
                         H5P_DEFAULT,
                         addr(data_hvl[0]))
          if err < 0:
            withDebug:
              echo "Trying to write data_hvl ", data_hvl
            raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
                               "while calling `H5Dwrite` in `[All]=`")
        else:
          echo "VLEN datatype does not make sense, if the data is of type seq[$#]" % T.name
          echo "Use normal datatype instead. Or did you only hand a single element"
          echo "of your vlen data?"
      else:
        # NOTE: for some reason if we don't specify `seqmath` for `flatten`, the
        # correct proc is not found
        var data_write = seqmath.flatten(data)
        err = H5Dwrite(dset.dataset_id,
                       dset.dtype_c,
                       H5S_ALL,
                       H5S_ALL,
                       H5P_DEFAULT,
                       addr(data_write[0]))
        if err < 0:
          withDebug:
            echo "Trying to write data_write ", data_write
          raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
            "while calling `H5Dwrite` in `[All]=`")
    else:
      var msg = "Wrong input shape of data to write in `[]=` while accessing " &
        "`$#`. Given shape `$#`, dataset has shape `$#`"
      msg = msg % [$dset.name, $data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    echo "Dataset not assigned anything, ind: DsetReadWrite invalid"

proc `[]=`*[T](dset: H5DataSet, inds: HSlice[int, int], data: seq[T]) =
  ## procedure to write a sequence of array to a dataset
  ## will be given to HDF5 library upon call, H5DataSet object
  ## does not store the data
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to write to
  ##    inds: HSlice[int, int] = slice of a range, which to write in dataset
  ##    data: openArray[T] = any array type containing the data to be written
  ##         needs to be of the same size as the shape given during creation of
  ##         the dataset or smaller

  # only write slice of dset by using hyperslabs
  raise newException(NotImplementedError, "This proc is not properly implemented!")

  # TODO: change this function to do what it's supposed to!
  if dset.shape == data.shape:
    # in this case run over all dimensions and flatten array
    withDebug:
      echo "shape before is ", data.shape
      echo data
    var data_write = flatten(data)
    let err = H5Dwrite(dset.dataset_id,
                       dset.dtype_c,
                       H5S_ALL,
                       H5S_ALL,
                       H5P_DEFAULT,
                       addr(data_write[0]))
    if err < 0:
      withDebug:
        echo "Trying to write data_write from slice ", data_write
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dwrite` in `[Slice]=`")
  else:
    raise newException(HDF5LibraryError, "Length of data " & data.len & " does " &
      "not match number of given indices to write: " & inds.len)

proc convertType*(h5dset: H5DataSet, dt: typedesc):
  proc(dset: H5DataSet): seq[dt] {.nimcall.} =
  ## return a converter proc, which casts the data from `h5dset` to the desired
  ## datatype `dtype`
  ## Note: only numerical types are supported!
  # for some reason we need this very weird conversion taking the type
  # explicitly of `tt`
  # make sure it's a no-op if we don't convert the type
  template fromTo(dset: untyped, fromType, toType: untyped): untyped =
    when toType is fromType:
      dset[fromType]
    else:
      type tt = toType
      dset[fromType].mapIt(tt(it))

  case h5dset.dtypeAnyKind
  of dkFloat32: result = proc(d: H5DataSet): seq[dt] = d.fromTo(float32, dt)
  of dkFloat64: result = proc(d: H5DataSet): seq[dt] = d.fromTo(float64, dt)
  of dkInt: result = proc(d: H5DataSet): seq[dt] = d.fromTo(int, dt)
  of dkInt8: result = proc(d: H5DataSet): seq[dt] = d.fromTo(int8, dt)
  of dkInt16: result = proc(d: H5DataSet): seq[dt] = d.fromTo(int16, dt)
  of dkInt32: result = proc(d: H5DataSet): seq[dt] = d.fromTo(int32, dt)
  of dkInt64: result = proc(d: H5DataSet): seq[dt] = d.fromTo(int64, dt)
  of dkUint8: result = proc(d: H5DataSet): seq[dt] = d.fromTo(uint8, dt)
  of dkUint16: result = proc(d: H5DataSet): seq[dt] = d.fromTo(uint16, dt)
  of dkUint32: result = proc(d: H5DataSet): seq[dt] = d.fromTo(uint32, dt)
  of dkUint64: result = proc(d: H5DataSet): seq[dt] = d.fromTo(uint64, dt)
  else:
    echo "it's of type ", h5dset.dtypeAnyKind
    result = proc(d: H5DataSet): seq[dt] = discard

proc select_elements[T](dset: H5DataSet, coord: seq[T]): hid_t {.inline, discardable.} =
  ## convenience proc to select specific coordinates in the dataspace of
  ## the given dataset
  ## NOTE: By using the `dataspace_id` proc on a `H5DataSet` to get a dataspace
  ## id, we cannot select elements, since each call gives us a new (!) dataspace id!
  ## A specific dataset id hence does *NOT* have a single dataspace id attached to
  ## it! This is why reading from selected coordinates failed!
  ## TODO: check whether reading specific coordinates also fails!
  ## Do we have a test for that?
  # first flatten coord tuples
  var flat_coord = mapIt(coord.flatten, hsize_t(it))
  result = dset.dataspace_id
  let res = H5Sselect_elements(result,
                               H5S_SELECT_SET,
                               csize_t(coord.len),
                               addr(flat_coord[0]))
  if res < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `select_elements` " &
      "after a call to `H5Sselect_elements` with return code " & $res)

proc read*[T: seq, U](dset: H5DataSet, coord: seq[T], buf: var seq[U]) =
  ## proc to read specific coordinates (or single values) from a dataset
  ## inputs:
  ##   dset: var H5DataSet = mutable copy of dataset from which to read
  ##   coord: seq[T] = seq of seqs, where each element contains a seq, which
  ##     describes a single scalar in the dataset.
  ##     Each element needs to have same dimensionality as dataset
  ##     Note: currently NOT checked, whether elements are within the dataset
  ##     If not, a H5 error occurs
  ## throws:
  ##   IndexError = raised if the shape of the a coordinate (check only first, be careful!)
  ##     does not match the shape of the dataset. Otherwise would cause H5 library error
  # select the coordinates in the dataset
  if coord[0].len != dset.shape.len:
    raise newException(IndexError, "Coordinate shape mismatch. Coordinate has " &
      "dimension $#, dataset is dimension $#!" % [$coord[0].len, $dset.shape.len])

  # select all elements from the coordinate seq
  let dspace = dset.select_elements(coord)
  let memspace_id = create_simple_memspace_1d(coord)

  # now read the elements
  if buf.len == coord.len:
    discard H5Dread(dset.dataset_id,
                    dset.dtype_c,
                    memspace_id,
                    dspace,
                    H5P_DEFAULT,
                    addr(buf[0]))

  else:
    echo "Provided buffer is not of same length as number of points to read"
  # close memspace again
  discard H5Sclose(memspace_id)

proc readAs*[T: SomeNumber](dset: H5DataSet, indices: seq[int], dtype: typedesc[T]):
                seq[dtype] =
  ## read some indices and returns the data converted to `dtype`
  case dset.dtypeAnyKind
  of dkFloat32: result = dset[indices, float32].mapIt(dtype(it))
  of dkFloat64: result = dset[indices, float64].mapIt(dtype(it))
  of dkInt:     result = dset[indices, int].mapIt(dtype(it))
  of dkInt8:    result = dset[indices, int8].mapIt(dtype(it))
  of dkInt16:   result = dset[indices, int16].mapIt(dtype(it))
  of dkInt32:   result = dset[indices, int32].mapIt(dtype(it))
  of dkInt64:   result = dset[indices, int64].mapIt(dtype(it))
  of dkUint8:   result = dset[indices, uint8].mapIt(dtype(it))
  of dkUint16:  result = dset[indices, uint16].mapIt(dtype(it))
  of dkUint32:  result = dset[indices, uint32].mapIt(dtype(it))
  of dkUint64:  result = dset[indices, uint64].mapIt(dtype(it))
  else:
    echo "Unsupported datatype for H5DataSet to convert to some number!"
    echo "Dset dtype: " & $dset.dtypeAnyKind & "; requested target: " &
      name(dtype)
    result = @[]

proc readConvert*[T: SomeNumber](dset: H5DataSet, indices: seq[int], dtype: typedesc[T]):
                seq[dtype] =
  {.deprecated: "This proc is deprecated in favor of `readAs`!".}
  readAs(dset, indices, dtype)

proc readAs*[T: SomeNumber](dset: H5DataSet, dtype: typedesc[T]): seq[dtype] =
  ## read some indices and returns the data converted to `dtype`
  case dset.dtypeAnyKind
  of dkFloat32: result = dset[float32].mapIt(dtype(it))
  of dkFloat64: result = dset[float64].mapIt(dtype(it))
  of dkInt:     result = dset[int].mapIt(dtype(it))
  of dkInt8:    result = dset[int8].mapIt(dtype(it))
  of dkInt16:   result = dset[int16].mapIt(dtype(it))
  of dkInt32:   result = dset[int32].mapIt(dtype(it))
  of dkInt64:   result = dset[int64].mapIt(dtype(it))
  of dkUint8:   result = dset[uint8].mapIt(dtype(it))
  of dkUint16:  result = dset[uint16].mapIt(dtype(it))
  of dkUint32:  result = dset[uint32].mapIt(dtype(it))
  of dkUint64:  result = dset[uint64].mapIt(dtype(it))
  else:
    echo "Unsupported datatype for H5DataSet to convert to some number!"
    echo "Dset dtype: " & $dset.dtypeAnyKind & "; requested target: " &
      name(dtype)
    result = @[]

proc readAs*[T: SomeNumber](h5f: H5FileObj, dset: string, dtype: typedesc[T]): seq[dtype] =
  ## reads data from the H5file without an intermediate return of a `H5DataSet`
  let dset = h5f.get(dset.dset_str)
  result = dset.readAs(dtype)

proc read*[T](dset: H5DataSet, buf: var seq[T]) =
  ## read whole dataset
  if buf.len == foldl(dset.shape, a * b, 1):
    discard H5Dread(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    addr(buf[0]))
    # now write data back into the buffer
    # for ind in 0..data.high:
    #   let inds = getIndexSeq(ind, shape)
    #   buf.set_element(inds, data[ind])
  else:
    var msg = "Wrong input shape of buffer to write to in `read`. " &
      "Buffer shape `$#`, dataset has shape `$#`"
    msg = msg % [$buf.shape, $dset.shape]
    raise newException(ValueError, msg)

proc read*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T]): seq[seq[T]] =
  ## procedure to read the data of an existing dataset based on variable length data
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    t: hid_t = special type of variable length data type.
  ##    dtype: typedesc[T] = Nim datatype
  ## outputs:
  ##    seq[dtype]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset
  ##         TODO: return the correct data shape!
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset

  # TODO: combine this proc with the one above, by getting the data type
  # in this proc, checking for VLEN and if so, use dtype to create the special
  # type. Do it similarly to write_norm and write_vlen, split into two

  var err: herr_t
  # check whether t is variable length
  let basetype = h5ToNimType(t)
  if basetype != dset.dtypeAnyKind:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given " &
                       "`$#`, dset is `$#`" % [$t, $dset.dtype])

  let n_elements = dset.shape[0]
  # create a flat sequence of the size of the dataset in the H5 file, then read data
  # cannot use the result sequence, since we need to hand the address of the sequence to
  # the H5 library
  var data = newSeq[hvl_t](n_elements)
  err = H5Dread(dset.dataset_id,
                dset.dtype_c,
                H5S_ALL,
                H5S_ALL,
                H5P_DEFAULT,
                addr(data[0]))

  result = vlenToSeq[dtype](data)
  # since we have in effect copied the whole array, we can now safely let the H5 library
  # reclaim the memory, which it alloc'd
  let dspace_id = H5Dget_space(dset.dataset_id)
  err = H5Dvlen_reclaim(dset.dtype_c, dspace_id, H5P_DEFAULT, addr(data[0]))
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dread` in full VLEN `read`")

template readVlen*[T](dset: H5DataSet, dtype: typedesc[T]): seq[seq[T]] =
  ## Convenience template to avoid having to define the special type to read a
  ## variable length dataset.
  if not dset.isVlen:
    raise newException(IOError, "Given datatype " & dset.name & " is not a " &
      "variable length dataset!")
  dset.read(special_type(dtype), dtype)

proc read*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T], idx: int): seq[T] =
  ## procedure to read a single element form a variable length dataset.
  ## NOTE: this uses hyperslab reading!
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    idx: int = the single element to read
  ## outputs:
  ##    seq[T]: a single variable length element of `dset`
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  let dsetLen = dset.shape[0]
  if idx > dsetLen:
    raise newException(IndexError, "Coordinate shape mismatch. Index " &
      "is $#, dataset is dimension $#!" % [$idx, $dsetLen])
  result = dset.read_hyperslab_vlen(dtype, @[idx, 0], @[1, 1])[0]

proc read*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T], indices: seq[int]): seq[seq[T]] =
  ## procedure to read a single element form a variable length dataset.
  ## NOTE: each element is read via a single call to read hyperslab!
  ## For consecutive elements, read manually via read hyperslab!
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    indices: seq[int] = the variable length elements to read
  ## outputs:
  ##    seq[T]: a single variable length element of `dset`
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  result = newSeqOfCap[seq[dtype]](indices.len)
  for idx in indices:
    result.add dset.read(t, dtype, idx)

proc read*[T](dset: H5DataSet, t: typedesc[T],
              allowVlen = false): seq[T] =
  ## procedure to read the data of an existing dataset and return it as a 1D sequence.
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    t: typedesc[T] = the Nim datatype of the dataset to be read
  ##    allowVlen: bool = if true it allows to read variable length data. Note this
  ##         means the vlen data will be flattened to 1D!
  ## outputs:
  ##    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset
  ##         TODO: return the correct data shape!
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  if dset.isVlen and allowVlen:
    result = dset.readVlen(t).flatten
  else:
    if not typeMatches(t, dset.dtype):
      raise newException(ValueError, "Wrong datatype as arg to `[]`. " &
        "Given `$#`, dset is `$#`" % [$t, $dset.dtype])
    # create a flat sequence of the size of the dataset in the H5 file, then read data
    # cannot use the result sequence, since we need to hand the address of the sequence to
    # the H5 library
    let
      shape = dset.shape
      n_elements = foldl(shape, a * b)
    result = newSeq[T](n_elements)
    dset.read(result)

proc `[]`*[T](dset: H5DataSet, t: typedesc[T]): seq[T] =
  ## Reads the given dataset into a `seq[T]`. If the given datatype does not
  ## match the datatype of the data stored in `dset`, a `ValueError` will be
  ## raised.
  result = dset.read(t)

proc `[]`*[T](dset: H5DataSet, ind: int, t: typedesc[T]): T =
  ## convenience proc to return a single element from a dataset
  ## mostly useful to read one element from a 1D dataset. In case of
  ## N-D datasets, still only a single element
  ## e.g.: ind == 0 -> [0, 0, ..., 0]
  ## will be read. In case of a NxNx...xN dataset, we will
  ## read from the diagonal (ind broadcasted to all dimensions)
  ## Implementation detail, due to no return value
  ## overloading.
  ## In case of different sizes of each dimensino, we still broadcast
  ## the same value, unless the size the index is larger than the
  ## size in one dimension, in which case we take the last element.
  ## inputs:
  ##   dset: var H5DataSet = the dataset from which to read an element
  ##   ind: int = the index at which to read the scalar
  ##   t: typedesc[T] = the datatype of the dataset. Needs to be given
  ##     to define the return value of the proc
  ## outputs:
  ##   T = scalar read from position `ind`
  ## throws:
  ##   HDF5LibraryError = in case a call to the H5 library fails
  let shape = dset.shape
  # broadcast coord to all dimensions. Needs to be packed into a sequence
  # since read() expects seq[seq[T]]
  # Done by checking for each dimension whether the given index still "fits"
  # into the dimension. If yes, `ind` is taken, else we use the last element
  # in that dimension (-> diagonal if
  let coord = @[mapIt(toSeq(0 .. shape.high), if ind < shape[it]: ind else: shape[it] - 1)]
  # create buffer seq of size 1 to read data into
  var buf = newSeq[t](1)
  dset.read(coord, buf)
  # return element of bufer
  result = buf[0]

proc `[]`*[T](dset: H5DataSet, indices: seq[int], t: typedesc[T]): seq[T] =
  ## Same as above proc, but reads several indices at once
  ## inputs:
  ##   dset: var H5DataSet = the dataset from which to read an element
  ##   indices: seq[int] = the indices from which to read
  ##   t: typedesc[T] = the datatype of the dataset. Needs to be given
  ##     to define the return value of the proc
  ## outputs:
  ##   T = scalar read from position `ind`
  ## throws:
  ##   HDF5LibraryError = in case a call to the H5 library fails
  let shape = dset.shape
  # broadcast coord to all dimensions. Needs to be packed into a sequence
  # since read() expects seq[seq[T]]
  # Done by checking for each dimension whether the given index still "fits"
  # into the dimension. If yes, `ind` is taken, else we use the last element
  # in that dimension (-> diagonal if
  var coords: seq[seq[int]]
  for idx in indices:
    coords.add @[mapIt(toSeq(0 .. shape.high), if idx < shape[it]: idx else: shape[it] - 1)]
  # create buffer seq of size 1 to read data into
  var buf = newSeq[t](indices.len)
  dset.read(coords, buf)
  # return element of bufer
  result = buf

proc `[]`*[T](dset: H5DataSet, indices: seq[int], t: hid_t, dtype: typedesc[T]): seq[seq[T]] =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, indices)

proc `[]`*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T], indices: seq[int]): seq[seq[T]]
  {.deprecated: "This proc is deprecated! Use the version with `indices` as the second argument!".} =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, indices)

proc `[]`*[T](dset: H5DataSet, idx: int, t: hid_t, dtype: typedesc[T]): seq[T] =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, idx)

proc `[]`*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T], idx: int): seq[T]
  {.deprecated: "This proc is deprecated! Use the version with `idx` as the second argument!".} =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, idx)

proc `[]`*[T](dset: H5DataSet, t: hid_t, dtype: typedesc[T]): seq[seq[T]] =
  ## reads a whole variable length dataset, wrapper around `read`
  result = read(dset, t, dtype)

template `[]`*(h5f: H5FileObj, name: dset_str): H5DataSet =
  ## a simple wrapper around get for datasets
  h5f.get(name)

proc `[]`*[T](h5f: H5FileObj, name: string, dtype: typedesc[T]): seq[T] =
  ## reads data from the H5file without an intermediate return of a `H5DataSet`
  result = h5f.get(name.dset_str).read(dtype)

proc `[]`*[T](h5f: H5FileObj, name: string, t: hid_t, dtype: typedesc[T]):
                seq[seq[T]] =
  ## reads variable length data from the H5file without an intermediate return
  ## of a `H5DataSet`
  ## `t` is a variable length `special_type` created with the proc of the same
  ## name
  result = h5f.get(name.dset_str).read(t, dtype)

template `[]`*(grp: H5Group, name: dset_str): H5DataSet =
  ## Accessor relative from a basegroup to a dataset
  grp.file_ref[name]

template withDset*(h5dset: H5DataSet, actions: untyped) =
  ## convenience template to read a dataset from the file and perform actions
  ## with that dataset, without having to manually check the data type of the
  ## dataset
  let dtype = if h5dset.dtypeAnyKind == dkSequence: h5dset.dtypeBaseKind
              else: h5dset.dtypeAnyKind
  case dtype
  of dkBool:
    let dset {.inject.} = h5dset.read(bool, allowVlen = true)
    actions
  of dkChar:
    let dset {.inject.} = h5dset.read(char, allowVlen = true)
    actions
  of dkString:
    let dset {.inject.} = h5dset.read(string, allowVlen = true)
    actions
  of dkFloat32:
    let dset {.inject.} = h5dset.read(float32, allowVlen = true)
    actions
  of dkFloat64:
    let dset {.inject.} = h5dset.read(float64, allowVlen = true)
    actions
  of dkInt8:
    let dset {.inject.} = h5dset.read(int8, allowVlen = true)
    actions
  of dkInt16:
    let dset {.inject.} = h5dset.read(int16, allowVlen = true)
    actions
  of dkInt32:
    let dset {.inject.} = h5dset.read(int32, allowVlen = true)
    actions
  of dkInt64:
    let dset {.inject.} = h5dset.read(int64, allowVlen = true)
    actions
  of dkUint8:
    let dset {.inject.} = h5dset.read(uint8, allowVlen = true)
    actions
  of dkUint16:
    let dset {.inject.} = h5dset.read(uint16, allowVlen = true)
    actions
  of dkUint32:
    let dset {.inject.} = h5dset.read(uint32, allowVlen = true)
    actions
  of dkUint64:
    let dset {.inject.} = h5dset.read(uint64, allowVlen = true)
    actions
  else:
    echo "WARNING: `withDset` nothing to do, dataset is of type ", h5dset.dtypeAnyKind
    discard

proc h5SelectHyperslab(dspace_id: hid_t, offset, count, stride, blk: var seq[hsize_t]): herr_t {.inline.} =
  ## wrapper for the H5 C hyperslab selection function
  ## inputs:
  ##    dspace_id: hid_t = dataspace id of the dataspace on which hyperslab selection is done
  ##      (might be dataspace of a dataset or different memory space)
  ##    offset, count, stride, blk: var seq[hsize_t] = mutable sequences of hyperslab selections
  ##      neeeded as var, since we have to hand the address of the start of the data
  ## outputs:
  ##    herr_t = return value of the C function
  ## throws:
  ##    HDF5LibraryError = in case a call to the HDF5 library fails
  withDebug:
    echo "Selecting the following hyperslab"
    echo "offset: ", offset
    echo "count:  ", count
    echo "stride: ", stride
    echo "block:  ", blk
  result = H5Sselect_hyperslab(dspace_id,
                               H5S_SELECT_SET,
                               addr(offset[0]),
                               addr(stride[0]),
                               addr(count[0]),
                               addr(blk[0]))

proc parseHyperslabSelection(offset, count: seq[int], stride, blk: seq[int] = @[]):
                            (seq[hsize_t], seq[hsize_t], seq[hsize_t], seq[hsize_t]) =
  ## proc to perform parsing and type conversion of input selections for hyperslabs
  ## notation follows HDF5 hyperslab notation
  ## inputs:
  ##    offset, count, stride, blk: seq[int] = hyperslab selections
  ## outputs:
  ##    tuple of type converted seq[int] -> seq[hsize_t],
  ## throws: nil, pure: true
  var
    moffset = mapIt(offset, hsize_t(it))
    mcount  = mapIt(count, hsize_t(it))
    mstride: seq[hsize_t] = @[]
    mblk: seq[hsize_t] = @[]
  if stride.len > 0:
    mstride = mapIt(stride, hsize_t(it))
  if blk.len > 0:
    mblk    = mapIt(blk, hsize_t(it))
  # in case of empty stride or block seqs, set them to the required definition
  # i.e. values of 1 for each dimension
  if stride.len == 0:
    mstride = mapIt(toSeq(0..offset.high), hsize_t(1))
  if blk.len == 0:
    mblk = mapIt(toSeq(0..offset.high), hsize_t(1))
  result = (moffset, mcount, mstride, mblk)

proc select_hyperslab(dset: H5DataSet,
                      offset,
                      count: seq[int],
                      stride, blk: seq[int] = @[]): hid_t =
  ## high level proc to select a hyperslab on a H5DataSet. Calls low level
  ## access proc h5SelectHyperslab given the dataspace of `dset`, select a
  ## hyperslab of it using `offset`, `stride`, `count` and `blk` for which
  ## all needs to hold:
  ## dset.shape.len == offset.shape.len, i.e. they need to be of the same
  ## rank as dset is we currently set the hyperslab selection such that
  ## previous selections are overwritten (2nd argument)
  ## outputs:
  ##   hid_t: the dataspace on which the hyperslab selection was performed
  var
    err: herr_t

  # parse and convert the hyperslab selection sequences
  var (moffset, mcount, mstride, mblk) = parseHyperslabSelection(offset,
                                                                 count,
                                                                 stride,
                                                                 blk)

  # and perform the selection on this dataspace
  result = dset.dataspace_id
  err = h5SelectHyperslab(result, moffset, mcount, mstride, mblk)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Sselect_hyperslab` in `select_hyperslab`")

proc write_hyperslab*[T](dset: H5DataSet,
                         data: seq[T],
                         offset,
                         count: seq[int],
                         stride, blk: seq[int] = @[]) =
  ## proc to select a hyperslab and write to it
  ## The HDF5 notation for hyperslabs is used.
  ## See sec. 7.4.1.1 in the HDF5 user's guide:
  ## https://support.hdfgroup.org/HDF5/doc/UG/HDF5_Users_Guide-Responsive%20HTML5/index.html
  # if no data given, simply return
  # TODO: parse hyperslab selection and make sure data is same number as hyperslab
  # covers!
  if data.len == 0:
    return

  var err: herr_t

  var memspace_id: hid_t
  if dset.dtype_class == H5T_VLEN:
    # in case of variable length data, the dataspace should be of layout
    # (# VLEN elements, 1)
    let memspaceShape = @[data.shape[0], 1]
    memspace_id = simple_dataspace(memspaceShape)
    withDebug:
      echo "Data shape ", data.shape
      echo "Data type class ", dset.dtype_class
      echo "memspace select ", H5Sget_select_npoints(memspace_id)
      echo "dataspace is valid ", H5Sselect_valid(dset.dataspace_id)
      echo "memspace is valid ", H5Sselect_valid(memspace_id)
      var start: seq[hsize_t] = @[hsize_t(999), 999]
      var ending: seq[hsize_t] = @[hsize_t(999), 999]
      echo H5Sget_select_bounds(dset.dataspace_id, addr(start[0]), addr(ending[0]))
      echo "start and ending ", start, " ", ending

    var md = data
    when T is seq:
      # in case we're dealing with variable length data, we know that the `data` is always
      # a nested `seq`, i.e. `T` is a `seq`. Need this guard, because otherwise code, which
      # does not actually run into the "VLEN" branch here will still be compiled against
      # it. The call to `toH5vlen` will fail, since it's a template which does not return
      # anything for `T isnot seq`.
      # TODO: replace template by typed template / proc?
      var mdata_hvl = md.toH5vlen
      let hyperslab_id = dset.select_hyperslab(offset, count, stride, blk)
      err = H5Dwrite(dset.dataset_id,
                     dset.dtype_c,
                     memspace_id,
                     hyperslab_id,
                     H5P_DEFAULT,
                     addr(mdata_hvl[0]))
      if err < 0:
        withDebug:
          echo "Trying to write VLEN data with shape ", memspaceShape
        raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
          "calling `H5Dwrite` in `write_hyperslab` trying to write VLEN data.")
  else:
    # flatten the data array to be written
    var mdata = data.flatten

    memspace_id = simple_dataspace(data.shape)
    let hyperslab_id = dset.select_hyperslab(offset, count, stride, blk)
    withDebug:
      echo "Selected now write space id ", hyperslab_id
    err = H5Dwrite(dset.dataset_id,
                   dset.dtype_c,
                   memspace_id,
                   hyperslab_id,
                   H5P_DEFAULT,
                   addr(mdata[0]))
    if err < 0:
      withDebug:
        echo "Trying to write mdata with shape ", mdata.shape
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dwrite` in `write_hyperslab`")

  err = H5Sclose(memspace_id)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Sclose` in `write_hyperslab`")

proc sizeOfHyperslab(offset, count, stride, blk: seq[hsize_t]): int =
  ## proc to calculate the number of elements in a defined
  ## hyperslab
  ## notation based on HDF5 hyperslab notation
  ## inputs:
  ##    offset, count, stride, blk: seq[int] = hyperslab selectors
  ## outputs:
  ##    int = number of elements in the selected hyperslab
  ## throws: nil, pure: true
  ## Note: negative values in specific dimensions are interpreted
  ##   as 0

  # stride is irrelevant for total size, iff the selected stride
  # is larger than the selected block
  # offset is always irrelevant for size
  # TODO: include this. We currently overestimate the size of
  # the sequence, if the user inserts e.g.
  # count = @[2, 2], stride = @[2, 2], blk = @[4, 4]
  # because due to the stride, there'd be an overlap of 2 x 4 elements
  # for each blk
  let
    mcount = mapIt(count, if it < 0: hsize_t(0) else: it)
    mblk   = mapIt(blk, if it < 0: hsize_t(0) else: it)
  result = int(foldl(mcount, a * b) * foldl(mblk, a * b))

proc hyperslab(dset: H5DataSet,
               offset, count, stride, blk: seq[int],
               full_output: bool): (hid_t, hid_t, int) =
  ## performs the hyperslab selection on `dset`, potentially respecting
  ## `full_output` (meaning output has shape of `dset`, even if fewer elements
  ## are read, unselected is zeroed).
  ## Returns the memory space id, the hyperslab ib for the selection and the
  ## number of selected elements.
  ## Basically combines `parseHyperslabSelection`, `select_hyperslab` and the
  ## calculation of the number of elements given `full_output`.
# parse the input hyperslab selections
  var (moffset, mcount, mstride, mblk) = parseHyperslabSelection(offset,
                                                                 count,
                                                                 stride,
                                                                 blk)

  # get a memory space for the size of the whole dataset, on which we will perform the
  # selection of the hyperslab we wish to read
  var memspace_id: hid_t
  if full_output == true:
    memspace_id = simple_dataspace(dset.shape)
    # in this case need to perform selection of the hyperslab on memspace
    # as well as dataspace
    let err = h5SelectHyperslab(memspace_id, moffset, mcount, mstride, mblk)
    if err < 0:
      raise newException(HDF5LibraryError,
                         "Call to HDF5 library failed while calling " &
                           "`h5SelectHyperslab` in `read_hyperslab`")
  else:
    # combine count and blk to get the size of the data we read as a sequence
    let shape = mapIt(zip(mcount, mblk), it[0] * it[1])
    memspace_id = simple_dataspace(shape)

  # perform hyperslab selection on dataspace
  let hyperslab_id = dset.select_hyperslab(offset, count, stride, blk)

  # calc lenght of needed output sequence
  var n_elements: int
  if full_output == false:
    n_elements = sizeOfHyperslab(moffset, mcount, mstride, mblk)
  else:
    n_elements = foldl(dset.shape, a * b)

  result = (memspace_id, hyperslab_id, n_elements)

proc read_hyperslab*[T](dset: H5DataSet, dtype: typedesc[T],
                        offset, count: seq[int], stride, blk: seq[int] = @[],
                        full_output = false): seq[T] =
  ## proc to read an arbitrary hyperslab from a given dataset.
  ## HDF5 notation for hyperslab selection applies
  ## See sec. 7.4.1.1 in the HDF5 user's guide:
  ## https://support.hdfgroup.org/HDF5/doc/UG/HDF5_Users_Guide-Responsive%20HTML5/index.html
  ## inputs:
  ##    dset: var H5DataSet = dataset from which we read hyperslab
  ##    dtype: datatype of the dataset, needed for the proc to return a
  ##           sequence of said type
  ##    offset, count, stride, blk: seq[int] = selection sequences, see note above
  ##      to seelect a single rectangle in the dataset, leave stride and blk empty
  ##    full_output: bool = if this flag is set to true, return a sequence of the
  ##      size of dset.shape with all zero entries except the elements read by
  ##      the hyperslab
  ## outputs:
  ##    seq[T] = 1D sequence of the hyperslab. To get reshaped data, use one of the
  ##      higher level read procs (NotYetImplemented...)
  ## throws:
  ##    HDF5LibraryError = if a call to the H5 library fails
  var err: herr_t
  if not typeMatches(dtype, dset.dtype):
    raise newException(ValueError,
                       "Wrong datatype as arg to `read_hyperslab`. Given " &
                       "`$#`, dset is `$#`" % [$dtype, $dset.dtype])

  let (memspace_id,
       hyperslab_id,
       n_elements) = dset.hyperslab(offset,
                                    count,
                                    stride,
                                    blk,
                                    full_output)
  var mdata = newSeq[dtype](n_elements)
  err = H5Dread(dset.dataset_id,
                dset.dtype_c,
                memspace_id,
                hyperslab_id,
                H5P_DEFAULT,
                addr(mdata[0]))
  result = mdata
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Dread` in `read_hyperslab`")

proc read_hyperslab_vlen*[T](dset: H5DataSet, dtype: typedesc[T],
                             offset, count: seq[int], stride, blk: seq[int] = @[],
                             full_output = false): seq[seq[T]] =
  ## proc to read an arbitrary hyperslab from a variable length dataset.
  ## See `read_hyperslab` for documentation
  var err: herr_t
  if not typeMatches(dtype, dset.dtypeBaseKind.anyTypeToString):
    raise newException(ValueError,
                       "Wrong datatype as arg to `read_hyperslab`. Given " &
                       "`$#`, dset is `$#`" % [$dtype, $dset.dtype])

  let (memspace_id,
       hyperslab_id,
       n_elements) = dset.hyperslab(offset,
                                    count,
                                    stride,
                                    blk,
                                    full_output)

  doAssert dset.dtype_class == H5T_VLEN
  var mdata = newSeq[hvl_t](n_elements)
  err = H5Dread(dset.dataset_id,
                dset.dtype_c,
                memspace_id,
                hyperslab_id,
                H5P_DEFAULT,
                addr(mdata[0]))
  result = vlenToSeq[T](mdata)

  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Dread` in `read_hyperslab`")

func isChunked*(dset: H5DataSet): bool =
  ## returns `true` if the dataset is using chunked storage
  result = H5Pget_layout(dset.dcpl_id) == H5D_CHUNKED

proc resize*[T: tuple | seq](dset: H5DataSet, shape: T) =
  ## proc to resize the dataset to the new size given by `shape`
  ## inputs:
  ##     dset: var H5DataSet = dataset to be resized
  ##     shape: T = tuple or seq describing the new size of the dataset
  ## Keep in mind:
  ##   - resizing only possible for datasets using chunked storage
  ##     (created with chunksize / maxshape != @[])
  ##   - resizing to smaller size than current size drops data
  ## throws:
  ##   HDF5LibraryError: if a call to the HDF5 library fails
  ##   ImmutableDatasetError: if the given dataset is contiguous memory instead
  ##     of chunked storage, i.e. cannot be resized
  # check if dataset is chunked storage
  if dset.isChunked:
    when T is tuple:
      var newshape = mapIt(parseShapeTuple(shape), hsize_t(it))
    elif T is seq:
      var newshape = shape.mapIt(hsize_t(it))
    # before we resize the dataspace, we get a copy of the
    # dataspace, since this internally refreshes the dataset. Important
    # since the dataset might be opened for reading when this
    # proc is called. We discard the dataspace_id, since we don't need it
    # (dataspace_id is a proc!)
    discard dset.dataspace_id
    let status = H5Dset_extent(dset.dataset_id, addr(newshape[0]))
    # set the shape we just resized to as the current shape
    withDebug:
      echo "Extending the dataspace to ", newshape
    dset.shape = mapIt(newshape, int(it))
    # after all is said and done, refresh again
    discard H5Dget_space(dset.dataset_id)
    if status < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed in " &
                         "`resize` calling `H5Dset_extent`")
  else:
    raise newException(ImmutableDatasetError, "Cannot resize a non-chunked " &
                       " (i.e. contiguous) dataset!")

proc add*[T](dset: H5DataSet, data: T, axis = 0, rewriteAsChunked = false) =
  ## Adds the `data` to the `dset` thereby resizing the dataset to fit
  ## the additional data. For this `data` must be compatible with the
  ## existing dataset.
  ## The data is added along `axis`.
  ## If the rewriteAsChunked flag is set to true, the existing dataset
  ## will be read to memory, removed from file, recreated as chunked and
  ## written back to file.
  if dset.isChunked:
    # simply resize and write the hyperslab
    let oldShape = dset.shape
    var newShape = oldShape
    newShape[axis] = oldShape[axis] + data.shape[axis]
    # before resizing, check that newShape <= maxShape
    if zip(newShape, dset.maxShape).anyIt(it[0].int > it[1].int):
      raise newException(ImmutableDatasetError, "The new required shape to " &
        "add data along axis " & $axis & " exceeds the maximum allowed shape!" &
        "\nnewShape: " & $newShape & "\nmaxShape: " & $dset.maxShape)
    dset.resize(newShape)
    var offset = newSeq[int](oldShape.len)
    offset[axis] = oldShape[axis]
    var count = oldShape
    count[axis] = data.shape[axis]
    dset.write_hyperslab(data,
                         offset = offset,
                         count = count)
  elif rewriteAsChunked:
    raise newException(NotImplementedError, "Rewriting as chunked storage " &
      "not yet implemented.")
  else:
    raise newException(ImmutableDatasetError, "Cannot add data to a non-chunked " &
      "dataset, unless the `rewriteAsChunked` option is set to true!")

proc high*(dset: H5DataSet, axis = 0): int =
  ## convenience proc to return the highest possible index of
  ## the dataset along a given axis (in a given dimension)
  ## inputs:
  ##   dset: var H5DataSet = dataset for which to return index
  ##   axis: int = axis for which to return highest index. By default
  ##     first axis is used. Mostly useful for 1D datasets
  ## outputs:
  ##   int = highest index along `axis`
  result = dset.shape[axis] - 1

proc isVlen*(dset: H5Dataset): bool =
  ## Returns true if the dataset is a variable length dataset
  result = dset.dtype_class == H5T_VLEN
