#[
This file contains the procedures related to attributes. 

The attribute types are defined in the datatypes.nim file.
]#


import typeinfo
import tables
import strutils

import hdf5_wrapper
import H5nimtypes
import datatypes
import dataspaces
import util

# forward declare procs, which we need to read the attributes from file
proc read_all_attributes*(h5attr: var H5Attributes)
  
proc newH5Attributes*(): H5Attributes =
  let attr = initTable[string, H5Attr]()  
  result = H5Attributes(attr_tab: attr,
                        num_attrs: -1,
                        parent_name: "",
                        parent_id: -1,
                        parent_type: "")

proc initH5Attributes*(p_name: string = "", p_id: hid_t = -1, p_type: string = ""): H5Attributes =
  let attr = initTable[string, H5Attr]()
  var h5attr = H5Attributes(attr_tab: attr,
                            num_attrs: -1,
                            parent_name: p_name,
                            parent_id: p_id,
                            parent_type: p_type)
  read_all_attributes(h5attr)
  result = h5attr

    

proc openAttrByIdx(h5attr: var H5Attributes, idx: int): hid_t =
  # proc to open an attribute by its id in the H5 file and returns
  # attribute id if succesful
  # need to hand H5Aopen_by_idx the location relative to the location_id,
  # if I understand correctly
  let loc = "."
  # we read by creation order, increasing from 0
  result = H5Aopen_by_idx(h5attr.parent_id,
                          loc,
                          H5_INDEX_CRT_ORDER,
                          H5_ITER_INC,
                          hsize_t(idx),
                          H5P_DEFAULT,
                          H5P_DEFAULT)

proc getAttrName(attr_id: hid_t, buf_space = 20): string =
  # proc to get the attribute name of the attribute with the given id
  # reserves space for the name to be written to
  withDebug:
    echo "Call to getAttrName! with size $#" % $buf_space
  var name = newString(buf_space)
  # read the name
  let length = attr_id.H5Aget_name(len(name), name)
  # H5Aget_name returns the length of the name. In case the name
  # is longer than the given buffer, we call this function again with
  # a buffer with the correct length
  if length <= name.len:
    result = name.strip
    # now set the length of the resulting string to the size
    # it actually occupies
    result.setLen(length)
  else:
    result = getAttrName(attr_id, length)

proc getNumAttrs(h5attr: var H5Attributes): int =
  # proc to get the number of attributes of the parent
  # uses H5Oget_info, which returns a struct containing the
  # metadata of the object (incl type etc.). Might be useful
  # at other places too?
  # reserve space for the info object
  var h5info: H5O_info_t
  let err = H5Oget_info(h5attr.parent_id, addr(h5info))
  if err >= 0:
    # successful
    withDebug:
      echo "getNumAttrs(): ", h5attr
    var status: hid_t
    var loc = cstring(".")
    result = int(h5info.num_attrs)
  else:
    withDebug:
      echo "getNumAttrs(): ", h5attr
    raise newException(HDF5LibraryError, "Call to HDF5 library failed in `getNumAttr` when reading $#" % $h5attr.parent_name)

proc setAttrAnyKind(attr: var H5Attr) =
  # proc which sets the AnyKind fields of a H5Attr
  let npoints = H5Sget_simple_extent_npoints(attr.attr_dspace_id)
  if npoints > 1:
    attr.dtypeAnyKind = akSequence
    # set the base type based on what's contained in the sequence
    attr.dtypeBaseKind = h5ToNimType(attr.dtype_c)
  else:
    attr.dtypeAnyKind = h5ToNimType(attr.dtype_c)

proc read_all_attributes*(h5attr: var H5Attributes) =
  # proc to read all attributes of the parent from file and store the names
  # and attribute ids in `h5attr`

  # first get how many objects there are
  h5attr.num_attrs = h5attr.getNumAttrs
  for i in 0..<h5attr.num_attrs:
    var attr: H5Attr
    let idx = hsize_t(i)
    attr.attr_id = openAttrByIdx(h5attr, i)
    let name = getAttrName(attr.attr_id)
    withDebug:
      echo "Found? ", attr.attr_id, " with name ", name
    # get dtypes and dataspace id
    attr.dtype_c = H5Aget_type(attr.attr_id)
    attr.attr_dspace_id = H5Aget_space(attr.attr_id)
    # now set the attribute any kind fields (checks whether attr is a sequence)
    setAttrAnyKind(attr)
    # add to this attribute object
    h5attr.attr_tab[name] = attr

proc existsAttribute*(h5id: hid_t, name: string): bool =
  # proc to check whether a given
  # simply check if the given attribute name corresponds to an attribute
  # of the given object
  # throws:
  #    
  let exists = H5Aexists(h5id, name)
  if exists > 0:
    result = true
  elif exists == 0:
    result = false
  else:
    raise newException(HDF5LibraryError, "HDF5 library called returned bad value in `existsAttribute` function")

template existsAttribute*[T: (H5FileObj | H5Group | H5DataSet)](h5o: T, name: string): bool =
  # proc to check whether a given
  # simply check if the given attribute name corresponds to an attribute
  # of the given object
  existsAttribute(h5o.getH5Id, name)

proc deleteAttribute*(h5id: hid_t, name: string): bool =
  withDebug:
    echo "Deleting attribute $# on id $#" % [name, $h5id]
  let success = H5Adelete(h5id, name)
  result = if success >= 0: true else: false

template deleteAttribute*[T: (H5FileObj | H5Group | H5DataSet)](h5o: T, name: string): bool =  
  deleteAttribute(h5o.getH5Id, name)
    
proc write_attribute*[T](h5attr: var H5Attributes, name: string, val: T, skip_check = false) =
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
    attr_exists = existsAttribute(h5attr.parent_id, name)
    withDebug:
      echo "Attribute $# exists $#" % [name, $attr_exists]
  if attr_exists == false:
    # create a H5Attr, which we add to the table attr_tab of the given
    # h5attr object once we wrote it to file
    var attr: H5Attr
    
    when T is SomeNumber or T is char:
      let
        dtype = nimToH5type(T)
        # create dataspace for single element attribute
        attr_dspace_id = simple_dataspace(1)
        # create the attribute
        attribute_id = H5Acreate2(h5attr.parent_id, name, dtype, attr_dspace_id, H5P_DEFAULT, H5P_DEFAULT)
        # mutable copy for address
      var mval = val
      # write the value
      discard H5Awrite(attribute_id, dtype, addr(mval))

      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      setAttrAnyKind(attr)
      
    elif T is seq or T is string:
      # NOTE:
      # in principle we need to differentiate between simple sequences and nested
      # sequences. However, for now only support normal seqs.
      # extension to nested seqs should be easy (using shape, handed simple_dataspace),
      # however we still need to have a good function to get the basetype of a nested
      # sequence for that
      when T is seq:
        # take first element of sequence to get the datatype
        let dtype = nimToH5type(type(val[0]))
        # create dataspace for attribute
        # 1D so call simple_dataspace with integer, instead of seq
        let attr_dspace_id = simple_dataspace(len(val))
      else:
        let
          # get copy of string type
          dtype = nimToH5type(type(val))
          # and reserve dataspace for string
          attr_dspace_id = string_dataspace(val, dtype)
      # create the attribute
      let attribute_id = H5Acreate2(h5attr.parent_id, name, dtype, attr_dspace_id, H5P_DEFAULT, H5P_DEFAULT)
      # mutable copy for address
      var mval = val
      # write the value
      discard H5Awrite(attribute_id, dtype, addr(mval[0]))

      # write information to H5Attr tuple
      attr.attr_id = attribute_id
      attr.dtype_c = dtype
      attr.attr_dspace_id = attr_dspace_id
      # set any kind fields (check whether is sequence)
      setAttrAnyKind(attr)
    elif T is bool:
      # NOTE: in order to support booleans, we need to use HDF5 enums, since HDF5 does not support
      # a native boolean type. H5 enums not supported yet though...
      echo "Type `bool` currently not supported as attribute"
      discard
    else:
      echo "Type `$#` currently not supported as attribute" % $T.name
      discard

    # add H5Attr tuple to H5Attributes table
    h5attr.attr_tab[name] = attr
  else:
    # if it does exist, we delete the attribute and call this function again, with
    # exists = true, i.e. without checking again whether element exists. Saves us
    # a call to the hdf5 library
    let success = deleteAttribute(h5attr.parent_id, name)
    if success == true:
      write_attribute(h5attr, name, val, true)
    else:
      raise newException(HDF5LibraryError, "Call to HDF5 library failed on call in `deleteAttribute`")

template `[]=`*[T](h5attr: var H5Attributes, name: string, val: T) =
  # convenience access to write_attribue
  h5attr.write_attribute(name, val)

proc read_attribute*[T](h5attr: var H5Attributes, name: string, dtype: typedesc[T]): T =
  # now implement reading of attributes
  # finally still need a read_all attribute. This function only reads a single one, if
  # it exists.
  # check existence, since we read all attributes upon creation of H5Attributes object
  # (attr as small, so the performance overhead should be minimal), we can just access
  # the attribute table to check for existence

  # TODO: check err values!
  
  let attr_exists = hasKey(h5attr.attr_tab, name)
  var err: herr_t
  if attr_exists:
    # in case of existence, read the data and return
    let attr = h5attr.attr_tab[name]
    when T is SomeNumber or T is char:
      var at_val: T
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(at_val))
      result = at_val
    elif T is seq:
      # determine number of elements in seq
      let npoints = H5Sget_simple_extent_npoints(attr.attr_dspace_id)
      # return correct type based on base kind
      var buf_seq: T = @[]
      buf_seq.setLen(npoints)
      # read data
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(buf_seq[0]))
      result = buf_seq
    elif T is string:
      # in case of string, need to determine size. use:
      let string_len = H5Aget_storage_size(attr.attr_id)
      var buf_string = newString(string_len)
      # read data
      err = H5Aread(attr.attr_id, attr.dtype_c, addr(buf_string[0]))
      result = buf_string
  else:
    raise newException(KeyError, "No key `$#` exists in group `$#`" % [name, h5attr.parent_name])

template `[]`*[T](h5attr: var H5Attributes, name: string, dtype: typedesc[T]): T =
  # convenience access to read_attribute
  h5attr.read_attribute(name, dtype)

template `[]`*(h5attr: H5Attributes, name: string): AnyKind =
  # accessing H5Attributes by string simply returns the datatype of the stored
  # attribute as an AnyKind value
  h5attr.attr_tab[name].dtypeAnyKind
