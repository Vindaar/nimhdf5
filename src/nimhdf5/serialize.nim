#[
This file contains helpers to serialize objects to a H5 file.

]#

from std / typetraits import distinctBase
from os import `/`
import ./datatypes, ./datasets, ./files, ./groups, ./util


proc toH5*[T: distinct](h5f: H5File, x: T, name = "", path = "/") =
  ## A single number is stored as an attribute with `name` under `path`.
  ## An additional attribute is created that stores the name of the original type.
  let xD = distinctBase(T)(x)
  h5f.toH5(xD, name, path)
  let obj = h5f[path.grp_str]
  obj.attrs["typeof(" & name & ")"] = $T

proc toH5*[T: SomeNumber](h5f: H5File, x: T, name = "", path = "/") =
  ## A single number is stored as an attribute with `name` under `path`
  let obj = h5f[path.grp_str]
  obj.attrs[name] = x

proc toH5*[T: char | string | cstring](h5f: H5File, x: T, name = "", path = "/") =
  ## A single character is stored as an attribute with `name` under `path`
  let obj = h5f[path.grp_str]
  obj.attrs[name] = x

proc toH5*[T: enum](h5f: H5File, x: T, name = "", path = "/") =
  ## An enum is stored as an attribute with `name` under `path` where the
  ## value is written as the *string value* of that attribute.
  let obj = h5f[path.grp_str]
  obj.attrs[name] = $x

template innerTyp(x: typed): untyped =
  ## Argument should be a `seq`, but at least iterable via `[]`
  typeof(x[0])

proc toH5*[T: seq](h5f: H5File, x: T, name = "", path = "/") =
  ## A sequence is stored as a 1D dataset if it is a flat sequence, else we
  ## raise an exception.
  ##
  ## For sequences of tuples the same remark as for raw tuples hold: they should
  ## be flat types. Otherwise runtime or compile time errors may occur.
  ##
  ## XXX: We could check manually if the sequence can be flattened (all sub elements
  ## same length) or just default to assume it is not flat and store as variable length.
  ## But what to do for 3D, 4D etc?
  # first check for tuple, as in this case
  when innerTyp(x) is SomeNumber | char | string | cstring:
    let dset = h5f.create_dataset(path / name,
                                  x.len, # 1D, so use length
                                  innerTyp(x))
    dset[dset.all] = x
  elif innerTyp(x) is tuple:
    ## Tuples are written as composite data types!
    let dset = h5f.create_dataset(path / name,
                                  x.len, # 1D, so use length
                                  innerTyp(x))
    dset[dset.all] = x
  else:
    raise newException(ValueError, "For now cannot serialize a nested sequence. Argument of shape " &
      $x.shape & " and type " & $T)

proc toH5*[T: object](h5f: H5File, x: T, name = "", path = "/") =
  # construct group of the name under `path`
  let grp = path / name / $typeof(T)
  discard h5f.create_group(grp)
  for field, val in fieldPairs(x):
    echo "Field: ", field
    h5f.toH5(val, field, grp)

proc toH5*[T: ref object](h5f: H5File, x: T, name = "", path = "/") =
  ## Ref objects are dereferenced and the underlying object stored. Be careful with
  ## nested reference objects that might by cyclic!
  h5f.toH5(x[], name, path)

proc toH5*[T](x: T,
              file: string,
              path: string = "/") = # group in the file (to add to an existing file for example
  var h5f = H5open(file, "rw")
  h5f.toH5(x, path)
  let err = h5f.close()
  if err != 0:
    raise newException(IOError, "Failed to close the H5 file " & $file & " after writing.")
