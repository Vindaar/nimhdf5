# this file contains utility procs, which are used all over
# the higl-level bindings of this library. They are mostly related
# to convenience procs, which are missing from the Nim standard
# library, e.g. to get the shape of a nested sequence.
# Others are more specific, but still not restricted to the H5
# library, e.g. formatName(), which formats a string handed to
# the `[]`(H5FileObj) proc to a format suitable for parsing.
# read: any proc, whose understanding does not require knowledge
# of the H5 library (although the purpose of the function might)
# and does not make use of any datatypes defined for H5 interop.

import strutils

template withDebug*(actions: untyped) =
  ## a debugging template, which can be used to e.g. output
  ## debugging information in the HDF5 library. The actions given
  ## to this template are only performed, if the
  ## -d:DEBUG_HDF5
  ## compiler flag is set.
  when defined(DEBUG_HDF5):
    actions

proc formatName*(name: string): string =
  # this procedure formats a given group / dataset namy by prepending
  # a potentially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  result = "/" & strip(name, chars = ({'/'} + Whitespace + NewLines))

proc shape*[T: (SomeNumber | bool | char | string)](x: T): seq[int] = @[]
  ## Exists so that recursive template stops with this proc.

proc shape*[T](x: seq[T]): seq[int] =
  ## recursively determine the dimension of a nested sequence.
  ## we simply append the dimension of the current seq to the
  ## result and call this function again recursively until
  ## we hit the type at core, which is catched by the above proc
  ## 
  ## Example:
  ##    let x = @[ @[ @[1, 2, 3], @[1, 2, 3]],
  ##               @[ @[1, 2, 3], @[1, 2, 3]] ]
  ##    echo x.shape
  ##    -> @[2, 2, 3]
  result = @[]
  if len(x) > 0:
    result.add(len(x))
    result.add(shape(x[0]))

proc flatten*[T: SomeNumber](a: seq[T]): seq[T] = a
proc flatten*[T: seq](a: seq[T]): auto =
  ## proc to flatten a nested sequence `a` to a 1D sequence,
  ## by recursively applying concat to the remaining sequence
  ## makes use of a stopping proc `flatten(T: SomeNumber)()`
  ##
  ## Example:
  ##   let a = @[ @[1, 2, 3], @[4, 5, 6]]
  ##   let a_flat = a.flatten
  ##   echo a_flat
  ##   -> @[1, 2, 3, 4, 5, 6]
  a.concat.flatten
  
# not used / not working? :(
template getSeq(t: untyped, data: untyped): untyped =
  when t is float64:
    data = newSeq[float64](n_elements)
  elif t is int64:
    data = newSeq[int64](n_elements)
  else:
    discard
  data

template getIndexSeq(ind: int, shape: seq[int]): seq[int] =
  # not used
  # given an index for a 1D array (flattened from nD), calculate back
  # the indices of that index in terms of N dimensions
  # e.g. if shape is [2, 4, 10] and index ind == 54:
  # returns a seq of: @[1, 1, 4], because:
  # x = 1
  # y = 1
  # z = 4
  # => ind = x + y * 10 + z * 4 * 10
  let dim = foldl(shape, a * b)
  let n_dims = len(shape)
  var result = newSeq[int](n_dims)
  var
    # set our remaining variable to ind as the start
    rem = ind
    # variable for dimensionality, starting by 1, multiplying with each j in shape
    d = 1
  for i, j in shape:
    # multiply with current dimensionality
    d *= j
    # given remainder, get the current index by dividing out the rest of the
    # dimensionality 
    result[i] = rem div int(dim / d)
    rem = rem mod int(dim / d)
  result

