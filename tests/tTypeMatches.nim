import nimhdf5/datatypes

when isMainModule:

  doAssert typeMatches(float, "float64") == true
  doAssert typeMatches(float64, "float64") == true
  doAssert typeMatches(float32, "float64") == false
  doAssert typeMatches(float32, "float32") == true
  when sizeof(int) == 4:
    doAssert typeMatches(int, "int32") == true
  elif sizeof(int) == 8:
    doAssert typeMatches(int, "int64") == true
  doAssert typeMatches(bool, "bool") == true
  doAssert typeMatches(uint32, "uint32") == true
  doAssert typeMatches(float32, "int64") == false
  doAssert typeMatches(int, "float64") == false  
