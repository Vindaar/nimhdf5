import macros

#[
Some utility macros that deal with converting an existing type into a type
that contains `ptr char` fields instead of `strings` and `hvl_t` instead
of nested (i.e. VLEN) sequences
]#

from hdf5_wrapper import hvl_t

proc typeNeedsCopy(n: NimNode): bool
proc needsCopyImpl(typ: NimNode): bool =
  result = false
  let implNode = if typ.kind == nnkObjectTy: typ[2] else: typ
  for ch in implNode:
    if ch.kind == nnkIdentDefs:
      let nTyp = ch[1]
      result = result or nTyp.typeNeedsCopy()
    elif typ.kind == nnkTupleConstr: # the fields are the types of the anonymous fields
      result = result or ch.typeNeedsCopy()
    elif typ.kind == nnkBracketExpr:
      # check all bracket expression children
      result = result or ch.typeNeedsCopy()
    else:
      doAssert false, "Invalid branch: " & $ch.kind & " and " & $ch.typeKind

proc typeNeedsCopy(n: NimNode): bool =
  case n.kind
  of nnkSym:
    if n.typeKind in {ntyString, ntySequence}:
      result = true
    elif n.typeKind in {ntyTuple, ntyObject}:
      result = n.getTypeImpl.needsCopyImpl()
    else:
      result = n.typeKind notin {ntyBool, ntyChar, ntyInt .. ntyUint64}
  of nnkIdent:
    result = n.strVal == "string"
  of nnkPtrTy, nnkBracketExpr: ## XXX: study generics?
    result = false
  of nnkTupleConstr, nnkTupleTy:
    result = n.needsCopyImpl()
  else:
    doAssert false, "Unsupported node: " & $n.treerepr

macro needsCopy*(t: typed): untyped =
  ## Checks if the given type contains any fields that requires a copy. Currently that means
  ## it or a nested type contains a `string` field or a `seq` indicating VLEN data.
  doAssert t.typeKind == ntyTypeDesc, "Argument was: " & $t.typeKind & " instead of `ntyTypeDesc`."
  let typ = t.getType[1]
  case typ.typeKind
  of ntyString, ntySequence: result = newLit true
  of ntyBool, ntyChar, ntyInt .. ntyUint64:
    result = newLit false
  of ntyObject, ntyTuple:
    case typ.kind
    of nnkSym:
      result = newLit(needsCopyImpl(typ.getTypeImpl))
    of nnkObjectTy, nnkTupleTy, nnkTupleConstr, nnkBracketExpr:
      result = newLit(needsCopyImpl(typ))
    else:
      doAssert false, "Type kind was = " & $typ.kind & " of " & $t.repr & " and " & $typ.treerepr
  else:
    result = newLit false

proc replaceField(n: NimNode, replaceVlen: bool): NimNode
proc replaceFields(typ: NimNode, replaceVlen: bool): NimNode =
  let implNode = if typ.kind == nnkObjectTy: typ[2] else: typ

  case typ.typeKind
  of ntySequence:
    result = bindSym"hvl_t"
  else:
    result = nnkTupleTy.newTree()
    for i, ch in implNode:
      if ch.kind == nnkIdentDefs:
        result.add nnkIdentDefs.newTree(ident(ch[0].strVal),
                                        ch[1].replaceField(replaceVlen),
                                        newEmptyNode())
      elif typ.kind == nnkTupleConstr: # anonymous tuple with types as args
        result.add nnkIdentDefs.newTree(ident("Field_" & $i),
                                        ch.replaceField(replaceVlen),
                                        newEmptyNode())
      elif typ.kind == nnkBracketExpr:
        # check all bracket expression children
        result.add nnkIdentDefs.newTree(ident("Field_" & $i),
                                        ch.replaceField(replaceVlen),
                                        newEmptyNode())
      else:
        doAssert false, "Invalid branch"

proc replaceField(n: NimNode, replaceVlen: bool): NimNode =
  case n.kind
  of nnkSym:
    if n.typeKind == ntyString:
      result = nnkPtrTy.newTree(ident"char")
    elif n.typeKind == ntySequence:
      ## XXX: check if *INNER* type is also sequence
      ##   -> seq[hvl_t]
      ##   else ->: hvl_t
      result = if replaceVlen: bindSym"hvl_t"
               else: n
    elif n.typeKind in {ntyTuple, ntyObject}:
      result = n.getTypeImpl.replaceFields(replaceVlen)
    else:
      result = n
  of nnkIdent, nnkPtrTy, nnkBracketExpr: ## XXX: study generics (bracket expr)?
    result = n
  of nnkTupleTy, nnkTupleConstr:
    result = n.replaceFields(replaceVlen)
  else:
    doAssert false, "Unsupported node: " & $n.treerepr

macro genCompatibleTuple*(t: typed, replaceVlen: static bool): untyped =
  ## Generates a tuple type from `t` that is equivalent except has all string fields
  ## replaced by `cstring` fields
  let typ = t.getType[1].getTypeImpl
  doAssert typ.kind in {nnkObjectTy, nnkTupleTy, nnkTupleConstr, nnkBracketExpr, nnkSym}, "Instead got " & $typ.kind
  case typ.typeKind
  of ntyString:
    result = nnkPtrTy.newTree(ident"char") #ident"pointer" #ident"cstring"
  of ntySequence:
    result = bindSym"hvl_t"
  else:
    result = replaceFields(typ, replaceVlen)

macro printType*(t: typed): untyped =
  result = newStmtList()
  proc addEcho(x: string): NimNode =
    result = nnkCall.newTree(ident"echo", newLit x)
  result.add addEcho(t.getType.repr)

macro typeName*(t: typed): untyped =
  result = newLit t.getType.repr

macro offsetStr*(x: typed, f: static string): untyped =
  ## Access the `offsetOf` procedure given a static string from `fieldPairs`
  let id = ident(f)
  result = quote do:
    #echo "Offset of: ", `f`, " for ", `x`
    offsetOf(`x`, `id`)


from util import address

proc offsetOfTup*[T: tuple](x: T, idx: static int): int =
  ## Returns the offset of fields in an anonymous tuple by subtracting the
  ## base address of the tuple (field 0) from the target field at index `idx`.
  template getAddr(x): untyped = cast[uint](address x)
  let baseAddr = getAddr(x[0])
  let targAddr = getAddr(x[idx])
  doAssert baseAddr <= targAddr, "Base address was: " & $baseAddr & " and targ address: " & $targAddr
  #echo "OffsetOfTup: ", x, " at ", idx
  result = int(targAddr - baseAddr)

import std / strutils # import removePrefix
from std / sugar import dup
macro offsetTup*(x: typed, f: static string): untyped =
  ## Helper to return the offset of a tuple based on the field name. Can be
  ## an anonymous tuple.
  if f.startsWith("Field"): # anonymous most likely
    let idx = parseInt(f.dup(removePrefix("Field")))
    result = quote do:
      offsetOfTup(`x`, `idx`)
  else:
    # non anonymous, reuse regular macro
    let id = ident(f)
    result = quote do:
      #echo "Offset of for tuple: ", `f`, " for ", `x`
      offsetOf(`x`, `id`)
