# the types defined in here are strictly related to
# datatypes defined by the HDF5 library to be used
# within the wrapper of the Nim library.
# Types used in the high-level bindings are instead
# found in the datatypes.nim files

type
  herr_t* = cint
  # define hid_t as distinct in64 in order to not clash with normal `int64`
  hid_t* = distinct clonglong
  ## NOTE: We define `time_t` by hand from `time.h` because using a definition based on
  ## `clong` is flawed. `clong` is 8 bytes on Linux but only 4 bytes on Winodws. That leads
  ## to mismatches in the `sizeof` of objects that contain `time_t` causing hard to understand
  ## stack corruption bugs! Therefore we just pretend it's an object despite it actually being
  ## an integer type. That is to make sure Nim doesn't mess up the size. `time_t` is 8 bytes
  ## on Windows *and* Linux.
  time_t* {.header: "<time.h>", importc: "time_t".} = object
  hbool_t* = bool
  htri_t* = cint
  hsize_t* = culonglong
  hssize_t* = clonglong
  h5_stat_size_t* = clonglong
  off_t* = h5_stat_size_t

#TODO: need to forbid  `=copy` or else make sure destroy isn' called twice
# on a dataspace e.g. that was copied!
# If we figure out a neat solution to this, we could introduce destructors for them.

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
