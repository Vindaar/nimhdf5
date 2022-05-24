import nimhdf5, sequtils

when isMainModule:

  block ShapeAndSeq:
    doAssert newSeqOf2D[int](@[9, 9]).shape == @[9, 9]
    doAssert newSeqOf2D[int]([9, 9]).shape == @[9, 9]

    doAssert newSeqOf3D[int](@[2, 2, 5]).shape == @[2, 2, 5]
    doAssert newSeqOf3D[int](@[5, 5, 5]).shape == @[5, 5, 5]
    doAssert newSeqOf3D[int](@[10, 5, 15]).shape == @[10, 5, 15]
    doAssert newSeqOf3D[int]([2, 2, 5]).shape == @[2, 2, 5]

    let
      s1 = newSeq[int](81)
      s2 = newSeq[int](4 * 5 * 6)
      s3 = newSeq[float](10 * 10 * 10)
    doAssert s1.reshape([9, 9]).shape == @[9, 9]
    doAssert s1.reshape2D(@[9, 9]).shape == @[9, 9]

    doAssert s2.reshape([4, 5, 6]).shape == @[4, 5, 6]
    doAssert s2.reshape3D(@[4, 5, 6]).shape == @[4, 5, 6]

    doAssert s3.reshape([10, 10, 10]).shape == @[10, 10, 10]
    doAssert s3.reshape3D(@[10, 10, 10]).shape == @[10, 10, 10]


  block Format:
    doAssert "foo".formatName() == "/foo"
    doassert "foo//".formatName() == "/foo"
    doAssert "/foo".formatName() == "/foo"
    doAssert "/foo/bar".formatName() == "/foo/bar"
    doAssert "/foo/bar/".formatName() == "/foo/bar"
    doAssert "/foo//bar/".formatName() == "/foo/bar"
    doAssert "/foo//bar/\n".formatName() == "/foo/bar"
