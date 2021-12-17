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

  FileID* = distinct hid_t
  DatasetID* = distinct hid_t
  GroupID* = distinct hid_t
  AttributeID* = distinct hid_t
  SomeH5ObjectID* = FileID | DatasetID | GroupID | AttributeID
  DataspaceID* = distinct hid_t
  DatatypeID* = distinct hid_t
  MemspaceID* = distinct hid_t
  HyperslabID* = distinct hid_t # an identifier of a dataspace ID that is a (possibly non contiguous) view
                                # onto a full dataspace

  FileAccessPropertyListID* = distinct hid_t
  FileCreatePropertyListID* = distinct hid_t
  GroupAccessPropertyListID* = distinct hid_t
  GroupCreatePropertyListID* = distinct hid_t
  DatasetAccessPropertyListID* = distinct hid_t
  DatasetCreatePropertyListID* = distinct hid_t

#TODO: need to forbid  `=copy` or else make sure destroy isn' called twice
# on a dataspace e.g. that was copied!
# If we figure out a neat solution to this, we could introduce destructors for them.


# Since we define hid_t as a distinct type (to deal with the creation of datasets
# of type `int64` (alias for hid_t before).
# need to borrow / define comparator etc procs for it

proc `$`*(x: hid_t): string {.borrow.}
proc `$`*(x: FileID): string {.borrow.}
proc `$`*(x: DatasetID): string {.borrow.}
proc `$`*(x: GroupID): string {.borrow.}
proc `$`*(x: AttributeID): string {.borrow.}
proc `$`*(x: DataspaceID): string {.borrow.}
proc `$`*(x: DatatypeID): string {.borrow.}
proc `$`*(x: MemspaceID): string {.borrow.}
proc `$`*(x: HyperslabID): string {.borrow.}

proc `$`*(x: FileAccessPropertyListID   ): string {.borrow.}
proc `$`*(x: FileCreatePropertyListID   ): string {.borrow.}
proc `$`*(x: GroupAccessPropertyListID  ): string {.borrow.}
proc `$`*(x: GroupCreatePropertyListID  ): string {.borrow.}
proc `$`*(x: DatasetAccessPropertyListID): string {.borrow.}
proc `$`*(x: DatasetCreatePropertyListID): string {.borrow.}


## unary minus to write `-1.FileID` etc.
proc `-`*(x: hid_t): hid_t {.borrow.}
proc `-`*(x: FileID): FileID {.borrow.}
proc `-`*(x: DatasetID): DatasetID {.borrow.}
proc `-`*(x: GroupID): GroupID {.borrow.}
proc `-`*(x: AttributeID): AttributeID {.borrow.}
proc `-`*(x: DataspaceID): DataspaceID {.borrow.}
proc `-`*(x: DatatypeID): DatatypeID {.borrow.}
proc `-`*(x: MemspaceID): MemspaceID {.borrow.}
proc `-`*(x: HyperslabID): HyperslabID {.borrow.}

proc `-`*(x: FileAccessPropertyListID   ): FileAccessPropertyListID {.borrow.}
proc `-`*(x: FileCreatePropertyListID   ): FileCreatePropertyListID {.borrow.}
proc `-`*(x: GroupAccessPropertyListID  ): GroupAccessPropertyListID {.borrow.}
proc `-`*(x: GroupCreatePropertyListID  ): GroupCreatePropertyListID {.borrow.}
proc `-`*(x: DatasetAccessPropertyListID): DatasetAccessPropertyListID {.borrow.}
proc `-`*(x: DatasetCreatePropertyListID): DatasetCreatePropertyListID {.borrow.}

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
