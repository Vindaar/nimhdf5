
import H5public
when defined(DEBUG_HDF5):
  echo "Initializing HDF5 library to determine datatypes and set variables accordingly..."
discard H5open()
