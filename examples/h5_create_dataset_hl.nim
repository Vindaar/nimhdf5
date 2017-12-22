#############################################################################
# Copyright by The HDF Group.                                               #
# Copyright by the Board of Trustees of the University of Illinois.         #
# All rights reserved.                                                      #
#                                                                           #
# This file is part of HDF5.  The full HDF5 copyright notice, including     #
# terms governing use, modification, and redistribution, is contained in    #
# the COPYING file, which can be found at the root of the source code       #
# distribution tree, or in https://support.hdfgroup.org/ftp/HDF5/releases.  #
# If you do not have access to either file, you may request a copy from     #
# help@hdfgroup.org.                                                        #
#############################################################################

## This example illustrates how to create a dataset that is a 4 x 6 
## array.  It is used in the HDF5 Tutorial.

## adapted to Nim by S. Schmidt (s.schmidt@physik.uni-bonn.de)
## used to illustrate low level access via C API

import ../src/nimhdf5
import ../src/nimhdf5/H5nimtypes
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

  # create dataset
  var dset = h5f.create_dataset("/group1/group2/dset", (2, 2, 5), float64)

  # var dat: seq[float64] = newSeq[float64](20)
  # var count = 0
  # for i in 0..<len(dat):
  #   dat[i] = float64(count) + 1
  #   inc count

  # let gr: grp_str = grp_str("/group1/group2")
  # let t = h5f[gr] #H5Group(get(h5f, gr))
  let gg = "/group1" # readLine(stdin)
  
  let t2 = h5f[gg.grp_str]
  echo name(type(t2))
  echo t2

  var g = h5f.create_group("/test/another/group")

  g = h5f["/test/another".grp_str]
  
  var h = g.create_group("/more/branches")
  echo "\n\n"
  echo "file ", h5f#.groups
  echo "\n\n\nnew group", g#.groups[]
  echo "old group", t2#.groups[]

  var d_ar = @[ @[ @[1, 2, 3, 4, 5],
                   @[6, 7, 8, 9, 10] ],
                @[ @[1, 2, 3, 4, 5],
                   @[6, 7, 8, 9, 10] ] ]
  var ddd = mapIt(d_ar, mapIt(it, mapIt(it, float64(it))))

  echo ddd
  echo ddd.shape, " ", ddd.high
  
  # if we simply want to write over the whole dataset 
  dset[dset.all] = ddd

  let dtype = nimToH5type(float64)
  # status = H5Dwrite(dset.dataset_id, dtype, H5S_ALL, H5S_ALL, H5P_DEFAULT,
  #                   addr(dat[0]))
  

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
  # Open "dset" dataset under the root group.
  #
  var dataset = file["/group1/group2/dset".dset_str]
  echo dataset
  echo file.datasets
  echo "ok?"
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

  discard file.close()

  
proc main() =
  write_some()
  read_some()
  
when isMainModule:
  main()
