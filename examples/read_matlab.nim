import std/json
import nimhdf5, nimhdf5 / [hdf5_matlab]

let mat = deserializeMatlab("/tmp/example.mat")

## Read a struct field `foo` of the stored Matlab struct
echo mat.readJson("foo").pretty()
## Iterate over all the sturct fields
for k in keys(mat):
  echo k
  for r in references(mat.h5f, mat[k]):
    ## `r` is now a `H5Reference`, which is a variant that may either be a H5Group
    ## or a `H5Dataset`, depending.
    echo r

## Of course you can define a custom type that matches the layout of the data stored
## in a dataset and use the regular nimhdf5 functionality to read Matlab like files!
