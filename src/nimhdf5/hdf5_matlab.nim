import std/[tables, strutils, json, sequtils]
import nimhdf5, nimhdf5/hdf5_wrapper

type
  MatlabInterface* = object
    h5f*: H5File
    data*: Table[string, H5Dataset]

proc getFieldName(s: string): string =
  doAssert s.startsWith("/")
  result = s
  result.removePrefix("/")

proc deserializeMatlab*(f: string): MatlabInterface =
  result = MatlabInterface(h5f: H5open(f, "r"),
                           data: initTable[string, H5DataSet]())
  var root = result.h5f["/".grp_str]
  for d in items(root, depth = 1):
    echo d.name
    let matlabField = getFieldName(d.name)
    # get the content of the dataset as identifiers
    result.data[matlabField] = d

proc `[]`*(m: MatlabInterface, s: string): H5Dataset =
  ## `[]` yields the dataset that contains the HDF5 references for the given key. The key
  ## corresponds to each field of of the Matlab struct.
  result = m.data[s]

iterator keys*(m: MatlabInterface): string =
  ## Yields all keys of the MatlabInterface, i.e. the fields of the `struct` contained in the file.
  for k in keys(m.data):
    yield k

proc readJson*(m: MatlabInterface, s: string): JsonNode =
  # Dataset is likely, but not necessarily, a dataset of references
  let d = m[s]
  case d.dtypeAnyKind
  of dkRef: # dtype logic
    # read the references, then readimpl those
    result = newJArray()
    for r in m.h5f.references(d):
      case r.kind
      of rkGroup:   result.add readJson(r.g)
      of rkDataset: result.add readJson(r.d)
  else: # native
    result = readJson(d)
