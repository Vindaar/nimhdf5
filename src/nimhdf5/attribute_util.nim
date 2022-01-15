import datatypes, attributes, tables

import json
func `%`(c: char): JsonNode = % $c # for `withAttr` returning a char
iterator attrsJson*(attrs: H5Attributes, withType = false): (string, JsonNode) =
  ## yields all attribute keys and their values as `JsonNode`. This way
  ## we can actually return all values to the user with one iterator.
  ## And for attributes the variant object overhead does not matter anyways.
  attrs.read_all_attributes
  for key, att in pairs(attrs.attr_tab):
    attrs.withAttr(key):
      if not withType:
        yield (key, % attr)
      else:
        yield (key, %* {
          "value" : attr,
          "type" : att.dtypeAnyKind
        })
    att.close()

iterator attrsJson*[T: H5File | H5Group | H5DataSet](h5o: T, withType = false): (string, JsonNode) =
  for key, val in attrsJson(h5o.attrs, withType = withType):
    yield (key, val)

proc attrsToJson*[T: H5Group | H5DataSet](h5o: T, withType = false): JsonNode =
  ## returns all attributes as a json node of kind `JObject`
  result = newJObject()
  for key, jval in h5o.attrsJson(withType = withType):
    result[key] = jval
