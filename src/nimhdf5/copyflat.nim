from util import address

type
  BufferObj* {.acyclic.} = object
    size*: int
    owned*: bool
    data*: pointer
    offsetOf*: int
    children*: seq[Buffer]
  Buffer* = ref BufferObj

  SimpleTypes* = SomeNumber | char | bool

proc `=copy`(dest: var BufferObj, source: BufferObj) {.error: "Copying a buffer is not allowed at the moment.".}

proc `=destroy`(x: var BufferObj) =
  for ch in mitems(x.children):
    `=destroy`(ch)
  if x.owned and x.data != nil:
    #echo "deallocing: ", x.offsetOf
    deallocShared(x.data)

proc `$`*(b: Buffer): string =
  result = "Buffer(size: " & $b.size & ", owned: " & $b.owned & ", data: " & $b.data.repr & ", offsetOf: " & $b.offsetOf & ", children: " & $b.children.len & ")"

proc newBuffer*(size: int, owned = true): Buffer =
  result = Buffer(owned: owned, size: size, data: allocShared0(size), offsetOf: 0)

proc newBuffer*(buf: pointer, size: int): Buffer =
  result = Buffer(owned: false, size: size, data: buf, offsetOf: 0)

proc newBuffer*[T](s: seq[T]): Buffer =
  result = Buffer(owned: false,
                  data: (if s.len > 0: cast[pointer](address(s[0]))
                         else: nil),
                  offsetOf: 0)

proc calcSize*[T: object | tuple](x: T): int
proc calcSize*[T: SimpleTypes](x: T): int =
  result = sizeof(T)

import typetraits
proc calcSize*[T: distinct](x: T): int =
  result = sizeof(distinctBase(T))

proc calcSize*[T: pointer|ptr](x: T): int =
  result = sizeof(T)

proc calcSize*[T: array](x: T): int =
  result = sizeof(T)

proc calcSize*[T: string | cstring](x: T): int =
  result = sizeof(ptr char)

proc calcSize*[T](x: seq[T]): int =
  result = sizeof(csize_t) + sizeof(pointer)

proc calcSize*[T: object | tuple](x: T): int =
  for field, val in fieldPairs(x):
    result += calcSize(val)

proc calcSize*[T](x: typedesc[T]): int =
  var tmp: T
  result = calcSize(tmp)

proc `+%`(x: pointer, offset: int): pointer =
  result = cast[pointer](cast[uint](x) + offset.uint)

proc copyFlat*[T](x: openArray[T]): Buffer

proc copyFlat[T: object | tuple](buf: var Buffer, x: T)
proc copyFlat[T: SimpleTypes](buf: var Buffer, x: T) =
  let size = calcSize(x)
  var target = buf.data +% buf.offsetOf
  target.copyMem(address(x), size)

proc copyFlat[T: distinct](buf: var Buffer, x: T) =
  let size = calcSize(x)
  var target = buf.data +% buf.offsetOf
  target.copyMem(address(x), size)

proc getAddr(x: string): uint =
  if x.len > 0:
    result = cast[uint](address(x[0]))
  else:
    result = 0

proc copyFlat[T: string | cstring](buf: var Buffer, x: T) =
  let size = calcSize(x)
  var p = getAddr(x) # want to copy the *address* of the string
  buf.copyFlat(p)

proc copyFlat[T](buf: var Buffer, x: seq[T]) =
  let child = copyFlat(x)
  buf.children.add child
  # copy child address
  buf.copyFlat((csize_t(x.len), cast[uint](child.data)))

import ./type_utils
proc copyFlat[T: object | tuple](buf: var Buffer, x: T) =
  var tmp: genCompatibleTuple(T, replaceVlen = true)
  #echo "-----------OBJ tuple compat: ", typeName(typeof(tmp)), " OF SIZE: ", sizeof(tmp), " StartingIdx: ", buf.offsetOf, "\n"
  let startIdx = buf.offsetOf # start data reading here
  for field, val in fieldPairs(x):
    buf.offsetOf = startIdx + offsetTup(tmp, field) # new offset
    buf.copyFlat(val)
  buf.offsetOf = startIdx + sizeof(tmp) # adjust final offset (jump over last member)
  #echo "FINAL OFFSET AT PROC END ", buf.offsetOf, " \n=======\n"

proc writeBuffer*(b: Buffer, fname = "/tmp/hexdat.dat") =
  writeFile(fname, toOpenArray(cast[ptr UncheckedArray[byte]](b.data), 0, b.size-1))

proc copyFlat*[T](x: openArray[T]): Buffer =
  if x.len > 0:
    let size = x.len * calcSize(x[0])
    result = newBuffer(size)
    when T.needsCopy:
      var tmp: genCompatibleTuple(T, replaceVlen = true)
    else:
      var tmp: T
    for el in x:
      result.copyFlat(el)
      when typeof(tmp) isnot tuple|object: # in the other case incrementation is done in the `copyFlat` proc above
        inc result.offsetOf, sizeof(tmp)
  else:
    result = newBuffer(0)

proc fromFlat*[T](buf: Buffer): seq[T]
proc fromFlat[T: SimpleTypes | pointer](x: var T, buf: Buffer) =
  let size = calcSize(x)
  var source = buf.data +% buf.offsetOf
  copyMem(addr(x), source, size)

## XXX: `fromFlat` for fixed length arrays!
proc fromFlat*[T: array](x: var T, buf: Buffer) =
  let size = calcSize(x)
  var source = buf.data +% buf.offsetOf
  copyMem(addr(x), source, size)

proc fromFlat[T: string | cstring](x: var T, buf: Buffer) =
  let source = buf.data +% buf.offsetOf
  let strBuf = cast[ptr cstring](source)
  if not strBuf.isNil:
    when T is string:
      x = $(strBuf[])
    else:
      x = strBuf[]

proc fromFlat[T](x: var seq[T], buf: Buffer) =
  # construct a child buffer.
  # 1. extract the size of the child buffer
  var len: csize_t
  len.fromFlat(buf)
  inc buf.offsetOf, sizeof(csize_t)
  let source = buf.data +% buf.offsetOf
  # 2. extract the data pointer
  var p: pointer
  p.fromFlat(buf)
  let bufChild = newBuffer(p, len.int * calcSize(T))
  x = fromFlat[T](bufChild)
  inc buf.offsetOf, sizeof(pointer)

proc fromFlat[T: object | tuple](x: var T, buf: Buffer) =
  var tmp: genCompatibleTuple(T, replaceVlen = true)
  #echo "-----------OBJ tuple compat: ", typeName(typeof(tmp)), " OF SIZE: ", sizeof(tmp), " StartingIdx: ", buf.offsetOf, "\n"
  let startIdx = buf.offsetOf
  for field, val in fieldPairs(x):
    buf.offsetOf = startIdx + offsetTup(tmp, field)
    val.fromFlat(buf)
  buf.offsetOf = startIdx + sizeof(tmp)
  #echo "FINAL OFFSET AT PROC END ", buf.offsetOf, " \n=======\n"

proc fromFlat*[T](buf: Buffer): seq[T] =
  ## Returns a sequence of `T` from the given buffer, taking into account conversion from
  ## `ptr char` to `string` and nested buffer children to `seq[U]`.
  let len = buf.size div calcSize(T)
  # set `offsetOf` to 0 to copy from beginning
  buf.offsetOf = 0
  result = newSeq[T](len)
  when T.needsCopy:
    var tmp: genCompatibleTuple(T, replaceVlen = true)
  else:
    var tmp: T
  for i in 0 ..< result.len:
    # copy element by element
    result[i].fromFlat(buf)
    when typeof(tmp) isnot tuple|object: # in the other case incrementation is done in the `copyFlat` proc above
      inc buf.offsetOf, sizeof(tmp)

when isMainModule:
  block A:
    var data = newSeq[(int, (float, string), seq[string])]()
    data.add (0xAFFEAFFE.int, (2342.2, "hello"), @["A", "HALO"])
    #buf.add (0x13371337.int, ("", 52.2), @["B", "FOO"])
    let buf = copyFlat(data)

    let xx = fromFlat[(int, (float, string), seq[string])](buf)
    echo xx

  block B:
    var data = newSeq[(int, (float, string), seq[int])]()
    data.add (0xAFFEAFFE.int, (2342.2, "hello"), @[1, 2, 3, 4, 5])
    #data.add (0x13371337.int, ("", 52.2), @["B", "FOO"])
    let buf = copyFlat(data)

    let xx = fromFlat[(int, (float, string), seq[int])](buf)
    echo xx
