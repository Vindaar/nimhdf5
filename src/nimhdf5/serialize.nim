#[
This file contains helpers to serialize objects to a H5 file.

]#

from std / strutils import parseBool, parseEnum
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

proc toH5*[T: char | string | cstring | bool](h5f: H5File, x: T, name = "", path = "/") =
  ## A single character, string, cstring and bool are stored as an attribute with `name` under `path`
  ## in string form.
  let obj = h5f[path.grp_str]
  obj.attrs[name] = $x

proc toH5*[T: enum](h5f: H5File, x: T, name = "", path = "/") =
  ## An enum is stored as an attribute with `name` under `path` where the
  ## value is written as the *string value* of that attribute.
  let obj = h5f[path.grp_str]
  obj.attrs[name] = $x

proc toH5*[T](h5f: H5File, x: set[T], name = "", path = "/") =
  ## A `set` is stored as a dataset with `name` under `path` where the
  ## elements in the set are written as string values in the dataset if the
  ## inner type is an `enum` and otherwise as the native type.
  when T is enum:
    let dset = h5f.create_dataset(path / name,
                                  x.card, # 1D, so use length
                                  string,
                                  overwrite = true)
    dset[dset.all] = x.toSeq.mapIt($it)
  else:
    let dset = h5f.create_dataset(path / name,
                                  x.card, # 1D, so use length
                                  T,
                                  overwrite = true)
    dset[dset.all] = x.toSeq

proc toH5*[T: tuple](h5f: H5File, x: T, name = "", path = "/") =
  ## An tuple is stored as an attribute with `name` under `path`. It is stored
  ## as a composite datatype. If each field of the tuple is not a supported
  ## flat object, this may raise or yield a compile time error.
  let obj = h5f[path.grp_str]
  obj.attrs[name] = x

proc toH5*[T](h5f: H5File, x: openArray[T], name = "", path = "/") =
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
  when T is SomeNumber | char | string | cstring | tuple | object:
    # Note that tuples will be written as composite types!
    let dset = h5f.create_dataset(path / name,
                                  x.len, # 1D, so use length
                                  T,
                                  overwrite = true)
    dset[dset.all] = @x # make sure to convert array to seq
  elif T is enum:
    # Note that tuples will be written as composite types!
    let dset = h5f.create_dataset(path / name,
                                  x.len, # 1D, so use length
                                  string,
                                  overwrite = true)
    dset[dset.all] = @x.mapIt($it) # make sure to convert array to seq
  else:
    raise newException(ValueError, "For now cannot serialize a nested sequence. Argument of shape " &
      $x.shape & " and type " & $T)

proc toH5*[T: object](h5f: H5File, x: T, name = "", path = "/", exclude: seq[string] = @[]) =
  ## XXX: In principle we could have a check / option that allows to
  ## store fully flat `objects` as a composite type (via the already
  ## supported functionality).
  # construct group of the name under `path`
  let grp = path / name
  discard h5f.create_group(grp)
  for field, val in fieldPairs(x):
    if field notin exclude: # skip this field
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

import std / options
proc toH5*[T](h5f: H5File, x: Option[T], name = "", path = "/") =
  ## Option is simply written as a regular object if it is `some`, else it is
  ## ignored.
  ## XXX: Of course when parsing we need to check and do the same.
  ## XXX: add some field (attribute?) indicating it's an option?
  if x.isSome:
    h5f.toH5(x.get, name, path)

## ==============================
## Deserialization
## ==============================

template withGrp(h5f, path, name, body: untyped): untyped =
  let obj {.inject.} = h5f[path.grp_str]
  if name in obj.attrs:
    body

template withDst(h5f, path, name, body: untyped): untyped =
  if path / name in h5f:
    body

proc fromH5*[T: distinct](h5f: H5File, res: var T, name = "", path = "/") =
  ## A single number is stored as an attribute with `name` under `path`.
  ## An additional attribute is created that stores the name of the original type.
  withGrp(h5f, path, name):
    res = T(obj.attrs[name, distinctBase(T)])

proc fromH5*[T: SomeNumber](h5f: H5File, res: var T, name, path: string) =
  ## Reads the attribute `name` from `path` into `res`
  withGrp(h5f, path, name):
    res = obj.attrs[name, T]

proc fromH5*[T: char | string | cstring | bool](h5f: H5File, res: var T, name = "", path = "/") =
  ## A single character, string, cstring and bool are stored as an attribute with `name` under `path`
  ## in string form.
  withGrp(h5f, path, name):
    when T is bool:
      res = parseBool(obj.attrs[name, string])
    elif T is char:
      let s = obj.attrs[name, string]
      doASsert s.len == 0, "Trying to read a char from a string with more than one element."
      res = s[0]
    elif T is string:
      res = obj.attrs[name, string]
    else:
      doAssert false, "Cannot deserialize a `cstring` safely"

proc fromH5*[T: enum](h5f: H5File, res: var T, name = "", path = "/") =
  ## An enum is stored as an attribute with `name` under `path` where the
  ## value is written as the *string value* of that attribute.
  withGrp(h5f, path, name):
    res = parseEnum[T](obj.attrs[name, string])

proc fromH5*[T: tuple](h5f: H5File, res: var T, name = "", path = "/") =
  ## An tuple is stored as an attribute with `name` under `path`. It is stored
  ## as a composite datatype. If each field of the tuple is not a supported
  ## flat object, this may raise or yield a compile time error.
  withGrp(h5f, path, name):
    res = obj.attrs[name, T]

proc fromH5*[T](h5f: H5File, res: var set[T], name = "", path = "/") =
  ## A `set` is stored as a dataset with `name` under `path` where the
  ## elements in the set are written as string values in the dataset if the
  ## inner type is an `enum` and otherwise as the native type.
  withDst(h5f, path, name):
    when T is enum:
      let data = h5f[(path / name), string]
      for el in data:
        res.incl parseEnum[T](el)
    else:
      let data = h5f[(path / name), T]
      for el in data:
        res.incl T(el)

proc fromH5*[N; T](h5f: H5File, res: var array[N, T], name = "", path = "/") =
  ## An array is stored as a 1D dataset if it is a flat sequence, else we
  ## raise an exception.
  ##
  ## For sequences of tuples the same remark as for raw tuples hold: they should
  ## be flat types. Otherwise runtime or compile time errors may occur.
  ##
  ## XXX: We could check manually if the sequence can be flattened (all sub elements
  ## same length) or just default to assume it is not flat and store as variable length.
  ## But what to do for 3D, 4D etc?
  withDst(h5f, path, name):
    when T is SomeNumber | char | string | cstring | tuple | object:
      let data = h5f[path / name, T]
      doAssert res.len == data.len
      for i, x in data:
        when N is SomeInteger:
          res[i] = x
        else:
          res[N(i)] = x
    elif T is enum:
      let data = h5f[path / name, string]
      doAssert res.len == data.len
      for i, x in data:
        res[i] = parseEnum[T](x)
    else:
      raise newException(ValueError, "For now cannot deserialize a nested array. Argument of shape " &
        $res.shape & " and type " & $T)

proc fromH5*[T](h5f: H5File, res: var seq[T], name = "", path = "/") =
  ## A sequence is stored as a 1D dataset if it is a flat sequence, else we
  ## raise an exception.
  ##
  ## For sequences of tuples the same remark as for raw tuples hold: they should
  ## be flat types. Otherwise runtime or compile time errors may occur.
  ##
  ## XXX: We could check manually if the sequence can be flattened (all sub elements
  ## same length) or just default to assume it is not flat and store as variable length.
  ## But what to do for 3D, 4D etc?
  withDst(h5f, path, name):
    when T is SomeNumber | char | string | cstring | tuple | object:
      res = h5f[path / name, T]
    elif T is enum:
      let data = h5f[path / name, string]
      res = newSeq[T](data.len)
      for i, x in data:
        res[i] = parseEnum[T](x)
    else:
      raise newException(ValueError, "For now cannot deserialize a nested sequence. Argument of shape " &
        $res.shape & " and type " & $T)

proc fromH5*[T](h5f: H5File, res: var Option[T], name = "", path = "/") =
  ## Option is simply written as a regular object if it is `some`, else it is
  ## ignored.
  ## XXX: Of course when parsing we need to check and do the same.
  ## XXX: add some field (attribute?) indicating it's an option?
  when T is openArray | set | object | tuple:
    if path / name in h5f:
      var tmp: T
      h5f.fromH5(tmp, name, path)
      res = some( tmp )
  else:
    let grp = h5f[path.grp_str]
    if name in grp.attrs:
      res = some( grp.attrs[name, T] )

proc fromH5*[T: object](h5f: H5File, res: var T, name = "", path = "/", exclude: seq[string] = @[]) =
  let grp = path / name
  for field, val in fieldPairs(res):
    if field notin exclude:
      h5f.fromH5(val, field, grp)

proc deserializeH5*[T: object](h5f: H5File, name = "", path = "/", exclude: seq[string] = @[]): T =
  ## Cannot name it same as `fromH5` because that causes the compiler to get confused. I don't understand,
  ## but with `LikelihoodContext` it ends up calling the `var set[LikelihoodContext]` overload, which does
  ## not make any sense.
  h5f.fromH5(result, name, path, exclude)

proc deserializeH5*[T: object](fname: string, name = "", path = "/", exclude: seq[string] = @[]): T =
  ## Cannot name it same as `fromH5` because that causes the compiler to get confused. I don't understand,
  ## but with `LikelihoodContext` it ends up calling the `var set[LikelihoodContext]` overload, which does
  ## not make any sense.
  withH5(fname, "r"):
    h5f.fromH5(result, name, path, exclude)
