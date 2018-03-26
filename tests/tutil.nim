import nimhdf5

# some hdf5 independent tests for the util module
# currently only for newSeq and reshape procs

when isMainModule:

  assert newSeqOf2D[int](@[9, 9]).shape == @[9, 9]
  assert newSeqOf2D[int]([9, 9]).shape == @[9, 9]  

  assert newSeqOf3D[int](@[2, 2, 5]).shape == @[2, 2, 5]
  assert newSeqOf3D[int](@[5, 5, 5]).shape == @[5, 5, 5]
  assert newSeqOf3D[int](@[10, 5, 15]).shape == @[10, 5, 15]    
  assert newSeqOf3D[int]([2, 2, 5]).shape == @[2, 2, 5]

  let
    s1 = newSeq[int](81)
    s2 = newSeq[int](4 * 5 * 6)
    s3 = newSeq[float](10 * 10 * 10)
  assert s1.reshape([9, 9]).shape == @[9, 9]
  assert s1.reshape2D(@[9, 9]).shape == @[9, 9]
  
  assert s2.reshape([4, 5, 6]).shape == @[4, 5, 6]
  assert s2.reshape3D(@[4, 5, 6]).shape == @[4, 5, 6]

  assert s3.reshape([10, 10, 10]).shape == @[10, 10, 10]
  assert s3.reshape3D(@[10, 10, 10]).shape == @[10, 10, 10]
  
