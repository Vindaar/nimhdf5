# check whether blosc is available and then import and export plugin
# else we just set the ``HasBloscSupport`` variable to false
template canImport(x: untyped): untyped =
  compiles:
    import x

import macros
when not defined(noBlosc):
  # need to have these nested, because otherwise we cannot seemingly combine
  # the two
  when canImport(blosc):
    import blosc
    export blosc

    const HasBloscSupport* = true
    static:
      warning("Compiling with blosc support")
  else:
    const HasBloscSupport* = false
    static:
      warning("Compiling without blosc support")
else:
  const HasBloscSupport* = false
  static:
    warning("Compiling without Blosc support!")

when HasBloscSupport:
  import ../nimhdf5/H5nimtypes
  import ../nimhdf5/datatypes
  import ../nimhdf5/hdf5_wrapper
  import ../nimhdf5/util

  # Filter revision number, starting at 1
  const FILTER_BLOSC_VERSION* = 2 # multiple compressors since Blosc 1.3

  # Filter ID registered with the HDF Group
  const FILTER_BLOSC* = 32001

  # need malloc and free, since we allocate memory, which needs to be freed
  # by the HDF5 library
  proc malloc(size: csize): pointer {.importc: "malloc", header: "stdlib.h".}
  proc free(p: pointer) {.importc: "free", header: "stdlib.h".}

  ## Prototypes for filter function in bloscFilter.c
  proc bloscFilter(flags: cuint, cd_nelmts: cint,
                    cd_values: ptr cuint, nbytes: csize,
                    buf_size: ptr cint, buf: ptr pointer):
                      csize {.exportc: "blosc_filter", cdecl.}

  proc bloscSetLocal(dcpl, dtype, space: hid_t):
                      herr_t {.exportc: "blosc_set_local", cdecl.}

  # filter class for blosc defined here, since used in ``bloscFilter`` as well
  # as ``H5PLget_plugin_info``
  let Blosc_H5Filter = H5Z_class2_t(
    version: H5Z_class_t_vers,
    id: FILTER_BLOSC.H5Z_filter_t,
    encoder_present: 1.cuint,              # encoder_present flag (set to true)
    decoder_present: 1.cuint,              # decoder_present flag (set to true)
    name: "blosc".cstring,
    # Filter info
    can_apply: nil,            # The "can apply" callback
    set_local: cast[H5Z_set_local_func_t](bloscSetLocal), # The "set local" callback
    filter: cast[H5Z_func_t](bloscFilter)               # The filter function
  )

  template getFilter(a, b, c, d, e, f, g: untyped): untyped =
      H5Pget_filter_by_id2(a, b, c, d, e, f, g, nil)

  proc bloscSetLocal(dcpl, dtype, space: hid_t): herr_t =
    ## Filter setup.  Records the following inside the DCPL:
    ##
    ##   1. If version information is not present, set slots 0 and 1 to the filter
    ##      revision and Blosc version, respectively.
    ##
    ##   2. Compute the type size in bytes and store it in slot 2.
    ##
    ##   3. Compute the chunk size in bytes and store it in slot 3.
    var
      r: herr_t
      basetypesize: csize
      bufsize: csize
      chunkdims = newSeq[hsize_t](32)
      flags: cuint
      nelements = 8.csize
      values = newSeq[cuint](8)

    r = getFilter(dcpl, FILTER_BLOSC, addr flags, addr nelements, addr values[0], 0, nil)
    if r < 0:
      return -1

    if nelements < 4:
      nelements = 4  # First 4 slots reserved.

    # Set Blosc info in first two slots
    values[0] = FILTER_BLOSC_VERSION
    values[1] = BLOSC_VERSION_FORMAT

    let ndims = H5Pget_chunk(dcpl, 32, addr chunkdims[0])
    if ndims < 0:
      return -1
    if ndims > 32:
      raise newException(HDF5LibraryError, "bloscSetLocal failed. " &
        "Chunk rank exceeds limit")

    let typesize = H5Tget_size(dtype)
    if typesize == 0:
      return -1
    # Get the size of the base type, even for ARRAY dtypes
    let classt = H5Tget_class(dtype)
    if classt == H5T_ARRAY:
      # Get the array base component
      let super_type = H5Tget_super(dtype)
      basetypesize = H5Tget_size(super_type)
      # Release resources
      discard H5Tclose(super_type)
    else:
      basetypesize = typesize

    # Limit large typesizes (they are pretty expensive to shuffle
    #   and, in addition, Blosc does not handle typesizes larger than
    #   256 bytes).
    if basetypesize > BLOSC_MAX_TYPESIZE:
      basetypesize = 1
    values[2] = basetypesize.cuint

    # Get the size of the chunk
    bufsize = typesize
    for i in 0 ..< ndims:
      bufsize = bufsize * chunkdims[i].csize
    values[3] = bufsize.cuint

    when defined(BLOSC_DEBUG):
      debugEcho "Blosc: Computed buffer size: ", bufsize

    r = H5Pmodify_filter(dcpl, FILTER_BLOSC, flags, nelements, addr values[0])
    if r < 0:
      result = -1

    result = 1


  proc bloscFilter(flags: cuint, cd_nelmts: cint,
                    cd_values: ptr cuint, nbytes: csize,
                    buf_size: ptr cint, buf: ptr pointer):
                      csize {.exportc: "blosc_filter", cdecl.} =
    ## The filter function
    var
      outbuf: pointer
      status = 0.cint                # Return code from Blosc routines
      outbuf_size: csize
      clevel = 5.cint
      doshuffle = 1.cint             # Shuffle default
      compname = "blosclz".cstring    # The compressor by default
      cd_val_arr = cast[ptr UncheckedArray[cuint]](cd_values)

    # Filter params that are always set
    let typesize = cd_val_arr[2].csize      # The datatype size
    outbuf_size = cd_val_arr[3].csize   # Precomputed buffer guess
    # Optional params
    if cd_nelmts >= 5.cint:
      clevel = cd_val_arr[4].cint        # The compression level
    if cd_nelmts >= 6.cint:
      doshuffle = cd_val_arr[5].cint  # BLOSC_SHUFFLE, BLOSC_BITSHUFFLE
      # bitshuffle is only meant for production in >= 1.8.0
      when BLOSC_VERSION_MAJOR <= 1 and BLOSC_VERSION_MINOR < 8:
        if doshuffle == BLOSC_BITSHUFFLE:
          raise newException(HDF5LibaryError, "bloscFilter failed. " &
            "this Blosc library version is not supported.  Please update to >= 1.8")


    if cd_nelmts >= 7.cint:
      let compcode = cd_val_arr[6].cint     # The Blosc compressor used
      # Check that we actually have support for the compressor code
      let complist = blosc_list_compressors()
      let code = blosc_compcode_to_compname(compcode, addr compname)
      if code == -1.cint:
        raise newException(HDF5LibraryError, "bloscFilter failed. " &
          "this Blosc library does not have support for " &
          "the " & $compname & " compressor, but only for: " &
          $complist)

    if (flags and H5Z_FLAG_REVERSE) == 0:
      # We're compressing

      # Allocate an output buffer exactly as long as the input data if
      # the result is larger, we simply return 0. The filter is flagged
      # as optional, so HDF5 marks the chunk as uncompressed and
      # proceeds.

      outbuf_size = buf_size[].csize

      when defined(BLOSC_DEBUG):
        debugEcho "Blosc: Compress ", nbytes, " chunk w/buffer ", outbuf_size

      outbuf = malloc outbuf_size

      if outbuf.isNil:
        free outbuf
        raise newException(HDF5LibraryError, "bloscFilter failed. " &
          "Can't allocate compression buffer")

      discard blosc_set_compressor(compname)
      status = blosc_compress(clevel, doshuffle, typesize, nbytes,
                              buf[], outbuf, nbytes)
      if status < 0:
        free outbuf
        raise newException(HDF5LibraryError, "bloscFilter failed. " &
          "Blosc compression error")

    else:
      # We're decompressing
      # declare dummy variables
      var
        cbytes: csize
        blocksize: csize

      # Extract the exact outbuf_size from the buffer header.
      #
      # NOTE: the guess value got from "cd_values" corresponds to the
      # uncompressed chunk size but it should not be used in a general
      # cases since other filters in the pipeline can modify the buffere
      #  size.
      #
      blosc_cbuffer_sizes(buf[], addr outbuf_size, addr cbytes, addr blocksize)

      when defined(BLOSC_DEBUG):
        debugEcho "Blosc: Decompress ", nbytes, " chunk w/buffer ", outbuf_size

      outbuf = malloc outbuf_size

      if outbuf == nil:
        free outbuf
        raise newException(HDF5LibraryError, "bloscFilter failed. " &
          "Can't allocate decompression buffer")

      status = blosc_decompress(buf[], cast[pointer](outbuf), outbuf_size)
      if status <= 0:    # decompression failed
        free outbuf
        raise newException(HDF5LibraryError, "bloscFilter failed. " &
          "Blosc decompression error")

    # compressing vs decompressing
    if status != 0:
      free buf[]
      buf[] = outbuf
      buf_size[] = outbuf_size.cint
      return status.csize  # Size of compressed/decompressed data

    result = 0

  # Registers the filter with the HDF5 library
  # Register the filter, passing on the HDF5 return value
  proc registerBlosc*(version: var string, date: var string):
                     cint {.exportc: "register_blosc", cdecl.} =

    var filter_class = Blosc_H5Filter

    result = H5Zregister(addr filter_class)
    if result < 0:
      raise newException(HDF5LibraryError, "registerBlosc failed. " &
        "Can't register Blosc filter")

    # constants defined in blosc.nim
    version = BLOSC_VERSION_STRING
    date = BLOSC_VERSION_DATE

    result = 1 # lib is available

  proc H5PLget_plugin_type*(): H5PL_type_t {.exportc: "H5PLget_plugin_type", cdecl.} =
    result = H5PL_TYPE_FILTER

  proc H5PLget_plugin_info*(): H5Z_class2_t {.exportc: "H5PLget_plugin_info", cdecl.} =
    result = Blosc_H5Filter


  # finally register the blosc plugin with the HDF5 library
  let available = if H5Zfilter_avail(FILTER_BLOSC) == 1: true else: false
  if not available:
    var
      version: string
      date: string
    let r = registerBlosc(version, date)
    if r >= 0:
      assert H5Zfilter_avail(FILTER_BLOSC) == 1

      withDebug:
        debugEcho "Registered Blosc."
        debugEcho "\tversion: " & $version
        debugEcho "\tdate: " & $date
    else:
      echo "Warning: could not register Blosc plugin with library!"
