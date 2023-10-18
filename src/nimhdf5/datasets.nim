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

# stdlib
import std / [options, tables, strutils, sequtils, macros]
tryExport:
  export nimIdentNormalize

# external nimble
import pkg / seqmath

# internal
import hdf5_wrapper, H5nimtypes, datatypes, dataspaces,
       attributes, filters, util, h5util
from type_utils import needsCopy
from groups import create_group

import ./copyflat
export copyflat

proc select_elements[T](dset: H5DataSet, coord: seq[T]): DataspaceID {.inline, discardable.}

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

proc readH5*[T: ptr | pointer](dset: H5DataSet, buf: T,
                memspaceId = H5S_ALL,
                hyperslabId = H5S_ALL) =
  ## read whole dataset into buffer `ptr T`. Unsafe and the caller needs to make sure
  ## the buffer can hold the data and possibly check the types!
  let err = H5Dread(dset.dataset_id.id, dset.dtype_c.id, memspaceId, hyperslabId, H5P_DEFAULT,
                    buf)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dread` in full `read`")

proc readImpl[T](dset: H5Dataset, buffer: var seq[T],
                 memspaceId = H5S_ALL,
                 hyperslabId = H5S_ALL,
                ) =
  template readData(buf: untyped): untyped {.dirty.} =
    when typeof(buf) is Buffer:
      readH5(dset,
             buf.data,
             memspaceId,
             hyperslabId)
    else:
      readH5(dset,
             addr(buf[0]),
             memspaceId,
             hyperslabId)

  template reclaim(buf: untyped): untyped =
    ## IMPORTANT: We must assign a `DatatypeID` instead of a raw `hid_t`, because `dataspaceID`
    ## is a `proc`. If we were to write `else: dset.dataspaceId.id` the returned value would
    ## be `=destroy`-ed before the `H5Dvlen_reclaim` call again!
    let dspaceId = if memspaceID.isValidID(): memspaceID.toDataspaceID() else: dset.dataspaceId
    let err = H5Dvlen_reclaim(dset.dtype_c.id, dspaceId.id, H5P_DEFAULT, buf.data)
    if err != 0:
      raise newException(HDF5LibraryError, "HDF5 library failed to reclaim variable length memory.")
  when T.needsCopy:
    # allocate a `Buffer` for HDF5 data
    let actBuf = newBuffer(buffer.len * calcSize(T))
    readData(actBuf)
    # convert back to Nim types
    buffer = fromFlat[T](actBuf)
    reclaim(actBuf)
  else:
    if dset.isVlen: # vlen == hvl_t -> use buffer
      let actBuf = newBuffer(buffer.len * calcSize(T))
      readData(actBuf)
      # convert back to Nim types
      buffer = fromFlat[T](actBuf)
      reclaim(actBuf)
    else:
      readData(buffer)

proc read*[T](h5f: H5File, dset: string, buf: ptr T) =
  let dset = h5f[dset.dset_str]
  dset.readH5(buf)

proc read*(dset: H5DataSet, buf: ptr | pointer) =
  dset.readH5(buf)

proc read*[T](dset: H5DataSet, buf: var seq[T], ignoreShapeCheck = false) =
  if ignoreShapeCheck or buf.len == foldl(dset.shape, a * b, 1):
    if buf.len > 0: # dataset can be empty
      dset.readImpl(buf)
  else:
    var msg = "Wrong input shape of buffer to write to in `read`. " &
      "Buffer shape `$#`, dataset has shape `$#`"
    msg = msg % [$buf.shape, $dset.shape]
    raise newException(ValueError, msg)

proc read*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T]): seq[seq[T]] =
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
  # check whether t is variable length
  let basetype = h5ToNimType(t)
  if basetype != dset.dtypeAnyKind:
    raise newException(ValueError, "Wrong datatype as arg to `[]`. Given " &
      "`$#`, dset is `$#`" % [$(t.id), $(dset.dtype)])

  let n_elements = dset.shape[0]
  result = newSeq[seq[T]](n_elements)
  readImpl(dset, result) # handles reclaim of VLEN

template readVlen*[T](dset: H5DataSet, dtype: typedesc[T]): seq[seq[T]] =
  ## Convenience template to avoid having to define the special type to read a
  ## variable length dataset.
  if not dset.isVlen:
    raise newException(IOError, "Given datatype " & dset.name & " is not a " &
      "variable length dataset!")
  when T is string:
    dset.read(special_type(char), dtype)
  else:
    dset.read(special_type(dtype), dtype)

proc read*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T], idx: int): seq[T] =
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
    raise newException(IndexDefect, "Coordinate shape mismatch. Index " &
      "is $#, dataset is dimension $#!" % [$idx, $dsetLen])
  result = dset.read_hyperslab_vlen(dtype, @[idx, 0], @[1, 1])[0]

proc read*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T], indices: seq[int]): seq[seq[T]] =
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
  ##   IndexDefect = raised if the shape of the a coordinate (check only first, be careful!)
  ##     does not match the shape of the dataset. Otherwise would cause H5 library error
  # select the coordinates in the dataset
  if coord[0].len != dset.shape.len:
    raise newException(IndexDefect, "Coordinate shape mismatch. Coordinate has " &
      "dimension $#, dataset is dimension $#!" % [$coord[0].len, $dset.shape.len])

  # select all elements from the coordinate seq
  let dspace = dset.select_elements(coord)
  let memspace_id = create_simple_memspace_1d(coord)

  # now read the elements
  if buf.len == coord.len:
    readImpl(dset, buf, memspaceId.id, dspace.id)
  else:
    echo "Provided buffer is not of same length as number of points to read"
  # close memspace again
  memspace_id.close()

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
  from std / strbasics import strip
else:
  from strutils import strip
  proc strip(s: var string, leading = true, trailing = true, chars: set[char] = Whitespace) =
    # for older nim versions we ignore arguments. only for same resolution
    var idx = 0
    while idx < s.len:
      if s[idx] in chars:
        break
      inc idx
    s.setLen(idx)

proc readFixedStringData(s: var seq[string], dset: H5Dataset) =
  # get size of stored strings
  doAssert not dset.dtype_c.isVariableString(), "String is variable! Read using `readVlenStringData`."
  let size = H5Tget_size(dset.dtype_c.id)
  var buf = newSeq[char](s.len * size.int) #char](n_elements * size.int)
  # read into `buf` ignoring the check of the shape
  dset.read(buf, ignoreShapeCheck = true)
  for i in 0 ..< s.len:
    s[i] = newString(size.int)
    copyMem(s[i][0].addr, buf[i * size.int].addr, size.int)
    s[i].strip(leading = false, chars = {'\0'})

proc readVlenStringData(s: var seq[string], dset: H5Dataset) =
  # get size of stored strings
  doAssert dset.dtype_c.isVariableString(), "String is variable! Read as `string`, not `cstring`."
  let size = H5Tget_size(dset.dtype_c.id)
  var buf = newSeq[cstring](s.len)
  # read into `buf` ignoring the check of the shape
  dset.read(buf, ignoreShapeCheck = true)
  for i in 0 ..< s.len:
    s[i] = newString(buf[i].len)
    copyMem(s[i][0].addr, buf[i][0].addr, buf[i].len)
  # let H5 reclaim memory
  if buf.len > 0: # if we didn't read anything, nothing to reclaim
    let err = H5Dvlen_reclaim(dset.dtype_c.id, dset.dataspace_id().id, H5P_DEFAULT, addr(buf[0]))
    if err < 0:
      raise newException(HDF5LibraryError, "Failed to let HDF5 library reclaim variable length string " &
        "buffer.")

proc readStringData(s: var seq[string], dset: H5DataSet) =
  ## Reads data from a string dataset. Takes care of dispatching to the correct procedure
  ## depending on fixed lenth strings (flat data) or variable length strings.
  if dset.dtype_c.isVariableString():
    readVlenStringData(s, dset)
  else:
    readFixedStringData(s, dset)

proc read*[T](dset: H5DataSet, t: typedesc[T], allowVlen = false): seq[T] =
  ## procedure to read the data of an existing dataset and return it as a 1D sequence.
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    t: typedesc[T] = the Nim datatype of the dataset to be read. If type is given
  ##         as a `seq[seq[T]]` the dataset has to be variable length.
  ##    allowVlen: bool = if true it allows to read variable length data. Note this
  ##         means the vlen data will be flattened to 1D!
  ## outputs:
  ##    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset or a `seq[seq[T]]` for variable length data.
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  when T is seq:
    if dset.isVlen:
      result = dset.readVlen(getInnerType(t))
    else:
      raise newException(ValueError, "Can only read variable length data into " &
        "a seq[seq[T]]. Uniform data has to be read into a 1D seq[T] currently.")
  else:
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
      when T is cstring:
        {.error: "Cannot read into a `cstring` as we cannot return a cstring without manual " &
          "allocation in the calling scope. Use the `ptr T` (using `char`) `read` procedure.".}
      when T is string:
        result.readStringData(dset)
      else:
        dset.read(result)

proc read*[T](dset: H5DataSet, inds: HSlice[int, int], t: typedesc[T], allowVlen = false): seq[T] =
  ## procedure to read a slice of an existing 1D dataset
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to read from
  ##    t: typedesc[T] = the Nim datatype of the dataset to be read. If type is given
  ##         as a `seq[seq[T]]` the dataset has to be variable length.
  ##    allowVlen: bool = if true it allows to read variable length data. Note this
  ##         means the vlen data will be flattened to 1D!
  ## outputs:
  ##    seq[T]: a flattened sequence of the data in the (potentially) multidimensional
  ##         dataset or a `seq[seq[T]]` for variable length data.
  ## throws:
  ##     ValueError: in case the given typedesc t is different than
  ##         the datatype of the dataset
  if dset.isVlen():
    result = dset.read_hyperslab_vlen(
      T,
      offset = @[inds.a, 0], count = @[inds.b - inds.a + 1, 1]
    ).flatten()
  else:
    result = dset.read_hyperslab(
      T,
      offset = @[inds.a], count = @[inds.b - inds.a + 1]
    )

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

proc readAs*[T: SomeNumber](h5f: H5File, dset: string, dtype: typedesc[T]): seq[dtype] =
  ## reads data from the H5file without an intermediate return of a `H5DataSet`
  let dset = h5f.get(dset.dset_str)
  result = dset.readAs(dtype)

when false:
  ## XXX: this was an idea to add a non raising API at some point. Guess I never finished that.
  proc getDset(h5f: H5File, dsetName: string): Option[H5DataSet] =
    ## convenience proc to return the dataset with name dsetName
    ## if it does not exist, KeyError is thrown
    ## inputs:
    ##    h5f: H5File = the file object from which to get the dset
    ##    obj_name: string = name of the dset to get
    ## outputs:
    ##    H5DataSet = if dataset is found
    ## throws:
    ##    KeyError: if dataset could not be found
    let dset_exist = hasKey(h5f.datasets, dsetName)
    if dset_exist == false:
      #raise newException(KeyError, "Dataset with name: " & dsetName & " not found in file " & h5f.name)
      result = none(H5DataSet)
    else:
      result = some(h5f.datasets[dsetName])

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

proc parseChunkSizeAndMaxShape(dset: H5DataSet, chunksize, maxshape: seq[int],
                               filter: H5Filter, autoChunkIfFilter: bool): herr_t =
  ## proc to parse the chunk size and maxhshape arguments handed to the create_dataset()
  ## Takes into account the different possible scenarios:
  ##    chunksize: seq[int] = a sequence containing the chunksize: the dataset should be
  ##            chunked in (if any). Empty seq: no chunking (but no resizing either!)
  ##    maxshape: seq[int] = a sequence containing the maxmimum sizes for each
  ##            dimension in the dataset.
  ##            - If empty sequence and chunksize == @[] -> no chunking, maxshape == shape
  ##            - If empty sequence and chunksize != @[] -> chunking, maxshape == shape
  ##            To set a specific dimension to unlimited set that dimensions value to `int.high`.

  var chunksize = chunksize
  if filter.kind != fkNone and chunksize.len == 0:
    ## In this case we must modify the chunk size
    if not autoChunkIfFilter:
      raise newException(ValueError, "Cannot apply compression filter " & $filter.kind & " to the " &
        "dataset " & $dset.name & " without a chunk size. Automatic chunking is disabled.")
    ## Compute a chunk size that is O(64KB) chunks
    let dims = dset.shape.len
    for x in dset.shape:
      chunksize.add min(pow(8192.float, 1 / dims.float).ceil.int, x)

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
    result = 0.herr_t
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

proc create_dataset_in_file(h5file_id: FileID, dset: H5DataSet): DatasetID =
  ## proc to create a given dataset in the H5 file described by `h5file_id`
  # TODO: I think the first if branch is never used, because `maxshape` is always
  # set to the `shape` (if no maxshape is given) or the given max shape. Therefore
  # the check can never succeed. Ok if we only check for chunksize?
  let dataspace_id = simple_dataspace(dset.shape, dset.maxshape)
  if dset.maxshape.len == 0 and dset.chunksize.len == 0:
    result = H5Dcreate2(h5file_id.id, dset.name.cstring, dset.dtype_c.id, dataspace_id.id,
                         H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT)
      .toDatasetID
  else:
    # in this case we are definitely working with chunked memory of some
    # sorts, which means that the dataset creation property list is set
    result = H5Dcreate2(h5file_id.id, dset.name.cstring, dset.dtype_c.id, dataspace_id.id,
                         H5P_DEFAULT, dset.dcpl_id.id, H5P_DEFAULT)
      .toDatasetID

proc open(fid: FileID, dset: string): DatasetID =
  ## Opens the given dataset `dset` using default properties
  ##
  ## Does not check whether the dataset exists, up to the user to do beforehand.
  result = H5Dopen2(fid.id, dset.cstring, H5P_DEFAULT)
    .toDatasetID
  if result.id < 0:
    raise newException(HDF5LibraryError, "Failed to open the dataset " & $dset & "!")

proc initDatasetAccessPropertyList(): DatasetAccessPropertyListID =
  ## Creates a default `dapl` ID
  result = H5Pcreate(H5P_DATASET_ACCESS).toDatasetAccessPropertyListID()

proc initDatasetCreatePropertyList(): DatasetCreatePropertyListID =
  ## Creates a default `dcpl` ID
  result = H5Pcreate(H5P_DATASET_CREATE).toDatasetCreatePropertyListID()

proc getDatasetAccessPropertyList(dset_id: DatasetID): DatasetAccessPropertyListID =
  result = H5Dget_access_plist(dset_id.id).toDatasetAccessPropertyListID()

proc getDatasetCreatePropertyList(dset_id: DatasetID): DatasetCreatePropertyListID =
  result = H5Dget_create_plist(dset_id.id).toDatasetCreatePropertyListID()

proc create_dataset*[T: (tuple | int | seq)](
    h5f: H5File,
    dset: string,
    shape: T,
    dtype: (typedesc | DatatypeID),
    chunksize: seq[int] = @[],
    maxshape: seq[int] = @[],
    filter: H5Filter = H5Filter(kind: fkNone),
    overwrite = false,
    autoChunkIfFilter = true): H5DataSet =
  ## procedure to create a dataset given a H5file object. The shape of
  ## that type is given as a tuple, the datatype as a typedescription
  ## inputs:
  ##    h5file: H5File = the H5File received by H5file() into which the data
  ##                   set belongs
  ##    dset: string = the name (incl. path) of the dataset to be created
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
  ##    filter: The filter to apply to the dataset for compression.
  ##    autoChunkIfFilter: Automatically chunk the data if a filter is used. This is mandatory
  ##            to use filters. Disabling this will raise an exception in this case.
  ## outputs:
  ##    ... some dataset object, part of the file?!
  ## throws:
  ##    ... some H5 C related errors ?!
  if {akExclusive, akReadWrite, akTruncate} * h5f.accessFlags == {}:
    raise newException(ReadOnlyError, "Cannot create a dataset in " & $h5f.name &
      ", because the file is opened with read-only access!")

  # remove any trailing / and insert potential missing root /
  var dsetName = formatName(dset)
  if h5f.isDataset(dsetName) and not overwrite: # if exists and no intention to overwrite, just return
    return h5f[dsetName.dset_str]
  ## TODO: should create_dataset fail by default if the dataset exists?

  when T is int:
    # in this case deal with regular 1D array. Just keep it as 1 element tuple
    let shape = (shape, )
    # need to deal with the shape of the dataset to be created
    let shape_seq = parseShapeTuple(shape)
  elif T is tuple:
    # need to deal with the shape of the dataset to be created
    let shape_seq = parseShapeTuple(shape)
  elif T is seq:
    let shape_seq = shape

  when dtype is seq or dtype is DatatypeID:
    ## Check if given `shape` is not causing problems
    if shape_seq.len != 1 and shape_seq[1].int > 1:
      raise newException(ValueError, "The `dtype` argument is " & $dtype & " for the `create_dataset` " &
        "call for the dataset: " & $dset & ". This implies a variable length (VLEN) dataset. The given " &
        "shape: " & $shape & " however is not 1 dimensional. For a VLEN dataset only give the " &
        "*number* of variable length elements to store!")

  # given dset name, either get or create group in which it belongs
  let group = create_group(h5f, dsetName.getParent) # getOrCreateGroup(h5f, dset.parent)

  withDebug:
    echo "Getting parent Id of ", dset.name
  let parent_id = getParentId(h5f, dset)

  # set up the dataset object
  let file_ref = h5f.getFileRef()
  result = newH5DataSet(dsetName, file_ref.name,
                        file_ref.file_id,
                        parent = group.name,
                        parentId = parentId,
                        shape = shape_seq)
  # first get the appropriate datatype for the given Nim type
  when dtype is DatatypeID:
    result.dtype_c = dtype
  elif dtype is string:
    # user wishes to construct dataset of variable length strings. `variableString`
    # takes care of turning the `DatatypeID` into a `H5T_VARIABLE` type
    result.dtype_c = nimToH5type(dtype, variableString = true)
  else:
    result.dtype_c = nimToH5type(dtype)
  # set the datatype as H5 type here, as its needed to create the dataset
  # the Nim dtype descriptors are set below from the data in the file
  result.dtype_class = result.dtype_c.getTypeClass()


  # create the dataset access property list
  result.dapl_id = initDatasetAccessPropertyList()
  # create the dataset create property list
  result.dcpl_id = initDatasetCreatePropertyList()

  # in case we wish to use chunked storage (either resizable or unlimited size)
  # we need to set the chunksize on the dataset create property list
  try:
    let status = result.parseChunkSizeAndMaxShape(chunksize, maxshape, filter, autoChunkIfFilter)
    if status >= 0:
      # potentially apply filters
      result.setFilters(filter)
      # check whether there already exists a dataset with the given name
      var exists = h5f.isDataset(dsetName)
      if exists and overwrite:
        discard group.delete(result.name)        # delete the element in the group
      if not exists or overwrite:
        # does not exist or overwrite
        result.dataset_id = create_dataset_in_file(h5f.file_id, result)
      else:
        doAssert false, "This is a dead branch. We have returned at the beginning of the proc!"
    else:
      raise newException(UnkownError, "Unkown error occured due to call to " &
        "`parseChunkSizeAndMaxhShape` returning with status = $#" % $status)
  except HDF5LibraryError:
    #let msg = getCurrentExceptionMsg()
    echo "Call to HDF5 library failed in `parseChunkSizeAndMaxShape` from `create_dataset`"
    raise

  # set the dtype fields of the object
  when dtype is DatatypeID:
    # for now we only support vlen arrays, later we need to
    # differentiate between the different H5T class types
    result.dtype = "vlen"
    result.dtypeAnyKind = dkSequence
  else:
    # in case of non vlen datatypes, don't take the immediate string of the datatype
    # but instead get it from the H5 datatype to conform to the same datatype, which
    # we read back from the file after writing
    result.dtype = getDtypeString(result.dataset_id)
    result.dtypeAnyKind = parseEnum[DtypeKind]("dk" & result.dtype, dkNone)
  # now get datatype base kind if vlen datatype
  if result.dtypeAnyKind == dkSequence:
    # need to get datatype id (id specific to this dataset describing type),
    # then super, which is the base type of a VLEN type and finally convert
    # that to a AnyKind type
    result.dtypeBaseKind = result.dataset_id.getDatasetType().getBasetype()

  # now create attributes field
  result.attrs = initH5Attributes(ParentID(kind: okDataset,
                                         did: result.dataset_id),
                                  result.name,
                                  "H5DataSet")
  h5f.datasets[dsetName] = result

proc prepareData[T](data: openArray[T] | seq[T], dset: H5Dataset,
                    isVlen: static bool): auto =
  when T is string and not isVlen:
    ## maps the given `seq[string]` to something that is flat in memory.
    ## This is for the case of constructing a dataset of type `array[N, char]`.
    ## We simply copy over the input string data to a flat `seq[char]` to
    ## have a flat object to write. As the H5 library knows the fixed size of
    ## each element, they can (and must) be flat in memory.
    ##
    ## i.e. corresponds to:
    ## `create_dataset(..., array[N, char]); dset[all] = @["hello", "foo"]`
    let size = H5Tget_size(dset.dtype_c.id)
    result = newSeq[char](data.len * size.int)
    for i, el in data:
      # only copy as many bytes as either in input string to write or
      # as we have space in the allocated fixed length dataset
      let copyLen = min(size.int,  el.len)
      when (NimMajor, NimMinor, NimPatch) >= (1, 7, 0):
        copyMem(result[i * size.int].addr, el[0].addr, copyLen)
      else:
        copyMem(result[i * size.int].addr, el[0].unsafeAddr, copyLen)
  elif T is seq|openArray and not isVlen:
    # just make sure the data is a flat `seq[T]`. If not, flatten to have
    # flat memory to write
    ## XXX: if nested data of a type that needs conversion not handled!
    result = seqmath.flatten(data)
  elif T.needsCopy() or isVlen:
    ## replace the string fields by `cstring` and put all data into a buffer
    result = copyFlat(data)
  else:
    result = data

proc writeH5[T: ptr | pointer](
  dset: H5Dataset, data: T,
  memspaceId = H5S_ALL,
  hyperslabId = H5S_all
                             ): herr_t =
  ## Wrapper around the actual HDF5 write call
  result = H5Dwrite(dset.dataset_id.id,
                    dset.dtype_c.id,
                    memspaceId,
                    hyperslabId,
                    H5P_DEFAULT,
                    data)

proc `$`*(x: hvl_t): string =
  if x.len == 0:
    result = "hvl_t(len: 0, p: nil)"
  else:
    result = "hvl_t(len: " & $x.len & ", p: " & $x.p.repr & ")"

proc writeImpl[T](dset: H5Dataset, data: seq[T] | openArray[T] | ptr T,
                  memspaceId = H5S_ALL,
                  hyperslabId = H5S_all): herr_t =
  ## Performs the `H5Dwrite` operation to the given dataset for the given input data
  ## to be written.
  template writeData(buf: untyped): untyped {.dirty.} =
    when typeof(buf) is Buffer:
      result = writeH5(dset,
                       buf.data,
                       memspaceId,
                       hyperslabId)
    elif typeof(buf) is ptr T:
      result = writeH5(dset,
                       buf,
                       memspaceId,
                       hyperslabId)
    else:
      result = writeH5(dset,
                       address(buf[0]),
                       memspaceId,
                       hyperslabId)

  when typeof(data) is ptr T:
    ## ptr T is just written as is. Caller responsible
    writeData(data)
  elif T is seq:
    ## Need to copy data!
    #static: echo "[INFO] A write call to write a dataset of type " & $T & " must copy " &
    #  "the data to a suitable buffer for the HDF5 library."
    if dset.isVlen():
      let buf = prepareData(data, dset, isVlen = true) # seqToVlen() # (copy!)
      writeData(buf)
    else:
      let buf = prepareData(data, dset, isVlen = false) # flat dataset, needs to be flattened to 1D seq (copy!)
      writeData(buf)
  elif T is string:
    # map strings to `cstring` to match H5 expectation
    ## XXX: depends on variable or fixed
    if dset.isVlen():
      let buf = prepareData(data, dset, isVlen = true) #seqToVlen() ## XXX: is this branch ever used? # (copy!)
      writeData(buf)
    elif dset.dtype_class == H5T_STRING and dset.dtype_c.isVariableString:
      # This branch corresponds to writing variable length strings (*not* variable length
      # data of type `char`!). Data is converted to `cstring` to have data that is flat
      # in memory (which `seq[string]` is not!)
      let buf = data.mapIt(it.cstring) # (copy!)
      writeData(buf)
    else:
      # this case is for fixed size strings. Convert to a flat `seq[char]`
      let buf = prepareData(data, dset, isVlen = false) # (copy!)
      writeData(buf)
  else: # 1D
    ## check if type needs to be copied
    when T.needsCopy():
      var buf = prepareData(data, dset, isVlen = false)
    else:
      template buf: untyped = data # (no copy!)
    writeData(buf)

proc write*[T](dset: H5DataSet, data: seq[T]) =
  ## procedure to write the full dataset `data` to `dset`. The data must
  ## match the type & shape of the dataset.
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##          about dataset shape, dtype etc. to write to
  ##    data: openArray[T] = any array type containing the data to be written
  ##         needs to be of the same size as the shape given during creation of
  ##         the dataset or smaller
  ## throws:
  ##    ValueError: if the shape of the input dataset is different from the reserved
  ##         size of the dataspace on which we wish to write in the H5 file
  ##         TODO: create an appropriate Exception for this case!
  # TODO: IMPORTANT: think about whether we should be using array types instead
  # of a dataspace of certain dimensions for arrays / nested seqs we're handed
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
  if shape[0] == data.shape[0]:
    let err = writeImpl(dset, data)
    withDebug:
      echo "Trying to write data_write ", data_write
    if err < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while calling `H5Dwrite`.")
  else:
    var msg = "Wrong input shape of data to write in `[]=` while accessing " &
      "`$#`. Given shape `$#`, dataset has shape `$#`"
    msg = msg % [$dset.name, $data.shape, $dset.shape]
    raise newException(ValueError, msg)

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
  dset.write(data)

# Forward declare read and write hyperslab procedures for convenience
# writing / reading procedures (for the case of slices)
proc write_hyperslab*[T](dset: H5DataSet,
                         data: seq[T] | openArray[T] | ptr T,
                         offset,
                         count: seq[int],
                         stride: seq[int] = @[],
                         blk: seq[int] = @[])
proc read_hyperslab*[T](dset: H5DataSet, dtype: typedesc[T],
                        offset, count: seq[int], stride: seq[int] = @[], blk: seq[int] = @[],
                        full_output = false): seq[T]
proc read_hyperslab_vlen*[T](dset: H5DataSet, dtype: typedesc[T],
                             offset, count: seq[int], stride: seq[int] = @[], blk: seq[int] = @[],
                             full_output = false): seq[seq[T]]


proc write*[T](dset: H5DataSet, inds: HSlice[int, int], data: seq[T]) =
  ## procedure to write a sequence to data at the slice index `inds`. This is
  ## only valid for 1D datasets!
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to write to
  ##    inds: HSlice[int, int] = slice of a range, which to write in dataset
  ##    data: openArray[T] = any array type containing the data to be written
  ##         needs to be of the same size as the shape given during creation of
  ##         the dataset or smaller
  if dset.shape.len > 1:
    raise newException(IndexDefect, "Slice assignment is only valid for 1D datasets. " &
      "Given dataset has shape " & $dset.shape & ".")
  dset.write_hyperslab(data,
                       offset = @[inds.a],
                       count = @[inds.b - inds.a + 1])

proc `[]=`*[T](dset: H5DataSet, inds: HSlice[int, int], data: seq[T]) =
  ## procedure to write a sequence to data at the slice index `inds`. This is
  ## only valid for 1D datasets!
  ## inputs:
  ##    dset: var H5DataSet = the dataset which contains the necessary information
  ##         about dataset shape, dtype etc. to write to
  ##    inds: HSlice[int, int] = slice of a range, which to write in dataset
  ##    data: openArray[T] = any array type containing the data to be written
  ##         needs to be of the same size as the shape given during creation of
  ##         the dataset or smaller
  dset.write(inds, data)

proc write_dataset*[TT](h5f: H5File, name: string, data: TT,
                        overwrite = false): H5DataSet =
  ## convenience proc to create a dataset and write data it immediately
  type T = getInnerType(TT)
  result = h5f.create_dataset(name, data.shape, T, overwrite = overwrite)
  result.write(data)

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
  let shape = dset.shape
  withDebug:
    echo "shape is ", shape, " of dset ", dset.name
    echo "data is of ", type(data).name, " and length = ", length

  # only write pointer data if shorter than size of dataset
  if shape.foldl(a * b) <= length:
    if dset.isVlen():
      raise newException(ValueError, "Cannot write variable length data " &
        "using `unsafeWrite`!")
    else:
      let err = writeH5(dset, data)
      if err < 0:
        withDebug:
          echo "Trying to write data_write ", data.repr
        raise newException(HDF5LibraryError, "Call to HDF5 library failed " &
          "while calling `H5Dwrite` in `unsafeWrite`")
  else:
    var msg = "Length of `data` in `unsafeWrite` exceeds size of dataset " &
     "Length: $#, Dataset: $#, Dataset shape: $#"
    msg = msg % [$length, $dset.name, $dset.shape]
    raise newException(ValueError, msg)

proc writeCoord*[T: seq, U](dset: H5DataSet, coord: seq[T], data: seq[U]) =
  ## Writes the `data` of variable or fixed length type at `coord` to the dataset `dset`.
  ##
  ## Essentially takes care of selecting the right dataspace for each coordinate and then
  ## hands these to the `write` call.
  #when U isnot seq:
  #  var mdata = @[data]
  #else:
  #  var mdata = data
  var mdata = data
  let dataValid = if coord.len == mdata.len: true else: false
  if dataValid:
    let memspaceId = create_simple_memspace_1d(coord)
    let dataspaceId = dset.select_elements(coord)
    let err = writeImpl(dset, mdata,
                        memspaceId.id,
                        dataspaceId.id)
    # DEBUGGING H5 calls
    withDebug:
      echo "memspace select ", H5Sget_select_npoints(memspace_id.id)
      echo "dataspace select ", H5Sget_select_npoints(dset.dataspace_id.id)
      echo "dataspace select ", H5Sget_select_elem_npoints(dset.dataspace_id.id)
      echo "dataspace is valid ", H5Sselect_valid(dset.dataspace_id.id)
      echo "memspace is valid ", H5Sselect_valid(memspace_id.id)

      var start: seq[hsize_t] = @[hsize_t(999), 999]
      var ending: seq[hsize_t] = @[hsize_t(999), 999]
      echo H5Sget_select_bounds(dset.dataspace_id.id, addr(start[0]), addr(ending[0]))
      echo "start and ending ", start, " ", ending
    if err < 0:
      withDebug:
        echo "Trying to write data_hvl ", data_hvl
      raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
        "calling `H5Dwrite` in `write`")
    memspaceId.close()
    dataspaceId.close()
  else:
    var msg = "Invalid coordinates or corresponding data to write in " &
      "`write_vlen`. Coord shape `$#`, data shape `$#`"
    msg = msg % [$coord.shape, $data.shape]
    raise newException(ValueError, msg)

template write*[T: seq, U](dset: H5DataSet, coord: seq[T], data: seq[U]) =
  ## template around both write fns for normal and vlen data
  if dset.isVlen():
    dset.writeCoord(coord, data)
  else:
    dset.writeCoord(coord, data)

proc write*[T: (SomeNumber | bool | char | string), U](dset: H5DataSet,
                                                       coord: seq[T],
                                                       data: seq[U]) =
  ## template around both write fns for normal and vlen data in case
  ## the coordinates are given as a seq of numbers (i.e. for 1D datasets!)
  if dset.isVlen():
    # we convert the list of indices to corresponding (y, x) coordinates, because
    # each VLEN table with 1 column, still is a 2D array, which only has the
    # x == 0 column
    dset.writeCoord(mapIt(coord, @[it, 0]), data)
  else:
    # need to differentiate 2 cases:
    # - either normal data is N dimensional (N > 1) in which case
    #   coord is a SINGLE coordinate for the array
    # - or data is 1D (read (N, ) dimensional) in which case we have
    #   handed 1 or more indices to write 1 or more elements!
    if dset.shape.len != 1:
      dset.writeCoord(@[coord], data)
    else:
      # in case of 1D data, need to separate each element into 1 element
      dset.writeCoord(mapIt(coord, @[it]), data)

proc write*[T: (seq | SomeNumber | bool | char | string)](dset: H5DataSet,
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
    if dset.isVlen():
      # does not make sense for tensor
      dset.writeCoord(@[ind], data)
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
      dset.writeCoord(coord, data)
  else:
    # in this case we're dealing with a single value for a single element
    # do not have to differentiate between VLEN and normal data
    dset.writeCoord(@[@[ind]], @[data])

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

proc select_elements[T](dset: H5DataSet, coord: seq[T]): DataspaceID {.inline, discardable.} =
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
  let res = H5Sselect_elements(result.id,
                               H5S_SELECT_SET,
                               csize_t(coord.len),
                               address(flat_coord[0]))
  if res < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `select_elements` " &
      "after a call to `H5Sselect_elements` with return code " & $res)

proc `[]`*[T](dset: H5DataSet, t: typedesc[T]): seq[T] =
  ## Reads the given dataset into a `seq[T]`. If the given datatype does not
  ## match the datatype of the data stored in `dset`, a `ValueError` will be
  ## raised.
  result = dset.read(t)

proc `[]`*[T](dset: H5DataSet, inds: HSlice[int, int], t: typedesc[T]): seq[T] =
  ## Reads the given slice from the 1D dataset `dset`.
  result = dset.read(inds, t)

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

proc read*[T](dset: H5DataSet, indices: seq[int], t: typedesc[T]): seq[T] =
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

proc `[]`*[T](h5f: H5File, name: string, dtype: typedesc[T]): seq[T] =
  ## reads data from the H5file without an intermediate return of a `H5DataSet`
  result = h5f.get(name.dset_str).read(dtype)

proc `[]`*[T](dset: H5DataSet, indices: seq[int], t: typedesc[T]): seq[T] =
  ## convenience overload for `dset.read(indices, t)`
  dset.read(indices, t)

proc `[]`*[T](dset: H5DataSet, indices: seq[int], t: DatatypeID, dtype: typedesc[T]): seq[seq[T]] =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, indices)

proc `[]`*[T](h5f: H5File, name: string, indices: seq[int], dtype: typedesc[T]): seq[T] =
  ## reads a single or several elements from a dataset
  result = h5f.get(name.dset_str).read(indices, dtype)

proc `[]`*[T](h5f: H5File, name: string, indices: seq[int], t: DatatypeID, dtype: typedesc[T]): seq[seq[T]] =
  ## reads a single or several elements from a variable length dataset
  result = h5f.get(name.dset_str).read(t, dtype, indices)

proc `[]`*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T], indices: seq[int]): seq[seq[T]]
  {.deprecated: "This proc is deprecated! Use the version with `indices` as the second argument!".} =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, indices)

proc `[]`*[T](dset: H5DataSet, idx: int, t: DatatypeID, dtype: typedesc[T]): seq[T] =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, idx)

proc `[]`*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T], idx: int): seq[T]
  {.deprecated: "This proc is deprecated! Use the version with `idx` as the second argument!".} =
  ## reads a single or several elements from a variable length dataset
  result = read(dset, t, dtype, idx)

proc `[]`*[T](dset: H5DataSet, t: DatatypeID, dtype: typedesc[T]): seq[seq[T]] =
  ## reads a whole variable length dataset, wrapper around `read`
  result = read(dset, t, dtype)

proc `[]`*[T](h5f: H5File, name: string, t: DatatypeID, dtype: typedesc[T]):
                seq[seq[T]] =
  ## reads variable length data from the H5file without an intermediate return
  ## of a `H5DataSet`
  ## `t` is a variable length `special_type` created with the proc of the same
  ## name
  result = h5f.get(name.dset_str).read(t, dtype)

template `[]`*(grp: H5Group, dsetName: dset_str): H5DataSet =
  ## Accessor relative from a basegroup to a dataset
  bind `/`
  grp.file_ref[(grp.name / dsetName.string).dset_str]

template withDset*(h5dset: H5DataSet, actions: untyped) =
  ## Convenience template to read a dataset from the file and perform actions
  ## with that dataset, without having to manually check the data type of the
  ## dataset.
  ##
  ## Simply reads all the data of the given dataset into the injected `dset`
  ## variable.
  case h5dset.dtypeAnyKind
  of dkBool:
    let dset {.inject.} = h5dset.read(bool)
    actions
  of dkChar:
    let dset {.inject.} = h5dset.read(char)
    actions
  of dkString:
    let dset {.inject.} = h5dset.read(string)
    actions
  of dkFloat32:
    let dset {.inject.} = h5dset.read(float32)
    actions
  of dkFloat64:
    let dset {.inject.} = h5dset.read(float64)
    actions
  of dkInt8:
    let dset {.inject.} = h5dset.read(int8)
    actions
  of dkInt16:
    let dset {.inject.} = h5dset.read(int16)
    actions
  of dkInt32:
    let dset {.inject.} = h5dset.read(int32)
    actions
  of dkInt64:
    let dset {.inject.} = h5dset.read(int64)
    actions
  of dkUint8:
    let dset {.inject.} = h5dset.read(uint8)
    actions
  of dkUint16:
    let dset {.inject.} = h5dset.read(uint16)
    actions
  of dkUint32:
    let dset {.inject.} = h5dset.read(uint32)
    actions
  of dkUint64:
    let dset {.inject.} = h5dset.read(uint64)
    actions
  of dkSequence:
    # need to perform same game again...
    case h5dset.dtypeBaseKind
    of dkBool:
      let dset {.inject.} = h5dset.readVlen(bool)
      actions
    of dkChar:
      let dset {.inject.} = h5dset.readVlen(char)
      actions
    of dkString:
      let dset {.inject.} = h5dset.readVlen(string)
      actions
    of dkFloat32:
      let dset {.inject.} = h5dset.readVlen(float32)
      actions
    of dkFloat64:
      let dset {.inject.} = h5dset.readVlen(float64)
      actions
    of dkInt8:
      let dset {.inject.} = h5dset.readVlen(int8)
      actions
    of dkInt16:
      let dset {.inject.} = h5dset.readVlen(int16)
      actions
    of dkInt32:
      let dset {.inject.} = h5dset.readVlen(int32)
      actions
    of dkInt64:
      let dset {.inject.} = h5dset.readVlen(int64)
      actions
    of dkUint8:
      let dset {.inject.} = h5dset.readVlen(uint8)
      actions
    of dkUint16:
      let dset {.inject.} = h5dset.readVlen(uint16)
      actions
    of dkUint32:
      let dset {.inject.} = h5dset.readVlen(uint32)
      actions
    of dkUint64:
      let dset {.inject.} = h5dset.readVlen(uint64)
      actions
    else:
      echo "WARNING: `withDset` for type of ", h5dset.dtypeBaseKind, " not supported"
  else:
    echo "WARNING: `withDset` nothing to do, dataset is of type ", h5dset.dtypeAnyKind
    discard

template withDset*(h5f: H5File, name: string, actions: untyped) =
  ## Version of `withDset`, which acts on an input file and a dataset given by
  ## a string name.
  let h5dset = h5f[name.dset_str]
  withDset(h5dset):
    actions

proc h5SelectHyperslab(dspace_id: DataspaceID | MemspaceID | HyperslabID,
                       offset, count, stride, blk: var seq[hsize_t]): herr_t {.inline.} =
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
  result = H5Sselect_hyperslab(dspace_id.id,
                               H5S_SELECT_SET,
                               addr(offset[0]),
                               addr(stride[0]),
                               addr(count[0]),
                               addr(blk[0]))

proc parseHyperslabSelection(offset, count: seq[int], stride: seq[int] = @[], blk: seq[int] = @[]):
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
                      stride: seq[int] = @[],
                      blk: seq[int] = @[]): HyperslabID =
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
  result = dset.dataspace_id.toHyperslabID() # this is a hyperslab and not a regular
                                             # dataspace anymore after calls to next:
  err = h5SelectHyperslab(result, moffset, mcount, mstride, mblk)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Sselect_hyperslab` in `select_hyperslab`")

proc write_hyperslab*[T](dset: H5DataSet,
                         data: seq[T] | openArray[T] | ptr T,
                         shape: seq[int],
                         offset,
                         count: seq[int],
                         stride: seq[int] = @[],
                         blk: seq[int] = @[]) =
  ## proc to select a hyperslab and write to it.
  ## The input data must be a pointer to a contiguous memory array!
  ##
  ## The HDF5 notation for hyperslabs is used.
  ## See sec. 7.4.1.1 in the HDF5 user's guide:
  ## https://support.hdfgroup.org/HDF5/doc/UG/HDF5_Users_Guide-Responsive%20HTML5/index.html
  # if no data given, simply return
  # TODO: parse hyperslab selection and make sure data is same number as hyperslab
  # covers!
  if shape.len == 0 :
    return
  when typeof(data) is seq | openArray:
    if data.len == 0:
      return # nothing to do in this case!
  # flatten the data array to be written
  let memspace_id = simple_memspace(shape)
  let hyperslab_id = dset.select_hyperslab(offset, count, stride, blk)
  withDebug:
    echo "Selected now write space id ", hyperslab_id
  let err = writeImpl(dset, data, memspaceId.id, hyperslabId.id)
  if err < 0:
    withDebug:
      echo "Trying to write mdata with shape ", mdata.shape
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Dwrite` in `write_hyperslab`")
  memspace_id.close()

proc write_hyperslab*[T](
  dset: H5DataSet,
  data: seq[T] | openArray[T] | ptr T,
  offset,
  count: seq[int],
  stride: seq[int] = @[],
  blk: seq[int] = @[]) =
  ## proc to select a hyperslab and write to it for 1D data.
  ## The HDF5 notation for hyperslabs is used.
  ## See sec. 7.4.1.1 in the HDF5 user's guide:
  ## https://support.hdfgroup.org/HDF5/doc/UG/HDF5_Users_Guide-Responsive%20HTML5/index.html
  if data.len == 0 :
    return # nothing to do in this case!
  if dset.isVlen():
    # in case of variable length data, the dataspace should be of layout
    # (# VLEN elements, 1)
    let shape = @[data.shape[0], 1]
    # in case we're dealing with variable length data, we know that the `data` is always
    # a nested `seq`, i.e. `T` is a `seq`. Need this guard, because otherwise code, which
    # does not actually run into the "VLEN" branch here will still be compiled against
    # it. The call to `toH5vlen` will fail, since it's a template which does not return
    # anything for `T isnot seq`.
    # TODO: replace template by typed template / proc?
    when T is seq:
      write_hyperslab(dset,
                      data,
                      shape,
                      offset, count, stride, blk)
    else:
      raise newException(ValueError, "Writing to variable length data with a 1D input is " &
        "not possible.")
  else:
    when T is seq:
      var mdata = data.flatten
    else:
      template mdata(): untyped = data # already flat!
    write_hyperslab(dset,
                    mdata,
                    data.shape,
                    offset, count, stride, blk)

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
               full_output: bool): (MemspaceID, HyperslabID, int) =
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

  ## XXX: NOTE: in the following aren't `memspace_id` and `hyperslab_id` the same thing???
  ## memspace goes to `h5SelectHyperslab` directly, `hyperslab_id` comes from a call to
  ## `select_hyperslab` first?!
  ## Difference is that `select_hyperslab` starts from a call to `dataspace_id` of the
  ## dataset, whereas for our call here, we start from a memspace. This is so weird.
  var memspace_id: MemspaceID
  if full_output == true:
    memspace_id = simple_memspace(dset.shape)
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
    memspace_id = simple_memspace(shape)

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
                        offset, count: seq[int], stride: seq[int] = @[], blk: seq[int] = @[],
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
  readImpl(dset, mdata, memspaceId.id, hyperslabId.id)
  result = mdata

proc read_hyperslab_vlen*[T](dset: H5DataSet, dtype: typedesc[T],
                             offset, count: seq[int], stride: seq[int] = @[], blk: seq[int] = @[],
                             full_output = false): seq[seq[T]] =
  ## proc to read an arbitrary hyperslab from a variable length dataset.
  ## See `read_hyperslab` for documentation
  var err: herr_t
  if not typeMatches(dtype, dset.dtypeBaseKind.anyTypeToString):
    raise newException(ValueError,
                       "Wrong datatype as arg to `read_hyperslab`. Given " &
                       "`$#`, dset is `$#`" % [$dtype, $dset.dtypeBaseKind])

  let (memspace_id,
       hyperslab_id,
       n_elements) = dset.hyperslab(offset,
                                    count,
                                    stride,
                                    blk,
                                    full_output)

  doAssert dset.isVlen()
  var mdata = newSeq[seq[T]](n_elements)
  readImpl(dset, mdata, memspaceId.id, hyperslabId.id)
  result = mdata

func isChunked*(dset: H5DataSet): bool =
  ## returns `true` if the dataset is using chunked storage
  result = H5Pget_layout(dset.dcpl_id.id) == H5D_CHUNKED

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
    # proc is called. We store it in an unused variable, so that it won't
    # be closed until we leave this scope (via `=destroy`)
    # (dataspace_id is a proc!)
    let dspace = dset.dataspace_id
    let status = H5Dset_extent(dset.dataset_id.id, address(newshape[0]))
    # set the shape we just resized to as the current shape
    withDebug:
      echo "Extending the dataspace to ", newshape
    dset.shape = mapIt(newshape, int(it))
    # after all is said and done, refresh again
    discard H5Dget_space(dset.dataset_id.id)
    if status < 0:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed in " &
                         "`resize` calling `H5Dset_extent`")
  else:
    raise newException(ImmutableDatasetError, "Cannot resize a non-chunked " &
                       " (i.e. contiguous) dataset!")

proc add*[T](dset: H5DataSet, data: seq[T] | openArray[T] | ptr T,
             shape: seq[int],
             axis = 0, rewriteAsChunked = false) =
  ## Adds the `data` to the `dset` thereby resizing the dataset to fit
  ## the additional data. For this `data` must be compatible with the
  ## existing dataset.
  ## The data is added along `axis`.
  ## If the rewriteAsChunked flag is set to true, the existing dataset
  ## will be read to memory, removed from file, recreated as chunked and
  ## written back to file.
  when typeof(data) is seq | openArray:
    if data.len == 0: return # nothing to do in this case!
  if dset.isChunked:
    # simply resize and write the hyperslab
    let oldShape = dset.shape
    var newShape = oldShape
    newShape[axis] = oldShape[axis] + shape[axis]
    # before resizing, check that newShape <= maxShape
    if zip(newShape, dset.maxShape).anyIt(it[0].int > it[1].int):
      raise newException(ImmutableDatasetError, "The new required shape to " &
        "add data along axis " & $axis & " exceeds the maximum allowed shape!" &
        "\nnewShape: " & $newShape & "\nmaxShape: " & $dset.maxShape)
    dset.resize(newShape)
    var offset = newSeq[int](oldShape.len)
    offset[axis] = oldShape[axis]
    var count = oldShape
    count[axis] = shape[axis]
    dset.write_hyperslab(data,
                         shape,
                         offset = offset,
                         count = count)
  elif rewriteAsChunked:
    raise newException(NotImplementedError, "Rewriting as chunked storage " &
      "not yet implemented.")
  else:
    raise newException(ImmutableDatasetError, "Cannot add data to a non-chunked " &
      "dataset, unless the `rewriteAsChunked` option is set to true!")

proc add*[T: seq|openArray](dset: H5DataSet, data: openArray[T], axis = 0, rewriteAsChunked = false) =
  ## Note: for nested data (VLEN or ND via seq[seq[...]])
  ##
  ## Adds the `data` to the `dset` thereby resizing the dataset to fit
  ## the additional data. For this `data` must be compatible with the
  ## existing dataset.
  ## The data is added along `axis`.
  ## If the rewriteAsChunked flag is set to true, the existing dataset
  ## will be read to memory, removed from file, recreated as chunked and
  ## written back to file.
  if dset.isVlen:
    dset.add(data, @[data.shape[0], 1], axis, rewriteAsChunked)
  else:
    let flat = data.flatten
    dset.add(flat, data.shape, axis, rewriteAsChunked)

proc add*[T: not (seq|openArray)](dset: H5DataSet, data: openArray[T], axis = 0, rewriteAsChunked = false) =
  ## Note: for 1D data (not VLEN)
  ##
  ## Adds the `data` to the `dset` thereby resizing the dataset to fit
  ## the additional data. For this `data` must be compatible with the
  ## existing dataset.
  ## The data is added along `axis`.
  ## If the rewriteAsChunked flag is set to true, the existing dataset
  ## will be read to memory, removed from file, recreated as chunked and
  ## written back to file.
  if dset.isVlen:
    raise newException(ValueError, "Cannot write 1D data to a VLEN dataset " & $dset.name)
  else:
    dset.add(data, data.shape, axis, rewriteAsChunked)

proc open*(h5f: H5File, dset: dset_str) =
  ## Opens the given `dset` and updates the data stored in the `datasets` table of
  ## the given `h5f`.
  ##
  ## If it does not exist, `KeyError` is thrown.
  ## inputs:
  ##    h5f: H5File = the file object from which to get the dset
  ##    dset: string = name of the dset to get
  ## outputs:
  ##    bool = `true` if opening is successful or the dataset is already open.
  ## throws:
  ##    KeyError: if dataset could not be found
  let dsetName = formatName(string(dset))
  let dsetIsOpen = isOpen(h5f, dset)

  var dsetOpen: H5DataSet
  if not dsetIsOpen:
    # before we raise an exception, because the dataset does not yet exist,
    # check whether such a dataset exists in the file we're not aware of yet
    withDebug:
      echo "file id is ", h5f.file_id
      echo "name is ", dsetName
    let dsetInFile = h5f.isDataset(dsetName)
    if dsetInFile:
      var parent = create_group(h5f, dsetName.getParent)
      let file_ref = h5f.getFileRef()
      dsetOpen = newH5DataSet(dsetName, file_ref.name,
                              parent = parent.name,
                              parentID = getH5Id(parent))
      dsetOpen.dataset_id = h5f.file_id.open(dsetName)       # perform the actual open
      dsetOpen.opened = true

      # assign datatype related fields
      let datatype_id = getDatasetType(dsetOpen.dataset_id)
      let f = h5ToNimType(datatype_id)
      if f == dkSequence:
        # dkSequence == VLEN type
        # in this case this only determines dtypeAnyKind, but we don't
        # know the basetype. Set that by another call of the super of
        # the datatype
        dsetOpen.dtypeBaseKind = getBasetype(datatype_id)
        dsetOpen.dtype = "vlen"
      else:
        # get the dtype string from AnyKind
        dsetOpen.dtype = anyTypeToString(f)
      dsetOpen.dtypeAnyKind = f
      dsetOpen.dtype_c = datatype_id.getNativeType()
      dsetOpen.dtype_class = datatype_id.getTypeClass()

      # get the dataset access property list
      dsetOpen.dapl_id = getDatasetAccessPropertyList(dsetOpen.dataset_id)
      # get the dataset create property list
      dsetOpen.dcpl_id = getDatasetCreatePropertyList(dsetOpen.dataset_id)
      withDebug:
        echo "ACCESS PROPERTY LIST IS ", dsetOpen.dapl_id
        echo "CREATE PROPERTY LIST IS ", dsetOpen.dcpl_id
        echo H5Tget_class(datatype_id.id)

      # get the dataspace id of the dataset and the corresponding sizes
      let dataspace_id = dsetOpen.dataspace_id
      (dsetOpen.shape, dsetOpen.maxshape) = getSizeOfDims(dataspace_id)
      # create attributes field
      dsetOpen.attrs = initH5Attributes(ParentID(kind: okDataset,
                                                 did: dsetOpen.dataset_id),
                                        dsetOpen.name,
                                        "H5DataSet")
      # need to close the data type again, otherwise cause resource leak
      datatype_id.close()
    else:
      # check whether there exists a group of same name?
      let groupOfName = h5f.isGroup(dsetName)
      if groupOfName:
        raise newException(ValueError, "Dataset with name: " & dsetName &
          " not found in file " & h5f.name & ". Instead found a group " &
          "of the same name")
      else:
        raise newException(KeyError, "Dataset with name: " & dsetName &
          " not found in file " & h5f.name)
  else:
    dsetOpen = h5f.datasets[dsetName]
    doAssert dsetOpen.opened
    # in this case we still need to update e.g. shape
    # TODO: think about what else we might have to update!
    let dataspace_id = dsetOpen.dataset_id.dataspace_id
    (dsetOpen.shape, dsetOpen.maxshape) = getSizeOfDims(dataspace_id)
  # finally update the dataset in the table
  h5f.datasets[dsetName] = dsetOpen

proc `[]`*(h5f: H5File, name: dset_str): H5DataSet =
  ## Opens and retrieves the dataset with name `name`
  ##
  ## Throws a `KeyError` if the dataset does not exist.
  h5f.open(name) # try to open (will fail if it does not exist)
  let nameStr = formatName name.string
  h5f.datasets[nameStr]

proc get*(h5f: H5File, dset_in: dset_str): H5DataSet =
  ## Convenience helper to open and return a the dataset `dset_in` from the given
  ## `h5f` file.
  result = h5f[dset_in]
