import nimhdf5

## XXX: MAKE ME A PROPER TEST
type
  FadcCuts* = object
    active: bool # only a valid cut if `active`, used to indicate we had data for this FADC setting
    riseLow: float
    riseHigh: float
    fallLow: float
    fallHigh: float
    skewness: float

const File = "/tmp/test_file_bool.h5"
var h5f = H5open(File, "rw")

let data = @[FadcCuts(active: true, riseLow: 40, riseHigh: 100, fallLow: 200, fallHigh: 400, skewness: -0.8),
             FadcCuts(active: false, riseLow: 0, riseHigh: 0, fallLow: 100, fallHigh: 300, skewness: 0.0)]
var dset = h5f.create_dataset("/w_bool",
                              2,
                              FadcCuts)
dset[dset.all] = data

discard h5f.close()


h5f = H5open(File, "r")
let read = h5f["/w_bool", FadcCuts]
echo read
discard h5f.close()
