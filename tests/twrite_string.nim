import nimhdf5
from std/sequtils import mapIt, filterIt
from std/os import removeFile


let File = "string_data.h5"
let Data = @["hello", "world", "foo"]
let DataAr = @[['h', 'e', 'l', 'l', 'o'], ['w', 'o', 'r', 'l', 'd'], ['f', 'o', 'o', '\0', '\0']]

proc writeFixed(h5f: H5File) =
  ## If you want to write a *fixed length string*, do it by creating a dataset
  ## of fixed length arrays. Writing the data is handled correctly if you just
  ## give a `seq[string]` (but may truncate if your input contains more than N
  ## elements!)
  let dset = h5f.create_dataset("fixed_strings", 3, array[5, char])
  dset[dset.all] = Data

proc readFixed(h5f: H5File) =
  let data = h5f["fixed_strings", array[5, char]]
  doAssert data == DataAr

  # alternative try to read as cstring
  let dataC = h5f["fixed_strings", cstring]
  doAssert dataC == Data.mapIt(it.cstring)

  # alternative try to read as string
  let dataS = h5f["fixed_strings", string]
  doAssert dataS == Data

proc writeVlenString(h5f: H5File) =
  ## More generally if you wish to write variable length strings, just create a
  ## string dataset.
  let dset = h5f.create_dataset("vlen_strings", 3, string)
  dset[dset.all] = Data

proc readVlenString(h5f: H5File) =
  let data = h5f["vlen_strings", string]
  doAssert data == Data
  # alternatively as `cstring`
  let dataC = h5f["vlen_strings", cstring]
  doAssert dataC == Data.mapIt(it.cstring)

proc writeAsVlen(h5f: H5File) =
  ## NOTE: writing a string as such will make it appear as pure `uint8` VLEN data in the file. Not
  ## recommended!
  let dset = h5f.create_dataset("strings_as_vlen", 3, special_type(char))
  dset[dset.all] = Data

  when compiles((discard h5f.create_dataset("strings_as_vlen_string", 3, special_type(string)))):
    doAssert false, "Call to `special_type(string)` does not fail! This is a regression."
  else:
    discard

proc readAsVlen(h5f: H5File) =
  let data = h5f["strings_as_vlen", special_type(char), char]
  doAssert data == DataAr.mapIt((@it).filterIt(it != '\0'))


when isMainModule:
  var h5f = H5open(File, "w")

  writeFixed(h5f)
  writeVlenString(h5f)
  writeAsVlen(h5f)

  doAssert h5f.close() >= 0

  h5f = H5open(File, "r")

  h5f.readFixed()
  h5f.readVlenString()
  h5f.readAsVlen()

  doAssert h5f.close() >= 0

  removeFile(File)
