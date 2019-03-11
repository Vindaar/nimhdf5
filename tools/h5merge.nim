import nimhdf5
import docopt
import strutils, options, os

## A simple tool, which does nothing else than merging two given H5 files

# get date using `CompileDate` magic
const currentDate = CompileDate & " at " & CompileTime

const docTmpl = """
Built on: $#
H5Merge. Merge two H5 files into one. The output file *must not* exist!

Usage:
  h5merge <file1> <file2> [--out=<outfile>] [options]
  h5merge -h | --help
  h5merge --version

Options:
  --out=<outfile>    Optional filename for the merged output file
  -h --help          Show this help
  --version          Show version.

"""
const doc = docTmpl % [currentDate]

proc copyIntoOut(h5f, h5out: var H5FileObj,
                 start = "/"): bool =
  # first copy all groups in the root group
  for group in items(h5f, start, depth = 1):
    # before copying check whether this group exists in
    # target. If so, recurse on group
    if group.name in h5out:
      echo "Exists, copying from group instead"
      result = copyIntoOut(h5f, h5out, group.name)
    else:
      result = h5f.copy(group, h5out = some(h5out))
    doAssert result

  # then copy all datasets in the root group
  var root = h5f[start.grp_str]
  for obj in root:
    if obj.name notin h5out:
      result = h5f.copy(obj, h5out = some(h5out))
      doAssert result
    else:
      echo "Skipping dataset: ", obj.name, " already exists in file!"

proc main =
  let args = docopt(doc)

  var outfile = "merged.h5"
  if $args["--out"] != "nil":
    outfile = $args["--out"]

  if outfile.fileExists:
    echo "Output file already exists! Aborting."
    return

  var
    h5in1 = H5file($args["<file1>"], "r")
    h5in2 = H5file($args["<file2>"], "r")
    h5out = H5file(outfile, "rw")

  var success = copyIntoOut(h5in1, h5out)
  doAssert success
  success = copyIntoOut(h5in2, h5out)
  doAssert success

  var err = h5in1.close()
  doAssert err >= 0
  err = h5in2.close()
  doAssert err >= 0
  err = h5out.close()
  doAssert err >= 0

when isMainModule:
  main()
