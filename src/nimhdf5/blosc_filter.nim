# check whether blosc is available and then import and export plugin
# else we just set the ``HasBloscSupport`` variable to false

import macros
when defined(blosc):
  template canImport(x: untyped): untyped =
    compiles:
      import x

  # need to have these nested, because otherwise we cannot seemingly combine
  # the two
  when canImport(blosc):
    const HasBloscSupport* = true
    static:
      warning("Compiling with blosc support")
  else:
    const HasBloscSupport* = false
    static:
      warning("Compiling without blosc support, because the `blosc` library cannot be found.")
else:
  const HasBloscSupport* = false
  static:
    warning("Compiling without Blosc support!")

when HasBloscSupport:
  import blosc
  export blosc
  import blosc_filter/blosc_plugin
  export blosc_plugin
