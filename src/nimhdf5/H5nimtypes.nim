# the types defined in here are strictly related to
# datatypes defined by the HDF5 library to be used
# within the wrapper of the Nim library.
# Types used in the high-level bindings are instead
# found in the datatypes.nim files

type
  herr_t* = cint
  hid_t* = clonglong
  time_t* = clong
  hbool_t* = bool
  htri_t* = cint
  hsize_t* = culonglong
  hssize_t* = clonglong
  h5_stat_size_t* = clonglong
  off_t* = h5_stat_size_t
