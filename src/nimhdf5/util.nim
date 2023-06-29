# this file contains utility procs, which are used all over
# the higl-level bindings of this library. They are mostly related
# to convenience procs, which are missing from the Nim standard
# library, e.g. to get the shape of a nested sequence.
# Others are more specific, but still not restricted to the H5
# library, e.g. formatName(), which formats a string handed to
# the `[]`(H5File) proc to a format suitable for parsing.
# read: any proc, whose understanding does not require knowledge
# of the H5 library (although the purpose of the function might)
# and does not make use of any datatypes defined for H5 interop.

import std / [strutils, macros, os, pathnorm]

template withDebug*(actions: untyped) =
  ## a debugging template, which can be used to e.g. output
  ## debugging information in the HDF5 library. The actions given
  ## to this template are only performed, if the
  ## -d:DEBUG_HDF5
  ## compiler flag is set.
  when defined(DEBUG_HDF5):
    actions

proc formatName*(name: string): string =
  # this procedure formats a given group / dataset name by prepending
  # a potentially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  # Note: we use `normalizePath` only for the behavior of `./`, `..` and multiple `/`
  result = "/" & name.normalizePath().strip(chars = ({'/'} + Whitespace + NewLines))

template getParent*(dset_name: string): string =
  ## given a `dset_name` after formating (!), return the parent name,
  ## simly done by a call to parentDir from ospaths
  var result: string
  result = parentDir(dset_name)
  if result == "":
    result = "/"
  result

proc traverseTree(input: NimNode): NimNode =
  # iterate children
  case input.kind
  of nnkSym:
    case input.typeKind
    of ntyAlias, ntyTypeDesc, ntySequence: result = traverseTree(input.getTypeImpl)
    of ntyBool, ntyChar, ntyInt .. ntyUint64, ntyTuple, ntySet, ntyObject, ntyString: result = input
    else:
      doAssert false, "Invalid type kind: " & $input.typeKind
  of nnkBracketExpr:
    if input.typeKind == ntyTypeDesc:
      result = traverseTree(input[1]) # look at actual type
    else:
      # look at last child for inner type
      result = traverseTree(input[input.len - 1])
  of nnkTupleConstr, nnkTupleTy:
    result = input
  else:
    doAssert false, "Invalid node: " & $input.treerepr

macro getInnerType*(TT: typed): untyped =
  ## macro to get the subtype of a nested type by iterating
  ## the AST
  # traverse the AST
  let res = traverseTree(TT.getTypeImpl)
  # assign symbol to result
  result = quote do:
    `res`

macro iterateEnumFields*(typ: typed): untyped =
  ## Creates a bracket with all elements that are actually set in the given enum type
  ##
  ## NOTE: this is currently not performing a lot of checks on what the argument is. It
  ## just assumes you only hand an enum from a generic context (i.e. the `iterateEnum`
  ## iterator below)
  let typImpl = typ.getTypeImpl[1].getImpl
  let enumTy = typImpl[2]
  doAssert enumTy.kind == nnkEnumTy
  result = nnkBracket.newTree()
  for field in enumTy:
    case field.kind
    of nnkEmpty: continue
    of nnkEnumFieldDef:
      result.add field[0]
    else:
      error("Invalid kind encountered in enum definition: " & $field.kind)

iterator iterateEnumSet*[T](s: set[T]): T =
  for field in iterateEnumFields(T):
    if field in s:
      yield field
