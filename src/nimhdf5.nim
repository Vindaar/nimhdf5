# now import / include the relevant pieces of the library
import nimhdf5/hdf5_wrapper
#include nimhdf5/H5nimtypes
import nimhdf5/H5nimtypes
export H5nimtypes

import nimhdf5/datatypes
export datatypes
import nimhdf5/util
export util
import nimhdf5/h5util
export h5util
import nimhdf5/files
export files
import nimhdf5/attributes
export attributes
import nimhdf5/groups
export groups
import nimhdf5/dataspaces
# dataspaces is not exported, since the user is not supposed to have
# to deal with dataspaces by her/himself
#export dataspaces
import nimhdf5/datasets
export datasets

# if we do not export seqmath the usage of `shape` will cause compilation errors
# in the users code when procs (not templates!) that use `shape` internally!
import seqmath
export seqmath

# compression / filter support
import nimhdf5/filters
export filters

import nimhdf5/blosc_filter
export blosc_filter
