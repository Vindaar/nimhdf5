import std / [tables, os]
import nimhdf5

proc writeDeserTest[T](x: T, f: string) =
  x.toH5(f)

  let xx = deserializeH5[T](f)
  echo "Deserialized: ", xx

  ## Verify they are the same!
  doAssert xx == x

block Float:
  let file = getTempDir() / "cacheTab_float.h5"
  type
    TabKey = (int, string)
    TabVal = float
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = 123.54

  writeDeserTest(cacheTab, file)

block String:
  let file = getTempDir() / "cacheTab_string.h5"
  type
    TabKey = (int, string)
    TabVal = string
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = "HALO"

  writeDeserTest(cacheTab, file)

block SeqInt:
  let file = getTempDir() / "cacheTab_seqint.h5"
  type
    TabKey = (int, string)
    TabVal = seq[int]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @[1, 2, 3, 4, 5] #@[1.1, 1.12, 123.54]

  writeDeserTest(cacheTab, file)

block SeqFloat:
  let file = getTempDir() / "cacheTab_seqfloat.h5"
  type
    TabKey = (int, string)
    TabVal = seq[float]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @[1.1, 1.12, 123.54]

  writeDeserTest(cacheTab, file)

block SeqString:
  let file = getTempDir() / "cacheTab_seqstring.h5"
  type
    TabKey = (int, string)
    TabVal = seq[string]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @["A", "HALO"]

  writeDeserTest(cacheTab, file)

block SeqTuple:
  let file = getTempDir() / "cacheTab_seqtuple.h5"
  type
    TabKey = (int, string)
    TabVal = seq[(int, float)]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @[(1, 1.2), (5, 123.4)]

  writeDeserTest(cacheTab, file)

block SeqTupleStr:
  let file = getTempDir() / "cacheTab_seqtuple_str.h5"
  type
    TabKey = (int, string)
    TabVal = seq[(string, float)]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @[("A", 1.2), ("HALO", 123.4)]

  writeDeserTest(cacheTab, file)

block SeqFloatLarge:
  let file = getTempDir() / "cacheTab_seqfloat_large.h5"
  type
    TabKey = (int, string)
    TabVal = seq[float]
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal]()
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = @[1.2, 3.21, 543.4]

  writeDeserTest(cacheTab, file)

block TrickyTuples:
  let file = getTempDir() / "cacheTab_tricky_tuples.h5"
  ## This checks whether we handle alignment within a tuple that does not need to be
  ## converted, but is contained in an outer tuple that is converted.
  type
    TabKey = (int, string)
    TabVal = (int, float32, float)
    CacheTabTyp = Table[TabKey, TabVal]
  var cacheTab = initTable[TabKey, TabVal](1)
  cacheTab[(232, "DEGA5e09EEGNAGEN")] = (4, 1.2'f32, 53.2)

  writeDeserTest(cacheTab, file)
