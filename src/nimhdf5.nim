import tables
import os,ospaths
import typeinfo
import typetraits
import sequtils
import strutils
import options
import future
import algorithm
#import seqmath

# NOTE:
# a short note on naming convention:
# The idea originally was to use snake_case for all procedures, which
# are usable for users of this library, while using camelCase for
# all internal (although sometimes exported `*` procedures) procedures.
# At the moment however, unfortunately this is not quite the case.
# (see TODO below)

# simple list of TODOs
# TODO:
#  - CHECK: does opening an dataset in a file, and trying to write a larger
#    dataset to it than the one currently in the file work? Does not seem to
#    be the case, but I didn't t see any errors either?!
#  - add iterators for attributes, groups etc..!
#  - add `contains` proc to check for elements in file / group (-> in, notin)
#  - add proc to delete dataset or group (this is especially needed for the case
#    in which we wish to rewrite a fixed size dataset with a different size!
#  - add ability to write arraymancer.Tensor (properly)
#  - add a lot of safety checks
#  - fix up naming convention of procs.
#    either default to:
#    - internal procs camelCase, external snake_case
#      external use of snake_case would reflect usage of HDF5 C API as well as h5py
#    or simply switch everything to either camelCase or snake_case. In this case
#    snake_case seems the reasonable choice to keep similar API calls as h5py
#  - CLEAN UP and refactor the code! way too long in a single file by now...

# now import / include the relevant pieces of the library
import nimhdf5/hdf5_wrapper
#include nimhdf5/H5nimtypes
import nimhdf5/H5nimtypes
export H5nimtypes

# TODO: instead of exporting everything from each module, we should
# instead only export the public fields of the types for example!

import nimhdf5/datatypes
# datatypes need to be exported. No, only parts of it, which can be
# exported from the specific submodules, e.g. groups, datasets etc.
export datatypes
import nimhdf5/util
# need to export util for shape and flatten
export util
import nimhdf5/h5util
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

# compression / filter support
import nimhdf5/filters
export filters

# finally import and export seqmath, so that calls to procs, which use
# e.g. `shape` or `flatten` internally do not fail, if the calling module
# has not imported seqmath itself
import seqmath
export seqmath
