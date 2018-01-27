#[
This file contains all procedures related to datasets.

The H5DataSet type is defined in the datatypes.nim file.
]#

import typeinfo
import typetraits
import options
import tables
import strutils
import sequtils

import arraymancer

import hdf5_wrapper
import H5nimtypes
import datatypes
import dataspaces
import attributes
import util
import h5util

from groups import create_group


proc newH5DataSet*(name: string = ""): ref H5DataSet =
  ## default constructor for a H5File object, for internal use
  let shape: seq[int] = @[]
  let attrs = newH5Attributes()
  result = new H5DataSet
  result.name = name
  result.shape = shape
  result.dtype = nil
  result.dtype_c = -1
  result.parent = ""
  result.file = ""
  result.dataspace_id = -1
  result.dataset_id = -1
  result.all = RW_ALL
  result.attrs = attrs
    
proc getDset(h5f: H5FileObj, dset_name: string): Option[H5DataSet] =
  # convenience proc to return the dataset with name dset_name
  # if it does not exist, KeyError is thrown
  # inputs:
  #    h5f: H5FileObj = the file object from which to get the dset
  #    obj_name: string = name of the dset to get
  # outputs:
  #    H5DataSet = if dataset is found
  # throws:
  #    KeyError: if dataset could not be found
  let dset_exist = hasKey(h5f.datasets, dset_name)
  if dset_exist == false:
    #raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
    result = none(H5DataSet)
  else:
    result = some(h5f.datasets[dset_name][])

  
template readDsetShape(dspace_id: hid_t): seq[int] =
  # get the shape of the dataset
  var result: seq[int] = @[]
  let ndims = H5Sget_simple_extent_ndims(dspace_id)
  # given ndims, create a seq in which to store the dimensions of
  # the dataset
  var shapes = newSeq[hsize_t](ndims)
  var max_sizes = newSeq[hsize_t](ndims)
  let s = H5Sget_simple_extent_dims(dspace_id, addr(shapes[0]), addr(max_sizes[0]))
  withDebug:
    echo "dimensions seem to be ", shapes
  result = mapIt(shapes, int(it))
  result
    
template get(h5f: var H5FileObj, dset_in: dset_str): H5DataSet =
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
  
  let dset_name = string(dset_in)
  let dset_exist = hasKey(h5f.datasets, dset_name)
  var result = newH5DataSet(dset_name)[]
  if dset_exist == false:
    # before we raise an exception, because the dataset does not yet exist,
    # check whether such a dataset exists in the file we're not aware of yet
    withDebug:
      echo "file id is ", h5f.file_id
      echo "name is ", result.name
    let exists = existsInFile(h5f.file_id, result.name)
    if exists > 0:
      result.dataset_id   = H5Dopen2(h5f.file_id, result.name, H5P_DEFAULT)
      result.dataspace_id = H5Dget_space(result.dataset_id)
      # does exist, add to H5FileObj
      let datatype_id = H5Dget_type(result.dataset_id)
      let f = h5ToNimType(datatype_id)
      if f == akSequence:
        # akSequence == VLEN type
        # in this case this only determines dtypeAnyKind, but we don't
        # know the basetype. Set that by another call of the super of
        # the datatype
        result.dtypeBaseKind = h5ToNimType(H5Tget_super(datatype_id))
        result.dtype = "vlen"
      else:
        result.dtype = strip($f, chars = {'a', 'k'}).toLowerAscii
      result.dtypeAnyKind = f
      result.dtype_c = H5Tget_native_type(datatype_id, H5T_DIR_ASCEND)
      result.dtype_class = H5Tget_class(datatype_id)

      # get the dataset access property list 
      result.dapl_id = H5Dget_access_plist(result.dataset_id)
      # get the dataset create property list
      result.dapl_id = H5Dget_create_plist(result.dataset_id)
      withDebug:
        echo "ACCESS PROPERTY LIST IS ", result.dapl_id
        echo "CREATE PROPERTY LIST IS ", result.dapl_id      
        echo H5Tget_class(datatype_id)

        
      result.shape = readDsetShape(result.dataspace_id)
      # still need to determine the parents of the dataset
      result.parent = getParent(result.name)      
      var parent = create_group(h5f, result.parent)
      result.parent_id = getH5Id(parent)
      result.file = h5f.name

      # create attributes field
      result.attrs = initH5Attributes(result.name, result.dataset_id, "H5DataSet")

      # need to close the datatype again, otherwise cause resource leak
      status = H5Tclose(datatype_id)
      if status < 0:
        #TODO: replace by exception
        echo "Status of H5Tclose() returned non-negative value. H5 will probably complain now..."


      # now that we have created the group fully (including IDs), we can add it to the file and
      # the parent
      var dset_ref = new H5DataSet
      dset_ref[] = result
      parent.datasets[result.name] = dset_ref
      h5f.datasets[result.name] = dset_ref
    else:
      raise newException(KeyError, "Dataset with name: " & dset_name & " not found in file " & h5f.name)
  else:
    result = h5f.datasets[dset_name][]
    # in this case we still need to update e.g. shape
    # TODO: think about what else we might have to update!
    result.dataspace_id = H5Dget_space(result.dataset_id)
    result.shape = readDsetShape(result.dataspace_id)
    # TODO: also read maxshape and chunksize if any
  result


template isDataSet(h5_object: typed): bool =
  # procedure to check whether object is a H5DataSet
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
  # NOTE: previously we returned a seq[hsize_t], but we now perform the
  # conversion from int to hsize_t in simple_dataspace() (which is the
  # only place we use the result of this proc!)
  # TODO: move the when T is int: branch from create_dataset to here
  # to clean up create_dataset!
  
  var n_dims: int
  # count the number of fields in the array, since that is number
  # of dimensions we have
  for field in dims.fields:
    inc n_dims

  result = newSeq[int](n_dims)
  # now set the elements of result to the values in the tuple
  var count: int = 0
  for el in dims.fields:
    # now set the value of each dimension
    # enter the shape in reverse order, since H5 expects data in other notation
    # as we do in Nim
    #result[^(count + 1)] = hsize_t(el)
    result[count] = int(el)
    inc count

  
proc parseChunkSizeAndMaxShape(dset: var H5DataSet, chunksize, maxshape: seq[int]): hid_t =
  ## proc to parse the chunk size and maxhshape arguments handed to the create_dataset()
  ## Takes into account the different possible scenarios:
  ##    chunksize: seq[int] = a sequence containing the chunksize, the dataset should be
  ##            should be chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.
  dset.maxshape = maxshape
  dset.chunksize = chunksize
  if maxshape.len > 0:
    # user wishes to create unlimited sized or limited sized + resizable dataset
    # need to create chunked storage.
    if chunksize.len == 0:
      # no chunksize, but maxshape -> chunksize = shape
      dset.chunksize = dset.shape
    else:
      # chunksize given, use it
      dset.chunksize = chunksize
    result = set_chunk(dset.dcpl_id, dset.chunksize)
    if result < 0:
      raise newException(HDF5LibraryError, "HDF5 library returned error on call to `H5Pset_chunk`")
  #elif maxshape.len == 0:
  else:
    if chunksize.len > 0:
      # chunksize given -> maxshape = shape
      dset.maxshape = dset.shape
      result = set_chunk(dset.dcpl_id, dset.chunksize)
      if result < 0:
        raise newException(HDF5LibraryError, "HDF5 library returned error on call to `H5Pset_chunk`")
    else:
      result = 0

proc create_dataset_in_file(h5file_id: hid_t, dset: H5DataSet): hid_t =
  ## proc to create a given dataset in the H5 file described by `h5file_id`
  if dset.maxshape.len == 0 and dset.chunksize.len == 0:
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dset.dataspace_id,
                         H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
  else:
    # in this case we are definitely working with chunked memory of some
    # sorts, which means that the dataset creation property list is set
    result  = H5Dcreate2(h5file_id, dset.name, dset.dtype_c, dset.dataspace_id,
                         H5P_DEFAULT, dset.dcpl_id, H5P_DEFAULT)

proc create_dataset*[T: (tuple | int)](h5f: var H5FileObj,
                                         dset_raw: string,
                                         shape_raw: T,
                                         dtype: (typedesc | hid_t),
                                         chunksize: seq[int] = @[],
                                         maxshape: seq[int] = @[]): H5DataSet = 
  ## procedure to create a dataset given a H5file object. The shape of
  ## that type is given as a tuple, the datatype as a typedescription
  ## inputs:
  ##    h5file: H5FileObj = the H5FileObj received by H5file() into which the data
  ##                   set belongs
  ##    shape: T = the shape of the dataset, given as a tuple
  ##    dtype = typedesc = a Nim typedesc (e.g. int, float, etc.) for that
  ##            dataset. vlen not yet supported
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
  var status: hid_t = 0
  when T is int:
    # in case we hand an int as the shape argument, it means we wish to write
    # 1 column data to the file. In this case define the shape from here on
    # as a (shape, 1) tuple instead. 
    var shape = (shape_raw, 1)
  else:
    var shape = shape_raw

  # TODO: before call to create_simple and create2, we need to check whether
  # any such dataset already exists. Could include that in the opening procedure
  # by getting all groups etc in the file (by id, not reading the data)

  # remove any trailing / and insert potential missing root /
  var dset_name = formatName(dset_raw)

  # first get the appropriate datatype for the given Nim type
  when dtype is hid_t:
    let dtype_c = dtype
  else:
    let dtype_c = nimToH5type(dtype)

  # need to deal with the shape of the dataset to be created
  #let shape_ar = parseShapeTuple(shape)
  var shape_seq = parseShapeTuple(shape)

  # set up the dataset object
  var dset = newH5DataSet(dset_name)[]
  when dtype is hid_t:
    # for now we only support vlen arrays, later we need to
    # differentiate between the different H5T class types
    dset.dtype = "vlen"
  else:
    dset.dtype   = name(dtype)
  dset.dtype_c = dtype_c
  dset.dtype_class = H5Tget_class(dtype_c)
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


  # create the dataset access property list
  dset.dapl_id = H5Pcreate(H5P_DATASET_ACCESS)
  # create the dataset create property list
  dset.dcpl_id = H5Pcreate(H5P_DATASET_CREATE)

  # in case we wish to use chunked storage (either resizable or unlimited size)
  # we need to set the chunksize on the dataset create property list
  try:
    status = dset.parseChunkSizeAndMaxShape(chunksize, maxshape)
    if status >= 0:
      # check whether there already exists a dataset with the given name
      # first in H5FileObj:
      var exists = hasKey(h5f.datasets, dset_name)
      if exists == false:
        # then check the actual file for a dataset with the given name
        # TODO: FOR NOW the location id given to H5Dopen2 is only the file id
        # once we have the parent properly determined, we can also check for
        # the parent (group) id!
        withDebug:
          echo "Checking if dataset exists via H5Lexists ", dset.name
        let in_file = existsInFile(h5f.file_id, dset.name)
        if in_file > 0:
          # in this case successful, dataset exists already
          exists = true
          # in this case open the dataset to read
          dset.dataset_id   = H5Dopen2(h5f.file_id, dset.name, H5P_DEFAULT)
          dset.dataspace_id = H5Dget_space(dset.dataset_id)
          # TODO: include a check about whether the opened dataset actually conforms
          # to what we wanted to create (e.g. same shape etc.)
          
        elif in_file == 0:
          # does not exist
          # now
          withDebug:
            echo "Does not exist, so create dataspace ", dset.name, " with shape ", shape_seq
          dset.dataspace_id = simple_dataspace(shape_seq, maxshape)
          
          # using H5Dcreate2, try to create the dataset
          withDebug:
            echo "Does not exist, so create dataset via H5create2 ", dset.name
          dset.dataset_id = create_dataset_in_file(h5f.file_id, dset)
        else:
          raise newException(HDF5LibraryError, "Call to HDF5 library failed in `existsInFile` from `create_dataset`")
      else:
        # else the dataset is already known and in the table, get it
        dset = h5f[dset.name.dset_str]
    else:
      raise newException(UnkownError, "Unkown error occured due to call to `parseChunkSizeAndMaxhShape` returning with status = $#" % $status)
  except HDF5LibraryError:
    #let msg = getCurrentExceptionMsg()
    echo "Call to HDF5 library failed in `parseChunkSizeAndMaxShape` from `create_dataset`"
    raise

  # now create attributes field
  dset.attrs = initH5Attributes(dset.name, dset.dataset_id, "H5DataSet")
  var dset_ref = new H5DataSet
  dset_ref[] = dset
  h5f.datasets[dset_name] = dset_ref
  # redundant:
  h5f.dataspaces[dset_name] = dset.dataspace_id

  result = dset

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




      
proc `[]=`*[T](dset: var H5DataSet, ind: DsetReadWrite, data: seq[T]) = #openArray[T])  
  # procedure to write a sequence of array to a dataset
  # will be given to HDF5 library upon call, H5DataSet object
  # does not store the data
  # inputs:
  #    dset: var H5DataSet = the dataset which contains the necessary information
  #         about dataset shape, dtype etc. to write to
  #    ind: DsetReadWrite = indicator telling us to write whole dataset,
  #         used to differentiate from the case in which we only write a hyperslab    
  #    data: openArray[T] = any array type containing the data to be written
  #         needs to be of the same size as the shape given during creation of
  #         the dataset or smaller
  # throws:
  #    ValueError: if the shape of the input dataset is different from the reserved
  #         size of the dataspace on which we wish to write in the H5 file
  #         TODO: create an appropriate Exception for this case!

  # TODO: IMPORTANT: think about whether we should be using array types instead
  # of a dataspace of certain dimensions for arrays / nested seqs we're handed

  var err: herr_t
  
  if ind == RW_ALL:
    let shape = dset.shape
    withDebug:
      echo "shape is ", shape, " of dset ", dset.name
      echo "shape is a ", type(shape).name, " and data is a ", type(data).name, " and data.shape = ", data.shape
    # check whether we will write a 1 column dataset. If so, relax
    # requirements of shape check. In this case only compare 1st element of
    # shapes. We compare shape[1] with 1, because atm we demand VLEN data to be
    # a 2D array with one column. While in principle it's a N element vector
    # it is always promoted to a (N, 1) array.
    if (shape.len == 2 and shape[1] == 1 and shape(data)[0] == dset.shape[0]) or
      data.shape == dset.shape:
      
      if dset.dtype_class == H5T_VLEN:
        # TODO: should we also check whether data really is 1D? or let user deal with that?
        # will flatten the array anyways, so in case on tries to write a 2D array as vlen,
        # the flattened array will end up as vlen in the file
        # in this case we need to prepare the data further by assigning the data to
        # a hvl_t struct
        when T is seq:
          var mdata = data
          # var data_hvl = newSeq[hvl_t](mdata.len)
          # var i = 0
          # for d in mitems(mdata):
          #   data_hvl[i].`len` = d.len
          #   data_hvl[i].p = addr(d[0])#cast[pointer]()
          #   inc i
          var data_hvl = mdata.toH5vlen
          err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                         addr(data_hvl[0]))
          if err < 0:
            withDebug:
              echo "Trying to write data_hvl ", data_hvl
            raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[All]=`")
        else:
          echo "VLEN datatype does not make sense, if the data is of type seq[$#]" % T.name
          echo "Use normal datatype instead. Or did you only hand a single element"
          echo "of your vlen data?"
      else:
        var data_write = flatten(data) 
        err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                       addr(data_write[0]))
        if err < 0:
          withDebug:
            echo "Trying to write data_write ", data_write
          raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[All]=`")
    else:
      var msg = """
Wrong input shape of data to write in `[]=` while accessing `$#`. Given shape `$#`, dataset has shape `$#`"""
      msg = msg % [$dset.name, $data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    echo "Dataset not assigned anything, ind: DsetReadWrite invalid"

proc `[]=`*[T](dset: var H5DataSet, ind: DsetReadWrite, data: AnyTensor[T]) =
  # equivalent of above fn, to support arraymancer tensors as input data
  if ind == RW_ALL:
    let tensor_shape = data.squeeze.shape
    # first check whether number of dimensions is the same
    let dims_fit = if tensor_shape.len == dset.shape.len: true else: false
    if dims_fit == true:
      # check whether each dimension is the same size
      let shape_good = foldl(mapIt(toSeq(0..dset.shape.high), tensor_shape[it] == dset.shape[it]), a == b, true)
      var data_write = data.squeeze.toRawSeq
      let err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                         addr(data_write[0]))
      if err < 0:
        withDebug:
          echo "Trying to write tensor ", data_write
        raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[Tensor]=`")
    else:
      var msg = """
Wrong input shape of data to write in `[]=`. Given shape `$#`, dataspace has shape `$#`"""
      msg = msg % [$data.shape, $dset.shape]
      raise newException(ValueError, msg)
  else:
    # TODO: replace by exception
    echo "Dataset not assigned anything, ind: DsetReadWrite invalid"

proc `[]=`*[T](dset: var H5DataSet, inds: HSlice[int, int], data: var seq[T]) = #openArray[T])  
  # procedure to write a sequence of array to a dataset
  # will be given to HDF5 library upon call, H5DataSet object
  # does not store the data
  # inputs:
  #    dset: var H5DataSet = the dataset which contains the necessary information
  #         about dataset shape, dtype etc. to write to
  #    inds: HSlice[int, int] = slice of a range, which to write in dataset
  #    data: openArray[T] = any array type containing the data to be written
  #         needs to be of the same size as the shape given during creation of
  #         the dataset or smaller

  # only write slice of dset by using hyperslabs

  # TODO: change this function to do what it's supposed to!
  if dset.shape == data.shape:
    #var ten = data.toTensor()
    # in this case run over all dimensions and flatten arrayA
    withDebug:
      echo "shape before is ", data.shape
      echo data
    var data_write = flatten(data) 
    let err = H5Dwrite(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                       addr(data_write[0]))
    if err < 0:
      withDebug:
        echo "Trying to write data_write from slice ", data_write
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `[Slice]=`")
  else:
    # TODO: replace by exception
    echo "All bad , shapes are ", data.shape, " ", dset.shape


template withDset*(h5dset: H5DataSet, actions: untyped) =
  ## convenience template to read a dataset from the file and perform actions
  ## with that dataset, without having to manually check the data type of the
  ## dataset
  case h5dset.dtypeAnyKind
  of akBool:
    let dset {.inject.} = h5dset[bool]
    actions
  of akChar:
    let dset {.inject.} = h5dset[char]
    actions
  of akString:
    let dset {.inject.} = h5dset[string]
    actions
  of akFloat32:
    let dset {.inject.} = h5dset[float32]
    actions
  of akFloat64:
    let dset {.inject.} = h5dset[float64]
    actions
  of akInt8:
    let dset {.inject.} = h5dset[int8]
    actions
  of akInt16:
    let dset {.inject.} = h5dset[int16]
    actions
  of akInt32:
    let dset {.inject.} = h5dset[int32]
    actions
  of akInt64:
    let dset {.inject.} = h5dset[int64]
    actions
  of akUint8:
    let dset {.inject.} = h5dset[uint8]
    actions
  of akUint16:
    let dset {.inject.} = h5dset[uint16]
    actions
  of akUint32:
    let dset {.inject.} = h5dset[uint32]
    actions
  of akUint64:
    let dset {.inject.} = h5dset[uint64]
    actions    
  else:
    echo "it's of type ", h5dset.dtypeAnyKind
    discard

proc select_elements[T](dset: var H5DataSet, coord: seq[T]) {.inline.} =
  ## convenience proc to select specific coordinates in the dataspace of
  ## the given dataset
  # first flatten coord tuples
  var flat_coord = mapIt(coord.flatten, hsize_t(it))
  discard H5Sselect_elements(dset.dataspace_id, H5S_SELECT_SET, csize(coord.len), addr(flat_coord[0]))

proc read*[T: seq, U](dset: var H5DataSet, coord: seq[T], buf: var seq[U]) =
  # proc to read specific coordinates (or single values) from a dataset
  
  # select the coordinates in the dataset
  dset.select_elements(coord)
  let memspace_id = create_simple_memspace_1d(coord)
  # now read the elements
  if buf.len == coord.len:
    discard H5Dread(dset.dataset_id, dset.dtype_c, memspace_id, dset.dataspace_id, H5P_DEFAULT,
                    addr(buf[0]))
    
  else:
    echo "Provided buffer is not of same length as number of points to read"
  # close memspace again
  discard H5Sclose(memspace_id)

proc read*[T](dset: var H5DataSet, buf: var seq[T]) =
  # read whole dataset
  if buf.len == foldl(dset.shape, a * b, 1):
    discard H5Dread(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    addr(buf[0]))
    # now write data back into the buffer
    # for ind in 0..data.high:
    #   let inds = getIndexSeq(ind, shape)
    #   buf.set_element(inds, data[ind])
  else:
    var msg = """
Wrong input shape of buffer to write to in `read`. Buffer shape `$#`, dataset has shape `$#`"""
    msg = msg % [$buf.shape, $dset.shape]
    raise newException(ValueError, msg)


proc `[]`*[T](dset: var H5DataSet, t: typedesc[T]): seq[T] =
  ## procedure to read the data of an existing dataset into 
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    ind: DsetReadWrite = indicator telling us to read whole dataset,
  ##         used to differentiate from the case in which we only read a hyperslab
  ## outputs:
  ##    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset
  ##         TODO: return the correct data shape!
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  # TODO: think about this check. Currently e.g. float != float64, although the two
  # are the same internally, or keep it as it is to make sure to be precise, given
  # that on other machine this will be different?
  # let basetype = h5ToNimType(t)
  # if basetype != dset.dtypeAnyKind:

  if $t != dset.dtype:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given `$#`, dset is `$#`" % [$t, $dset.dtype]) 

  let
    shape = dset.shape
    n_elements = foldl(shape, a * b)
  # create a flat sequence of the size of the dataset in the H5 file, then read data
  # cannot use the result sequence, since we need to hand the address of the sequence to
  # the H5 library
  var data = newSeq[T](n_elements)    
  dset.read(data)
  
  result = data

proc `[]`*[T](dset: var H5DataSet, t: hid_t, dtype: typedesc[T]): seq[seq[T]] =
  ## TODO: combine this proc with the one above, by getting the data type
  ## in this proc, checking for VLEN and if so, use dtype to create the special
  ## type. Do it similarly to write_norm and write_vlen, split into two
  
  ## procedure to read the data of an existing dataset based on variable length data
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    ind: DsetReadWrite = indicator telling us to read whole dataset,
  ##         used to differentiate from the case in which we only read a hyperslab
  ## outputs:
  ##    seq[dtype]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset
  ##         TODO: return the correct data shape!
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  var err: herr_t
  # check whether t is variable length
  let basetype = h5ToNimType(t)
  if basetype != dset.dtypeAnyKind:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given `$#`, dset is `$#`" % [$t, $dset.dtype])
  let
    shape = dset.shape
    n_elements = foldl(shape, a * b)
  # create a flat sequence of the size of the dataset in the H5 file, then read data
  # cannot use the result sequence, since we need to hand the address of the sequence to
  # the H5 library
  var data = newSeq[hvl_t](n_elements)
  err = H5Dread(dset.dataset_id, dset.dtype_c, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                    addr(data[0]))
  echo "H5Dread : ", err

  # converting the raw data from the C library to a Nim sequence is sort of ugly, but
  # here it goes...
  # number of elements we read
  result = newSeq[seq[dtype]](n_elements)
  # iterate over every element of the pointer we have with data
  for i in 0 ..< n_elements:
    let elem_len = data[i].len
    # create corresponding sequence for the size of this element
    result[i] = newSeq[dtype](elem_len)
    # now we need to cast the data, which is a pointer, to a ptr of an unchecked
    # array of our datatype
    let data_seq = cast[ptr UncheckedArray[dtype]](data[i].p)
    # now assign each element of the unckecked array to our sequence
    for j in 0 ..< elem_len:
      result[i][j] = data_seq[j]
  # since we have in effect copied the whole array, we can now safely let the H5 library
  # reclaim the memory, which it alloc'd 
  let dspace_id = H5Dget_space(dset.dataset_id)
  err = H5Dvlen_reclaim(dset.dtype_c, dspace_id, H5P_DEFAULT, addr(data[0]))
  echo "H5Dvlen_reclaim : ", err

proc write_vlen*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  # check whehter we have data for each coordinate
  var err: herr_t
  when U isnot seq:
    var mdata = @[data]
  else:
    var mdata = data
  let valid_data = if coord.len == mdata.len: true else: false
  if valid_data == true:
    let memspace_id = create_simple_memspace_1d(coord)
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
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_vlen`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_vlen`")
    
  else:
    var msg = """
Invalid coordinates or corresponding data to write in `write_vlen`. Coord shape `$#`, data shape `$#`"""
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

proc write_norm*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  ## write procedure for normal (read non-vlen) data based on a set of coordinates 'coord'
  ## to write 'data' to. Need to have one element in data for each coord and
  ## data needs to be of shape corresponding to coord
  # mutable copy
  var err: herr_t
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
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_norm`")
    err = H5Sclose(memspace_id)
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_norm`")    
  else:
    var msg = """
Invalid coordinates or corresponding data to write in `write_norm`. Coord shape `$#`, data shape `$#`"""
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

  
template write*[T: seq, U](dset: var H5DataSet, coord: seq[T], data: seq[U]) =
  # template around both write fns for normal and vlen data
  if dset.dtype_class == H5T_VLEN:
    dset.write_vlen(coord, data)
  else:
    dset.write_norm(coord, data)

template write*[T: (SomeNumber | bool | char | string), U](dset: var H5DataSet,
                                                           coord: seq[T],
                                                           data: seq[U]) =
  # template around both write fns for normal and vlen data in case the coordinates are given as
  # a seq of numbers (i.e. for 1D datasets!)
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

template write*[T: (seq | SomeNumber | bool | char | string)](dset: var H5DataSet,
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
        let msg = """
Cannot broadcast ind to dataset in `write`, because data does not fit into array row / column wise. 
    data.len = $#
    dset.shape = $#""" % [$data.len, $dset.shape]
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
  
template `[]`*(h5f: H5FileObj, name: dset_str): H5DataSet =
  # a simple wrapper around get for datasets
  h5f.get(name)
    
proc resize*[T: tuple](dset: var H5DataSet, shape: T) =
  ## proc to resize the dataset to the new size given by `shape`
  ## inputs:
  ##     dset: var H5DataSet = dataset to be resized
  ##     shape: T = tuple describing the new size of the dataset
  ## Keep in mind:
  ##   - resizing only possible for datasets using chunked storage
  ##     (created with chunksize / maxshape != @[])
  ##   - resizing to smaller size than current size drops data
  ## throws:
  ##   HDF5LibraryError: if a call to the HDF5 library fails
  ##   ImmutableDatasetError: if the given dataset is contiguous memory instead
  ##     of chunked storage, i.e. cannot be resized

  # check if dataset is chunked storage
  if H5Pget_layout(dset.dcpl_id) == H5D_CHUNKED:
    var newshape = mapIt(parseShapeTuple(shape), hsize_t(it))
    # before we resize the dataspace, we get a copy of the
    # dataspace, since this internally refreshes the dataset. Important
    # since the dataset might be opened for reading when this
    # proc is called
    dset.dataspace_id = H5Dget_space(dset.dataset_id)
    let status = H5Dset_extent(dset.dataset_id, addr(newshape[0]))
    # set the shape we just resized to as the current shape
    withDebug:
      echo "Extending the dataspace to ", newshape
    dset.shape = mapIt(newshape, int(it))
    # after all is said and done, refresh again
    dset.dataspace_id = H5Dget_space(dset.dataset_id)
    if status < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed in `resize` calling `H5Dset_extent`")
  else:
    raise newException(ImmutableDatasetError, "Cannot resize a non-chunked (i.e. contiguous) dataset!")

proc select_hyperslab(dset: var H5DataSet, offset, count: seq[int], stride, blk: seq[int] = @[]) =
  # given the dataspace of `dset`, select a hyperslab of it using `offset`, `stride`, `count` and `blk`
  # for which all needs to hold:
  # dset.shape.len == offset.shape.len, i.e. they need to be of the same rank as dset is
  # we currently set the hyperslab selection such that previous selections are overwritten (2nd argument)
  var
    err: herr_t
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

  withDebug:
    echo "Selecting the following hyperslab"
    echo "offset: ", moffset
    echo "count:  ", mcount
    echo "stride: ", mstride
    echo "block:  ", mblk
    
  # just in case get the most current dataspace
  dset.dataspace_id = H5Dget_space(dset.dataset_id)
  # and perform the selection on this dataspace
  err = H5Sselect_hyperslab(dset.dataspace_id,
                            H5S_SELECT_SET,
                            addr(moffset[0]),
                            addr(mstride[0]),
                            addr(mcount[0]),
                            addr(mblk[0]))
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sselect_hyperslab` in `select_hyperslab`")

proc write_hyperslab*[T](dset: var H5DataSet, data: seq[T], offset, count: seq[int], stride, blk: seq[int] = @[]) =
  # proc to select a hyperslab and write to it
  var err: herr_t

  # flatten the data array to be written
  var mdata = data.flatten

  dset.dataspace_id = H5Dget_space(dset.dataset_id)
  let memspace_id = simple_dataspace(data.shape)
  dset.select_hyperslab(offset, count, stride, blk)

  err = H5Dwrite(dset.dataset_id, dset.dtype_c, memspace_id, dset.dataspace_id, H5P_DEFAULT, addr(mdata[0]))
  if err < 0:
    withDebug:
      echo "Trying to write mdata with shape ", mdata.shape
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite` in `write_hyperslab`")
  err = H5Sclose(memspace_id)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Sclose` in `write_vlen`")