import std / [strutils, strformat, tables]
import datatypes, H5nimtypes, attribute_util, json

proc pretty*(att: H5Attr, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}opened: {att.opened},\n"
  result.add &"{fieldInd}dtypeAnyKind: {att.dtypeAnyKind}"
  if full:
    result.add &",\n{fieldInd}attr_id: {att.attr_id.hid_t},\n"
    result.add &"{fieldInd}dtype_c: {att.dtype_c.hid_t},\n"
    result.add &"{fieldInd}dtypeBaseKind: {att.dtypeBaseKind},\n"
    result.add &"{fieldInd}attr_dspace_id: {att.attr_dspace_id.hid_t}"
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
    result.add &",\n{fieldInd}parent_id: {attrs.parent_id.kind}, {attrs.parent_id.to_hid_t}"
  if attrs.num_attrs > 0:
    result.add &"{fieldInd}attributes: " & "{"
  for name, attr in attrs.attrsJson:
    result.add &"{fieldInd}{name}: {attr},\n"
  if attrs.num_attrs > 0:
    result.add &"{fieldInd}" & "}"
  result.add repeat(' ', indent) & "}\n"

proc `$`*(attrs: H5Attributes): string =
  ## to string conversion for a `H5Attributes` for pretty printing
  result = pretty(attrs, full = false)

proc pretty*(dset: H5DataSet, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {dset.name},\n"
  result.add &"{fieldInd}opened: {dset.opened},\n"
  result.add &"{fieldInd}file: {dset.file},\n"
  result.add &"{fieldInd}parent: {dset.parent},\n"
  result.add &"{fieldInd}shape: {dset.shape},\n"
  result.add &"{fieldInd}dtype: {dset.dtype}"
  if full:
    result.add &",\n{fieldInd}maxshape: {dset.maxshape},\n"
    result.add &"{fieldInd}parent_id: {dset.parent_id.kind}, {dset.parent_id.to_hid_t}\n"
    result.add &"{fieldInd}chunksize: {dset.chunksize},\n"
    result.add &"{fieldInd}dtypeAnyKind: {dset.dtypeAnyKind},\n"
    result.add &"{fieldInd}dtypeBaseKind: {dset.dtypeBaseKind},\n"
    result.add &"{fieldInd}dtype_c: {dset.dtype_c.hid_t},\n"
    result.add &"{fieldInd}dtype_class: {dset.dtype_class},\n"
    result.add &"{fieldInd}dataset_id: {dset.dataset_id.hid_t},\n"
    result.add &"{fieldInd}num_attrs: {dset.attrs.num_attrs},\n"
    result.add &"{fieldInd}dapl_id: {dset.dapl_id.hid_t},\n"
    result.add &"{fieldInd}dcpl_id: {dset.dcpl_id.hid_t}"
  result.add &"\n" & repeat(' ', indent) & "}"

proc `$`*(dset: H5DataSet): string =
  ## to string conversion for a `H5DataSet` for pretty printing
  result = pretty(dset, full = false)

proc pretty*(grp: H5Group, indent = 2, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  let fieldIndTwo = repeat(' ', indent + 4)
  result.add &"{fieldInd}name: {grp.name},\n"
  result.add &"{fieldInd}opened: {grp.opened},\n"
  result.add &"{fieldInd}file: {grp.file},\n"
  result.add &"{fieldInd}parent: {grp.parent}"
  if full:
    result.add &",\n{fieldInd}file_id: {grp.file_id.hid_t},\n"
    result.add &"{fieldInd}group_id: {grp.group_id.hid_t},\n"
    result.add &"{fieldInd}parent_id: {grp.parent_id.kind}, {grp.parent_id.to_hid_t},\n"
    result.add &"{fieldInd}gapl_id: {grp.gapl_id.hid_t},\n"
    result.add &"{fieldInd}gcpl_id: {grp.gcpl_id.hid_t}"
  # datasets

  if grp.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{\n"
    for name, dset in grp.datasets:
      result.add &"{fieldInd}{name}:\n" & dset.pretty(indent = indent + 4) & ",\n"
    result.add &"{fieldInd}" & "}"
  else:
    result.add &",\n{fieldInd}datasets: " & "{:}\n"
  if grp.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{\n"
    for name, subGrp in grp.groups:
      result.add &"{fieldIndTwo}{name},\n"
    result.add fieldInd & "}"
  else:
    result.add &",\n{fieldInd}groups: " & "{:}\n"
  result.add &"\n" & repeat(' ', indent) & "}"

proc `$`*(grp: H5Group): string =
  ## to string conversion for a `H5Group` for pretty printing
  result = pretty(grp, full = false)

proc pretty*(h5f: H5File, indent = 2, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {h5f.name},\n"
  result.add &"{fieldInd}rw_type: {h5f.rw_type},\n"
  result.add &"{fieldInd}visited: {h5f.visited}"
  if full:
    result.add &",\n{fieldInd}nfile_id: {h5f.file_id.hid_t},\n"
    result.add &"{fieldInd}err: {h5f.err},\n"
    result.add &"{fieldInd}status: {h5f.status}"
  if h5f.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{\n"
    for name, dset in h5f.datasets:
      result.add &"{fieldInd}{name}:\n" & dset.pretty(indent = indent + 4) & ",\n"
    result.add &"{fieldInd}" & "}"
  else:
    result.add &",\n{fieldInd}datasets: " & "{:}\n"
  if h5f.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{\n"
    for name, subGrp in h5f.groups:
      result.add &"{fieldInd}{name}:\n" & subGrp.pretty(indent = indent + 4)
    result.add fieldInd & "}"
  else:
    result.add &",\n{fieldInd}groups: " & "{:}\n"
  result.add &",\n{fieldInd}attrs:\n {h5f.attrs}"
  result.add &"\n" & repeat(' ', indent) & "}\n"

proc `$`*(h5f: H5File): string =
  ## to string conversion for a `H5File` for pretty printing
  result = pretty(h5f, full = false)
