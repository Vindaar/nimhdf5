import nimhdf5
import os

proc main() =

  if paramCount() < 1:
    quit()
  let file = paramStr(1)

  echo "Waiting..."
  sleep(3000)
  echo "Opening file..."
  var h5f = H5file(file, "rw")
  echo "Visiting file..."
  h5f.visit_file
  h5f.printOpenObjects
  echo "Waiting..."
  sleep(5000)
  discard h5f.close()

  # running this on CalibrationRuns.h5
  # size: 30GB
  # outputs:
  # Visiting file...
  #        objects open:
  #       	 files open: 1
  #       	 dsets open: 10472
  #       	 groups open: 1236
  #       	 types open: 0
  #       	 attrs open: 4312
  # and uses about 300MB just to keep the file open!!!
  # TODO: change visit_file to only read dataset and group information
  # but not open them!

when isMainModule:
  main()
