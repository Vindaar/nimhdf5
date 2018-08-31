# file which defines the shared library names for the different OS
when not declared(libname):
  when defined(Windows):
    const
      libname* = "hdf5.dll"
  elif defined(MacOSX):
    const
      libname* = "libhdf5.dylib"
  else:
    const
      libname* = "libhdf5.so"
