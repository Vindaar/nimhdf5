import ./datatypes, ./datasets, ./files, ./groups, ./util, ./serialize
import std / tables

proc toH5*[K; V](h5f: H5File, tab: Table[K, V] | OrderedTable[K, V], name = "", path = "/") =
  ## Stores the given `Table` as in the H5 file.
  ## This is done by constructing a group for the table and adding a
  ## compound dataset with (key, value) pairs in each row.
  bind `/`
  let grp = path / name
  discard h5f.create_group(grp)

  var data = newSeqOfCap[(K, V)](tab.len)
  for k, v in tab:
    data.add (k, v)
  h5f.toH5(data, "table", grp)

proc fromH5*[K; V](h5f: H5File, res: var (Table[K, V] | OrderedTable[K, V]), name = "", path = "/", exclude: seq[string] = @[]) =
  ## Reads a Table of the given type stored by `toH5`
  bind `/`
  let grp = h5f[(path / name).grp_str]
  var data: seq[(K, V)]
  h5f.fromH5(data, "table", grp.name)
  res = default(typeof(res))
  for i in 0 ..< data.len:
    let (k, v) = data[i]
    res[k] = v
