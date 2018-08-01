# this file contains utility procs, which are used all over
# the higl-level bindings of this library. They are mostly related
# to convenience procs, which are missing from the Nim standard
# library, e.g. to get the shape of a nested sequence.
# Others are more specific, but still not restricted to the H5
# library, e.g. formatName(), which formats a string handed to
# the `[]`(H5FileObj) proc to a format suitable for parsing.
# read: any proc, whose understanding does not require knowledge
# of the H5 library (although the purpose of the function might)
# and does not make use of any datatypes defined for H5 interop.

import strutils
import algorithm
import sequtils

template withDebug*(actions: untyped) =
  ## a debugging template, which can be used to e.g. output
  ## debugging information in the HDF5 library. The actions given
  ## to this template are only performed, if the
  ## -d:DEBUG_HDF5
  ## compiler flag is set.
  when defined(DEBUG_HDF5):
    actions

proc formatName*(name: string): string =
  # this procedure formats a given group / dataset namy by prepending
  # a potentially missing root / and removing a potential trailing /
  # do this by trying to strip any leading and trailing / from name (plus newline,
  # whitespace, if any) and then prepending a leading /
  result = "/" & strip(name, chars = ({'/'} + Whitespace + NewLines))
