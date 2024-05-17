#[
This file contains the procedures related to attributes.

The attribute types are defined in the datatypes.nim file.
]#

import typeinfo
import tables
import strutils, sequtils

import hdf5_wrapper, h5util, H5nimtypes, datatypes, dataspaces, util

proc `$`*(h5attr: H5Attributes): string =
  result = $(h5attr[])

# forward declare procs, which we need to read the attributes from file
proc read_all_attributes*(h5attr: H5Attributes)

proc openAttrByIdx(h5attr: H5Attributes, idx: int): AttributeID =
  ## proc to open an attribute by its id in the H5 file and returns
  ## attribute id if succesful
  ## need to hand H5Aopen_by_idx the location relative to the location_id,
  ## if I understand correctly
  let loc = "."
  # we read by creation order, increasing from 0
  result = H5Aopen_by_idx(h5attr.parent_id.to_hid_t,
                          loc.cstring,
                          H5_INDEX_CRT_ORDER,
                          H5_ITER_INC,
                          hsize_t(idx),
                          H5P_DEFAULT,
                          H5P_DEFAULT)
    .toAttributeID

proc openAttribute(h5attr: H5Attributes, key: string): AttributeID =
  ## proc to open an attribute by its name.
  ## NOTE: This assumes the caller already checked the attribute exists!
  # we read by creation order, increasing from 0
  result = H5Aopen(h5attr.parent_id.to_hid_t, key.cstring, H5P_DEFAULT)
    .toAttributeID

proc getAttrName*[T: SomeInteger](attr_id: AttributeID, buf_space: T = 200): string =
  ## proc to get the attribute name of the attribute with the given id
  ## reserves space for the name to be written to
  withDebug:
    debugEcho "Call to getAttrName! with size $#" % $buf_space
  var name = newString(buf_space)
  # read the name
  let length = H5Aget_name(attr_id.id, len(name).csize_t, name.cstring)
  # H5Aget_name returns the length of the name. In case the name
  # is longer than the given buffer, we call this function again with
  # a buffer with the correct length
  if length <= name.len.csize_t:
    result = name.strip
    # now set the length of the resulting string to the size
    # it actually occupies
    result.setLen(length)
  else:
    result = getAttrName(attr_id, length)

proc setAttrAnyKind[T](attr: H5Attr, dtype: typedesc[T]) =
  ## proc which sets the AnyKind fields of a H5Attr
  when dtype is void:
    # use heuristics
    let npoints = getNumberOfPoints(attr.attr_dspace_id)
    if npoints > 1:
      attr.dtypeAnyKind = dkSequence
      # set the base type based on what's contained in the sequence
      attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
    else:
      attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)
  elif dtype is seq:
    attr.dtypeAnyKind = dkSequence
    attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
  else:
    attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)

proc getAttrDataspaceID(attr_id: Attribute_ID): DataspaceID =
  ## returns a valid dataspace for the given attribute
  result = H5Aget_space(attr_id.id).toDataspaceID()

proc getAttributeType(attr_id: AttributeID): DatatypeID =
  result = H5Aget_type(attr_id.id).toDatatypeID()

proc readAttributeInfo(h5attr: H5Attributes,
                       attr: H5Attr,
                       name: string) =
  withDebug:
    debugEcho "Found? ", attr.attr_id, " with name ", name
  # get dtypes and dataspace id
  attr.dtype_c = getAttributeType(attr.attr_id)

  # TODO: remove debug
  withDebug:
    debugEcho "attr ", name, " is vlen string ", H5Tis_variable_str(attr.dtype_c.id)
  #attr.dtype_c = H5Tget_native_type(attr.dtype_c, H5T_DIR_ASCEND)
  #echo "Encoding is native ", H5Tget_cset(attr.dtype_c)
  attr.attr_dspace_id = getAttrDataspaceID(attr.attr_id)
  # now set the attribute any kind fields (checks whether attr is a sequence)
  attr.setAttrAnyKind(void)
  # add to this attribute object
  h5attr.attr_tab[name] = attr

proc readAttributeInfo(h5attr: H5Attributes, key: string) =
  ## reads all information about the attribute `key` from the H5 file
  ## NOTE: this does ``not`` read the value of that attribute!
  var attr = newH5Attr()
  attr.attr_id = openAttribute(h5attr, key)
  attr.opened = true
  readAttributeInfo(h5attr, attr, key)

proc read_all_attributes*(h5attr: H5Attributes) =
  ## proc to read all attributes of the parent from file and store the names
  ## and attribute ids in `h5attr`.
  ## NOTE: If possible try to avoid using this proc! However, if you must, make
  ## sure to close all attributes after usage, otherwise memory leaks might happen.
  # first get how many objects there are
  h5attr.num_attrs = h5attr.getNumAttrs
  for i in 0 ..< h5attr.num_attrs:
    var attr = newH5Attr()
    attr.attr_id = openAttrByIdx(h5attr, i)
    attr.opened = true
    let name = getAttrName(attr.attr_id)
    readAttributeInfo(h5attr, attr, name)

proc existsAttribute*(parent: ParentID, name: string): bool =
  ## simply check if the given attribute name corresponds to an attribute
  ## of the given object
  ## throws:
  ##   HDF5LibraryError = in case a call to the H5 library fails
  let exists = H5Aexists(parent.to_hid_t, name)
  if exists > 0:
    result = true
  elif exists == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "HDF5 library called returned bad value in `existsAttribute` function")

template existsAttribute*[T: (H5File | H5Group | H5DataSet)](h5o: T, name: string): bool =
  ## proc to check whether a given
  ## simply check if the given attribute name corresponds to an attribute
  ## of the given object
  existsAttribute(h5o.getH5Id, name)

proc contains*(attr: H5Attributes, key: string): bool =
  ## proc to check whether a given attribute with name `key` exists in the attribute
  ## field of a group or dataset
  result = attr.parent_id.existsAttribute(key)

proc deleteAttribute*(h5id: ParentID, name: string): bool =
  ## deletes the given attribute `name` on the object defined by
  ## the H5 id `h5id`
  ## throws:
  ##   HDF5LibraryError = may be raised by the call to `existsAttribute`
  ##     if a call to the H5 library fails
  withDebug:
    debugEcho "Deleting attribute $# on id $#" % [name, $h5id]
  if existsAttribute(h5id, name) == true:
    let success = H5Adelete(h5id.to_hid_t, name)
    result = if success >= 0: true else: false
  else:
    result = true

proc deleteAttribute*[T: (H5File | H5Group | H5DataSet)](h5o: T, name: string): bool =
  result = deleteAttribute(getH5Id(h5o), name)
  # if successful also lower the number of attributes
  h5o.attrs.num_attrs = h5o.attrs.getNumAttrs

proc createAttribute*(pid: ParentID, name: string, dtype: DatatypeID,
                     dspace: DataspaceID): AttributeID =
  ## Creates an attribute `name` under `pid` with default properties.
  result = H5Acreate2(pid.to_hid_t, name.cstring, dtype.id,
                      dspace.id, H5P_DEFAULT, H5P_DEFAULT).toAttributeID

proc writeAttribute*(attr_id: AttributeID, dtype: DatatypeID, data: pointer) =
  ## Writes the given daat to the attribute.
  ##
  ## Note: This proc is inherently unsafe. The callee needs to make sure the
  ## data and dataspaces are prepared correctly.
  let err = H5Awrite(attr_id.id, dtype.id, data)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to HDF5 library failed while " &
      "calling `H5Awrite` in `writeAttribute`.")

import ./copyflat
from type_utils import needsCopy

proc prepareData[T](data: T, dtypeId: DatatypeID,
                    isVlen: static bool): auto =
  when T is tuple:
    when T.needsCopy() or isVlen:
      ## replace the string fields by `cstring` and put all data into a buffer
      result = copyFlat(@[data])
    else:
      result = data
  else:
    result = data

proc prepareData[T](data: openArray[T] | seq[T], dtypeId: DatatypeID,
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
    let size = H5Tget_size(dtypeId.id)
    result = newSeq[char](data.len * size.int)
    for i, el in data:
      # only copy as many bytes as either in input string to write or
      # as we have space in the allocated fixed length dataset
      let copyLen = min(size.int,  el.len)
      copyMem(result[i * size.int].addr, el[0].address, copyLen)
  elif T is seq|openArray and not isVlen:
    # just make sure the data is a flat `seq[T]`. If not, flatten to have
    # flat memory to write
    ## XXX: if nested data of a type that needs conversion not handled!
    result = seqmath.flatten(data)
  elif T.needsCopy() or isVlen:
    # convert data to HDF5 compatible data layout
    result = copyFlat(data)
  else:
    result = data

template writeData(buf: untyped): untyped {.dirty.} =
  ## Helper template to access correct start of memory
  when typeof(buf) is Buffer:
    writeAttribute(attr.attr_id,
                   dtypeId,
                   buf.data)
  elif typeof(buf) is ptr T:
    writeAttribute(attr.attr_id,
                   dtypeId,
                   buf)
  elif typeof(buf) is string or typeof(buf) is seq:
    if buf.len > 0:
      writeAttribute(attr.attr_id,
                     dtypeId,
                     address(buf[0]))
  else:
    writeAttribute(attr.attr_id,
                   dtypeId,
                   address(buf))

proc writeImpl[T](attr: H5Attr, dtypeId: DatatypeId, data: seq[T]) =
  ## Performs the `H5Awrite` operation to the given attribute for the given input data
  ## to be written.
  ##
  ## This proc is for `seq` data.
  when typeof(data) is ptr T:
    ## ptr T is just written as is. Caller responsible
    writeData(data)
  elif T is string:
    let buf = prepareData(data, dtypeId, isVlen = true) # (copy!)
    writeData(buf)
  else:
    if attr.isVlen():
      let buf = prepareData(data, dtypeId, isVlen = true) # (copy!)
      writeData(buf)
    else:
      let buf = prepareData(data, dtypeId, isVlen = false) # might copy if nested seq
      writeData(buf)

proc writeImpl[T: not seq](attr: H5Attr, dtypeId: DatatypeId, data: T) =
  ## Performs the `H5Awrite` operation to the given attribute for the given input data
  ## to be written.
  ##
  ## This proc is for non seq datatypes or raw `ptr` data.
  when T is ptr:
    ## ptr T is just written as is. Caller responsible
    writeData(data)
  elif T is string:
    # map strings to `cstring` to match H5 expectation
    if attr.isVlen():
      let buf = prepareData(data, dtypeId, isVlen = true)
      writeData(buf)
    else:
      # this case is for fixed size strings. Convert to a flat `seq[char]`
      let buf = prepareData(data, dtypeId, isVlen = false) # (copy!)
      writeData(buf)
  else: # scalar elements
    ## check if type needs to be copied
    when T.needsCopy(): # might still require copy (e.g. some tuple types)
      var buf = prepareData(data, dtypeId, isVlen = false)
    else:
      template buf: untyped = data # (no copy!)
    writeData(buf)

proc createAndWriteAttribute[T](parentId: ParentID, name: string, val: T): H5Attr =
  ## Helper which actually creates the given attribute `name` and writes `val`
  ##
  ## The new attribute is returned.
  result = new H5Attr
  var
    dtype: DatatypeID
    attr_dspace_id: DataspaceID

  when T is SomeNumber or T is char or T is bool or T is tuple:
    dtype = nimToH5type(T)
    # create dataspace for single element attribute
    attr_dspace_id = simple_dataspace(1)
  elif T is seq[string]:
    dtype = nimToH5type(string)
    attr_dspace_id = string_dataspace(val, dtype)
  elif T is string:
    # get copy of string type
    dtype = nimToH5type(type(val))
    # and reserve dataspace for string
    attr_dspace_id = string_dataspace(val, dtype)
  elif T is seq: # seq of elements, which can be memcopied.
    # take first element of sequence to get the datatype
    dtype = nimToH5type(type(val[0]))
    # create dataspace for attribute
    # 1D so call simple_dataspace with integer, instead of seq
    attr_dspace_id = simple_dataspace(len(val))
  else:
    {.error: "Unsupported type `" & $T & "` for attributes.".}
  # create the attribute
  let attribute_id = createAttribute(parent_id, name, dtype,
                                     attr_dspace_id)
  # write information to H5Attr tuple
  result.attr_id = attribute_id
  result.opened = true
  result.dtype_c = dtype
  result.attr_dspace_id = attr_dspace_id
  # set any kind fields (check whether is sequence)
  result.setAttrAnyKind(T)
  # perform actual writing!
  writeImpl(result, dtype, val)

proc write_attribute*[T](h5attr: H5Attributes, name: string, val: T, skip_check = false) =
  ## writes the attribute `name` of value `val` to the object `h5o`
  ## NOTE: by defalt this function overwrites an attribute, if an attribute
  ## of the same name already exists!
  ## need to
  ## - create simple dataspace
  ## - create attribute
  ## - write attribute
  ## - add attribute to h5attr
  ## - later close attribute when closing parent of h5attr
  var attr_exists = false
  # the first check is done, since we may be calling this function KNOWING that
  # the attribute does not exist. This should normally not be done by a user,
  # but only in case we have previously succesfully deleted the attribute
  if skip_check == false:
    attr_exists = name in h5attr
    withDebug:
      debugEcho "Attribute $# exists $#" % [name, $attr_exists]
  if not attr_exists:
    # create it in the file and write it
    let attr = createAndWriteAttribute(h5attr.parent_id, name, val)
    h5attr.attr_tab[name] = attr  # store in table of known attributes
    h5attr.attr_tab[name].close() # close again
  else:
    # if it does exist, we delete the attribute and call this function again, with
    # exists = true, i.e. without checking again whether element exists. Saves us
    # a call to the hdf5 library
    let success = deleteAttribute(h5attr.parent_id, name)
    if success == true:
      write_attribute(h5attr, name, val, true)
    else:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed on call in `deleteAttribute`")

  # independent of previous attribute, refresh the number of attributes
  h5attr.num_attrs = h5attr.getNumAttrs

proc `[]=`*[T](h5attr: H5Attributes, name: string, val: T) =
  ## convenience access to write_attribue
  h5attr.write_attribute(name, val)

proc readAttribute*(attr: H5Attr, dtypeId: DatatypeID, buf: pointer) =
  let err = H5Aread(attr.attr_id.id, dtypeId.id, buf)
  if err < 0:
    raise newException(HDF5LibraryError, "Call to `H5Aread` failed in `readAttribute`")

proc readAttribute*(attr: H5Attr, buf: pointer) =
  ## Reads the attribute data into `buf`. This assumes `buf` has allocated enough space!
  readAttribute(attr, attr.dtype_c, buf)

proc readStringArrayAttribute(attr: H5Attr, npoints: hssize_t): seq[string] =
  ## proc to read an array of strings attribute from a H5 file, for an existing
  ## `H5Attr`. This proc is only used in the `read_attribute` proc
  ## for users after checking of attribute is done.
  doAssert (attr.dtypeAnyKind == dkSequence and attr.dtypeBaseKind == dkString) or
    (attr.dtypeAnyKind == dkString and npoints == 1.hssize_t),
     "`readStringArrayAttribute` called for a non string attribute. Attribute " &
     "is kind " & $attr.dtypeAnyKind & "!"
  # create a void pointer equivalent
  let nativeType = copyType(H5T_C_S1)
  discard H5Tset_size(nativeType.id, H5T_VARIABLE)
  var buf = newSeq[cstring](npoints.int)
  readAttribute(attr, nativeType, buf[0].addr)
  # cast the void pointer to a ptr on a ptr of an unchecked array
  # and dereference it to get a ptr to an unchecked char array
  result = newSeq[string](npoints)
  for i, s in buf:
    result[i] = $s

proc readStringAttribute(attr: H5Attr): string =
  ## proc to read a string attribute from a H5 file, for an existing
  ## `H5Attr`. This proc is only used in the `read_attribute` proc
  ## for users after checking of attribute is done.
  doAssert attr.dtypeAnyKind == dkString, "`readStringAttribute` called for a non " &
    "string attribute. Attribute is kind " & $attr.dtypeAnyKind & "!"
  # in case of string, need to determine size. use:
  # in case of existence, read the data and return
  if isVariableString(attr.dtype_c):
    let nativeType = copyType(H5T_C_S1)
    discard H5Tset_size(nativeType.id, H5T_VARIABLE)
    var buf: cstring
    readAttribute(attr, nativeType, buf.addr)
    result = $buf
  else:
    let nativeType = getNativeType(attr.dtype_c)
    let string_len = H5Aget_storage_size(attr.attr_id.id)
    var buf_string = newString(string_len)
    readAttribute(attr, nativeType, addr buf_string[0])
    result = buf_string

proc readImpl[T](attr: H5Attr, buffer: var T) =
  let dtypeId = attr.dtype_c
  let dspaceId = attr.attr_dspace_id
  template readData(buf: untyped): untyped {.dirty.} =
    when typeof(buf) is Buffer:
      readAttribute(attr,
                    dtypeId,
                    buf.data)
    elif T is seq:
      readAttribute(attr,
                    dtypeId,
                    addr(buf[0]))
    else:
      readAttribute(attr,
                    dtypeId,
                    addr buf)

  template reclaim(buf: untyped): untyped =
    ## IMPORTANT: We must assign a `DatatypeID` instead of a raw `hid_t`, because `dataspaceID`
    ## is a `proc`. If we were to write `else: attr.dataspaceId.id` the returned value would
    ## be `=destroy`-ed before the `H5Dvlen_reclaim` call again!
    let err = H5Dvlen_reclaim(attr.dtype_c.id, dspaceId.id, H5P_DEFAULT, buf.data)
    if err != 0:
      raise newException(HDF5LibraryError, "HDF5 library failed to reclaim variable length memory.")
  when T is seq:
    type TT = typeof(buffer[0])
    when TT is string:
      buffer = readStringArrayAttribute(attr, buffer.len)
    elif TT.needsCopy:
      # allocate a `Buffer` for HDF5 data
      let actBuf = newBuffer(buffer.len * calcSize(T))
      readData(actBuf)
      # convert back to Nim types
      buffer = fromFlat[TT](actBuf)
      reclaim(actBuf)
    else:
      readData(buffer)
  elif T is string:
    buffer = readStringAttribute(attr)
  elif T.needsCopy:
    # allocate a `Buffer` for HDF5 data
    let actBuf = newBuffer(calcSize(T))
    readData(actBuf)
    # convert back to Nim types
    buffer = fromFlat[T](actBuf)[0]
    reclaim(actBuf)
  else:
    readData(buffer)

proc readAttribute*[T](attr: H5Attr, dtype: typedesc[T]): T =
  ## Performs the actual reading of the `H5Attr`
  when T is seq:
    # determine number of elements in seq
    let npoints = getNumberOfPoints(attr.attr_dspace_id)
    type TT = type(result[0])
    # in case it's a string, do things differently..
    result.setLen(npoints)
    readImpl(attr, result)
  else: # no allocation needed, just call `readImpl`
    readImpl(attr, result)

proc read_attribute*[T](h5attr: H5Attributes, name: string, dtype: typedesc[T]): T =
  ## now implement reading of attributes
  ## finally still need a read_all attribute. This function only reads a single one, if
  ## it exists.
  ## check existence, since we read all attributes upon creation of H5Attributes object
  ## (attr as small, so the performance overhead should be minimal), we can just access
  ## the attribute table to check for existence
  ## inputs:
  ##   h5attr: H5Attributes = H5Attributes from which to read specific attribute
  ##   name: string = name of the attribute to be read
  ##   dtype: typedesc[T] = datatype of the attribute to be read. Needed to define return
  ##     value.
  ## throws:
  ##   KeyError: In case the key does not exist as an attribute
  # TODO: check err values!
  let attr_exists = name in h5attr
  var err: herr_t
  if attr_exists:
    # in case of existence, read the data and return
    h5attr.readAttributeInfo(name)
    let attr = h5attr.attr_tab[name]
    result = attr.readAttribute(dtype)
    # close attribute again after reading
    h5attr.attr_tab[name].close()
  else:
    raise newException(KeyError, "No attribute `$#` exists in object `$#`" % [name, h5attr.parent_name])

proc `[]`*[T](h5attr: H5Attributes, name: string, dtype: typedesc[T]): T =
  # convenience access to read_attribute
  h5attr.read_attribute(name, dtype)

proc `[]`*(h5attr: H5Attributes, name: string): DtypeKind =
  # accessing H5Attributes by string simply returns the datatype of the stored
  # attribute as an AnyKind value
  h5attr.attr_tab[name].dtypeAnyKind

proc `[]`*[T](attr: H5Attr, dtype: typedesc[T]): T =
  # convenience access to readAttribute for the actual attribute
  attr.readAttribute(dtype)
