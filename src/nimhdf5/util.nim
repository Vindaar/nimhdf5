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
import algorithm
import sequtils
import macros

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

proc traverseTree(input: NimNode): NimNode =
  # iterate children
  for i in 0 ..< input.len:
    case input[i].kind
    of nnkSym:
      # if we found a symbol, take it
      result = input[i]
    of nnkBracketExpr:
      # has more children, traverse
      result = traverseTree(input[i])
    else:
      error("Unsupported type: " & $input.kind)

macro getInnerType*(TT: typed): untyped =
  ## macro to get the subtype of a nested type by iterating
  ## the AST
  # traverse the AST
  let res = traverseTree(TT.getTypeInst)
  # assign symbol to result
  result = quote do:
    `res`
