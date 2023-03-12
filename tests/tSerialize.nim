#[
Simple example showing how objects can be serialized (even ref objects)
and how the functionality is extended using custom `toH5` procedures,
here done for arraymancer `Tensor` and datamancer `DataFrame` types.
]#

from os import `/`
import nimhdf5
import datamancer

type
  Bar = object
    a: int
    c: char

  TheKind = enum
    tkA, tkB

  TestFloat = distinct float

  Foo = ref object
    x: float
    y: int
    z: seq[int]
    s: string
    b: Bar
    tf: TestFloat
    files: seq[string]
    case kind: TheKind
    of tkA: lol: int
    of tkB: lmao: float
    test: int
    df: DataFrame

## Test extending the
proc toH5[T](h5f: H5File, x: Tensor[T], name = "", path = "/") =
  ## Stores the given arraymancer `Tensor` in the given H5 file using the
  ## shape info to construct an equivalent dataset.
  echo "Constructing: ", path / name
  let dset = h5f.create_dataset(path / name,
                                @(x.shape), # 1D, so use length
                                T)
  when T is KnownSupportsCopyMem:
    dset.unsafeWrite(x.toUnsafeView(), x.size.int)
  else:
    dset[dset.all] = x.toSeq1D

proc toH5(h5f: H5File, x: DataFrame, name = "", path = "/") =
  ## Stores the given datamancer `DataFrame` as in the H5 file.
  ## This is done by constructing a group for the dataframe and then adding
  ## each column as a 1D dataset.
  ##
  ## Alternatively we could also store it as a composite datatype, but that is less
  ## efficient for reading individual columns.
  let grp = path / name
  discard h5f.create_group(grp)
  for k in getKeys(x):
    withNativeTensor(x[k], val):
      echo val
      when typeof(val) isnot Tensor[Value]:
        h5f.toH5(val, k, grp)
      else:
        echo "[WARNING]: writing object column " & $k & " as string values!"
        h5f.toH5(val.valueTo(string), k, grp)

let b = Bar(a: 123, c: 'x')
let df = toDf({"x" : @[1, 2, 3], "y" : @["a", "b", "c"]})

let x = Foo(x: 5.5, y: 10, z: @[1, 2, 3, 4, 5], s: "hello", files: @["/tmp/test.txt", "/tmp/foo.txt"], b: b,
            tf: 5.5.TestFloat,
            kind: tkA, lol: 5, test: 6,
            df: df)

x.toH5("/tmp/test.h5", path = "/SubPath")

## XXX: Ideally we'd turn this into a proper test case that checks
## the content actually shows up as it should. We do that by hand
## right now as I don't want to waste more time on this at the moment.
