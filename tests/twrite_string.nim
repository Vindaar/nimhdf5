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
  ## NOTE: We cannot read into a `cstring` directly!
  let data = h5f["fixed_strings", array[5, char]]
  doAssert data == DataAr

  # read manually using `ptr T` interface
  var cbuf = cstring(newString(15))
  block:
    let dset = h5f["fixed_strings".dset_str]
    dset.read(cbuf[0].addr)
    doAssert cbuf == cstring("helloworldfoo\0\0")
  block:
    h5f.read("fixed_strings", cbuf[0].addr)
    doAssert cbuf == cstring("helloworldfoo\0\0")

  # alternative try to read as string
  let dataS = h5f["fixed_strings", string]
  doAssert dataS == Data

proc writeVlenString(h5f: H5File) =
  ## More generally if you wish to write variable length strings, just create a
  ## string dataset.
  let dset = h5f.create_dataset("vlen_strings", 3, string)
  dset[dset.all] = Data

proc readVlenString(h5f: H5File) =
  ## NOTE: We cannot read into a `cstring` directly!
  let data = h5f["vlen_strings", string]
  doAssert data == Data


## NOTE: This "feature" is not supported anymore. I will keep this test around to think about
## it again in the future (i.e. whether this should work after all in the way that this test
## shows or if it's fine to not support at all. A `string` is *not* a `seq[char]` after all!)
#proc writeAsVlen(h5f: H5File) =
#  ## NOTE: writing a string as such will make it appear as pure `uint8` VLEN data in the file. Not
#  ## recommended!
#  let dset = h5f.create_dataset("strings_as_vlen", 3, special_type(char))
#  dset[dset.all] = Data
#
#  when compiles((discard h5f.create_dataset("strings_as_vlen_string", 3, special_type(string)))):
#    doAssert false, "Call to `special_type(string)` does not fail! This is a regression."
#  else:
#    discard

proc readAsVlen(h5f: H5File) =
  let data = h5f["strings_as_vlen", special_type(char), char]
  doAssert data == DataAr.mapIt((@it).filterIt(it != '\0'))


when isMainModule:
  var h5f = H5open(File, "w")

  writeFixed(h5f)
  writeVlenString(h5f)
  #writeAsVlen(h5f)

  doAssert h5f.close() >= 0

  h5f = H5open(File, "r")

  h5f.readFixed()
  h5f.readVlenString()
  #h5f.readAsVlen()

  doAssert h5f.close() >= 0

  removeFile(File)
