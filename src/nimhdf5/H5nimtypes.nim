# the types defined in here are strictly related to
# datatypes defined by the HDF5 library to be used
# within the wrapper of the Nim library.
# Types used in the high-level bindings are instead
# found in the datatypes.nim files

type
  herr_t* = cint
  # define hid_t as distinct in64 in order to not clash with normal `int64`
  hid_t* = distinct clonglong
  time_t* = clong
  hbool_t* = bool
  htri_t* = cint
  hsize_t* = culonglong
  hssize_t* = clonglong
  h5_stat_size_t* = clonglong
  off_t* = h5_stat_size_t


# Since we define hid_t as a distinct type (to deal with the creation of datasets
# of type `int64` (alias for hid_t before).
# need to borrow / define comparator etc procs for it

proc `$`*(x: hid_t): string {.borrow.}

proc `-`*(x: hid_t): hid_t {.borrow.}  
proc `-`*(x, y: hid_t): hid_t {.borrow.}

proc `<`*(x, y: hid_t): bool {.borrow.}
proc `<`*(x: hid_t, y: int): bool =
  result = x < y.hid_t
proc `<`*(x: int, y: hid_t): bool =
  result = x.hid_t < y
  
proc `>`*(x, y: hid_t): bool =
  ## Note: convert x, y to int64, otherwise we get a weird stack overflow when 
  ## compiling.
  ## {.borrow.} also does not work for some reason
  result = x.int64 > y.int64
proc `>`*(x: hid_t, y: int): bool =
  result = x > y.hid_t
proc `>`*(x: int, y: hid_t): bool =
  result = x.hid_t > y

proc `>=`*(x, y: hid_t): bool =
  ## Note: see comment on `>`(x, y: hid_t)
  result = x.int64 >= y.int64
proc `>=`*(x: int, y: hid_t): bool =
  result = x.hid_t >= y
proc `>=`*(x: hid_t, y: int): bool =
  result = x >= y.hid_t

proc `<=`*(x, y: hid_t): bool =
  result = x.int64 <= y.int64
proc `<=`*(x: int, y: hid_t): bool =
  result = x.hid_t <= y
proc `<=`*(x: hid_t, y: int): bool =
  result = x <= y.hid_t    
  
proc `==`*(x, y: hid_t): bool {.borrow.}
proc `==`*(x: hid_t, y: int): bool =
  result = x == y.hid_t
proc `==`*(x: int, y: hid_t): bool =
  result = x.hid_t == y

  
