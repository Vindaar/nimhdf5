# a simple example showing the so far available nimhdf5
# high level bindings

import nimhdf5
# wrapper is normally not needed to be imported, here only
# to showcase
import nimhdf5/hdf5_wrapper
import typetraits
import typeinfo
import sequtils
import tables

const FILE = "dset.h5"

proc write_some() = 
  var
    # identifiers
    status: herr_t
  
  # Create a new file using default properties.
  var h5f = H5file(FILE, "rw")

  # create datasets
  var dset = h5f.create_dataset("/group1/group2/dset", (2, 2, 5), float64)
  var dset1D = h5f.create_dataset("/group1/dset1D", 5, float64)
  var dset_broadcast = h5f.create_dataset("/group1/dsetbroadcast", (3, 3), int)
  var dset_resize = h5f.create_dataset("/group1/dsetresize", (3, 3), int, chunksize = @[3, 3], maxshape = @[9, 9])
  # define special type for variable length datatype
  let vlen_type = special_type(int)
  var dset_vlen = h5f.create_dataset("/group1/dset_vlen", 5, vlen_type)

  # define a group name and
  let g1_name = "/group1"
  # and get the corresponding group from the file
  # we get the group using the string by converting the string
  # to a distinct string type called grp_str. Used to differentiate
  # between groups and datasets, which both can the retrieved from
  # the H5FileObj
  var g1 = h5f[g1_name.grp_str]
  # print type and group itself
  echo name(type(g1))
  echo g1

  # create another nested group
  var g2 = h5f.create_group("/test/another/group")
  # and create groups based on the just created group relative
  # from its location in the file
  var h = g2.create_group("/more/branches")
  echo "\n\n"
  echo "file ", h5f
  echo "\n\n\nnew group", g2
  echo "old group", g1

  # define some arrays to write
  var d_ar = @[ @[ @[1'f64, 2, 3, 4, 5],
                   @[6'f64, 7, 8, 9, 10] ],
                @[ @[1'f64, 2, 3, 4, 5],
                   @[6'f64, 7, 8, 9, 10] ] ]

  var d1d = @[13'f64, 12, 2, 123, 1e9]

  var d_br = @[ @[1, 1, 1],
                @[1, 1, 1],
                @[1, 1, 1] ]

  # and a variable length array
  var d_vlen = @[ @[1, 2, 3],
                  @[4, 5],
                  @[6, 7, 8, 9, 10],
                  @[11, 12, 13, 14, 15],
                  @[16, 17, 18, 19, 20, 21, 22, 22, 23, 24, 25] ]
  
  # if we simply want to write over the whole dataset, use the .all field of
  # the H5DataSet object. It's a simple enum, used to differentiate between
  # this and using indices (which ironically isn't implemented...)
  dset[dset.all] = d_ar
  dset1D[dset1D.all] = d1d
  dset_broadcast[dset_broadcast.all] = d_br
  # NOTE: if you call this programm twice in a row, dset_resize will already have been
  # resized to (9, 9). This means that the following line will instead of writing the
  # data to the top left (3, 3) array, it will now write all entries of the first
  # row of the (9, 9) array!
  dset_resize[dset_resize.all] = d_br
  dset_vlen[dset_vlen.all] = d_vlen

  # write values for multiple coordinates by handing sequences of coordinates and
  # one sequence of the values to write
  dset.write(@[@[0, 0, 2], @[1, 1, 3]], @[3'f64, 123'f64])
  # write single value by handing sequence of single coordinate and sequence of single
  # value
  dset.write(@[0, 1, 2], @[1337'f64])

  # write whole row by broadcasting one index
  dset_broadcast.write(0, @[9, 9, 9])
  # overwrite last column
  dset_broadcast.write(2, @[7, 7, 7], column = true)
  
  # write 2 values into 1D data by handing sequence of indices to write
  dset1D.write(@[2, 4], @[8'f64, 21e9])
  # write single value to 1D dataset
  dset1D.write(0, 299792458'f64)
  
  # write single or more elements of VLEN data
  dset_vlen.write(@[1], @[8, 3, 12, 3, 3, 555, 23234234])
  # write single element into single index
  dset_vlen.write(3, 1337)

  # now resize the dsetresize dataset and write additional data to it
  dset_resize.resize((9, 9))
  # now write some data to the bottom right of the resized array
  dset_resize.write(@[@[7,7], @[7,8], @[8,7], @[8,8]], @[1, 1, 1, 1])

  # # now write some attributes
  g1.attrs["Time"] = "21:19"
  g1.attrs["Counter"]= 128
  g1.attrs["Seq"] = @[1, 2, 3, 4]
  # will be visible in file as 73 (decimal value of ascii for 'I')
  g1.attrs["Type"]= 'I'
  # boolean type not yet supported
  # g1.attrs["HODL"] = true
  # g1.attrs["UnsupportedType"] = [1, 2, 3]

  echo g1.attrs
  
  # close datasets, groups and file
  status = h5f.close()
  echo "Status of file closing is ", status

proc read_some() =
  # This example writes data to the existing empty dataset created by h5_crtdat.py and then reads it back.
  #
  # Open an existing file using default properties.
  #
  var file = H5File("dset.h5", "r")
  #
  # Open "dset" dataset in the nested groups
  # done using distinct string type dset_str, to differentiate between groups
  # and dataset
  var dataset = file["/group1/group2/dset".dset_str]
  echo dataset
  # # read some specific elements from the dataset
  let inds = @[@[0, 0, 0], @[1, 1, 1], @[1, 1, 4]]
  # to read specific indices from a dataset, we need to hand a mutable
  # sequence in which the data will be stored
  var data_read = newSeq[float64](3)
  dataset.read(inds, data_read)
  echo data_read
  
  echo file.datasets
  # Note: while we could in principle try to write to the dataset, we
  # just got from the file, this would fail (unfortunately with a libhdf5
  # error instead of a Nim custom one. TODO...), since we only opened
  # the file with 'r', instead of 'rw'. Opening the file properly
  # and writing to the dataset also works
  
  withDset(dataset):
    # this allows us to work with the dataset without
    # explicitly performing a type check. So as long as we wish
    # to only work on a single dataset at a time, we can simply
    # do it like this. Be aware though, that this performs
    # a whole read of the data on every template call, so the convenience
    # might have a huge cost, if the dataset is large!
    echo dset
  # alternatively this also works. If you enter a wrong datatype, a ValueError in case
  # the wrong data type is given to the proc. Unfortunately, we cannot dynamically check
  # the data type
  let data = dataset[float64]
  echo data


  # read attributes back
  let g1_name = "/group1"
  var g1 = file[g1_name.grp_str]
  echo g1.attrs.read_attribute("Counter", int)

  # get table of attributes
  var attr = g1.attrs
  echo attr
  # attr contains keys: string, values: AnyKind
  # where the value describes the data type of the attribute
  # so if we want to read some attribute now, simply
  case attr["Counter"]
  of akInt, akInt64:
    let val = g1.attrs["Counter", int]
    echo "Counter is int with val = ", val
  of akFloat:
    let val = g1.attrs["Counter", float]
    echo "Counter is is float with val = ", val    
  else:
    echo "somethign weird somethingsomething ", attr["Counter"]
    discard
  # of course, if you know the data type, feel free to just call
  let val = g1.attrs["Counter", int]
  # from the get go
  # take note however, that each call to attr(<key>, <type>) performs a call
  # to the HDF5 library. So if you wish to avoid the overhead of performing
  # repetetive calls, store the attributes!
  echo "Counter type value is still = ", val
  let seq_val = g1.attrs["Seq", seq[int]]
  echo "Seq val is = ", seq_val
  let time = g1.attrs["Time", string]
  echo "Time val is = ", time

  # or even another way: create a case based on the AnyKind field of the. 
  # dataset like so (this is what the withDset template does internally):
  case dataset.dtypeAnyKind
  of akFloat64:
    echo dataset[float64]
  of akInt64:
    echo dataset[int64]
  else:
    # whatever else you may think is in this dataset
    discard

  # close the file again
  discard file.close()

  
proc main() =
  write_some()
  read_some()
  
when isMainModule:
  main()
