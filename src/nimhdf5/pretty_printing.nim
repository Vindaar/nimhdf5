import std / [strutils, strformat, tables]
import datatypes, H5nimtypes, attribute_util, json, util

proc pretty*(att: H5Attr, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}opened: {att.opened},\n"
  result.add &"{fieldInd}dtypeAnyKind: {att.dtypeAnyKind}"
  if full:
    result.add &",\n{fieldInd}attr_id: {att.attr_id.id},\n"
    result.add &"{fieldInd}dtype_c: {att.dtype_c.id},\n"
    result.add &"{fieldInd}dtypeBaseKind: {att.dtypeBaseKind},\n"
    result.add &"{fieldInd}attr_dspace_id: {att.attr_dspace_id.id}"
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
  result.add "\n" & repeat(' ', indent) & "}"

proc `$`*(attrs: H5Attributes): string =
  ## to string conversion for a `H5Attributes` for pretty printing
  result = pretty(attrs, full = false)

proc pretty*(dset: H5DataSet, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  result.add &"{fieldInd}name: {dset.name}"
  result.add &",\n{fieldInd}opened: {dset.opened}"
  if full or dset.file.len > 0:
    result.add &",\n{fieldInd}file: {dset.file}"
  if full or dset.parent.len > 0:
    result.add &",\n{fieldInd}parent: {dset.parent}"
  result.add &",\n{fieldInd}shape: {dset.shape}"
  if full or dset.dtype.len > 0:
    result.add &",\n{fieldInd}dtype: {dset.dtype}"
  if full:
    result.add &",\n{fieldInd}maxshape: {dset.maxshape},\n"
    result.add &"{fieldInd}parent_id: {dset.parent_id.kind}, {dset.parent_id.to_hid_t}\n"
    result.add &"{fieldInd}chunksize: {dset.chunksize},\n"
    result.add &"{fieldInd}dtypeAnyKind: {dset.dtypeAnyKind},\n"
    result.add &"{fieldInd}dtypeBaseKind: {dset.dtypeBaseKind},\n"
    result.add &"{fieldInd}dtype_c: {dset.dtype_c.id},\n"
    result.add &"{fieldInd}dtype_class: {dset.dtype_class},\n"
    result.add &"{fieldInd}dataset_id: {dset.dataset_id.id},\n"
    result.add &"{fieldInd}num_attrs: {dset.attrs.num_attrs},\n"
    result.add &"{fieldInd}dapl_id: {dset.dapl_id.id},\n"
    result.add &"{fieldInd}dcpl_id: {dset.dcpl_id.id}"
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
    result.add &",\n{fieldInd}file_id: {grp.file_id.id},\n"
    result.add &"{fieldInd}group_id: {grp.group_id.id},\n"
    result.add &"{fieldInd}parent_id: {grp.parent_id.kind}, {grp.parent_id.to_hid_t},\n"
    result.add &"{fieldInd}gapl_id: {grp.gapl_id.id},\n"
    result.add &"{fieldInd}gcpl_id: {grp.gcpl_id.id}"
  # datasets

  if grp.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{\n"
    for name, dset in grp.datasets:
      result.add &"{fieldInd}{name}:\n" & dset.pretty(indent = indent + 4) & ",\n"
    result.add &"{fieldInd}" & "}"
  else:
    result.add &",\n{fieldInd}datasets: " & "{:}"
  if grp.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{"
    for name, subGrp in grp.groups:
      result.add &"\n{fieldIndTwo}{name},"
    result.add fieldInd & "\n}"
  else:
    result.add &",\n{fieldInd}groups: " & "{:}"
  result.add &"\n" & repeat(' ', indent) & "}"

proc `$`*(grp: H5Group): string =
  ## to string conversion for a `H5Group` for pretty printing
  result = pretty(grp, full = false)

proc `$`*[T: AccessKind | ObjectKind](s: set[T]): string =
  result = "{"
  var idx = 0
  for el in iterateEnumSet(s):
    if idx < s.card-1:
      result.add $el & ", "
    else:
      result.add $el
    idx += 1
  result.add "}"

proc pretty*(h5f: H5File, indent = 0, full = false): string =
  result = repeat(' ', indent) & "{\n"
  let fieldInd = repeat(' ', indent + 2)
  let fieldIndTwo = repeat(' ', indent + 4)
  result.add &"{fieldInd}name: {h5f.name},\n"
  result.add &"{fieldInd}accessFlags: {h5f.accessFlags},\n"
  result.add &"{fieldInd}visited: {h5f.visited}"
  if full:
    result.add &",\n{fieldInd}nfile_id: {h5f.file_id.id},\n"
    result.add &"{fieldInd}err: {h5f.err},\n"
    result.add &"{fieldInd}status: {h5f.status}"
  if h5f.datasets.len > 0:
    result.add &",\n{fieldInd}datasets: " & "{\n"
    for name, dset in h5f.datasets:
      result.add &"{fieldIndTwo}{name}:\n" & dset.pretty(indent = indent + 4) & ",\n"
    result.add &"{fieldInd}" & "}"
  else:
    result.add &",\n{fieldInd}datasets: " & "{:}"
  if h5f.groups.len > 0:
    result.add &",\n{fieldInd}groups: " & "{"
    for name, subGrp in h5f.groups:
      result.add &"\n{fieldIndTwo}{name}:\n" & subGrp.pretty(indent = indent + 4) & ","
    result.add &"\n{fieldInd}" & "}"
  else:
    result.add &",\n{fieldInd}groups: " & "{:}"
  result.add &",\n{fieldInd}attrs:\n{h5f.attrs}"
  result.add &"\n" & repeat(' ', indent) & "}"

proc `$`*(h5f: H5File): string =
  ## to string conversion for a `H5File` for pretty printing
  result = pretty(h5f, full = false)
