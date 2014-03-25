library attribute_binding;

import "package:logging/logging.dart";

/**
 * Holds all the Element's querySelectors that are bound to a single attribute name.
 */
class AttributeBinding {

  ///Name of the attribute.
  String name;

  ///Logger
  Logger _logger;

  /**
   * This is a list of [Map]s which hold all necessary inforation for each of the matching [Element]s.
   * An example looks like this:
   *     name = "firstname"
   *     boundElements = [{"selector":"[name=firstname]"},{"selector":"#welcomeName"},{"selector":"#title"}]
   *
   * TODO: Eventually the map can hold references to converter functions which can be used to modify
   *  the structure or presentation of data between the model and view. It would be an added key for
   *  each map:
   *     name = "firstname"
   *     elements = [{"selector":"[name=firstname]"},{"selector":"#welcomeName", "converter": "formalize"}]
   */
  List elements;

  /**
   * Constructor initializes [boundElements] with new [List].
   */
  AttributeBinding() {
    elements = new List<Map<String,String>>();
    _logger = new Logger("AttributeBinding");
  }

  /**
   * Add [selector] to attribute.
   */
  bool addSelector(String selector) {

    if (selector != null && selector != "") {
      elements.add({"selector": selector});
      _logger.fine("Added selector: $selector");
      return true;
    } else {
      _logger.severe("Can not add null or empty selector");
      return false;
    }
  }

  /**
   * Remove [selector] from attribute.
   */
  bool removeSelector(String selector) {

    if (selector != null && selector != "") {
      for (int i=0; i < elements.length; i++) {
        Map element = elements[i];
        if (element["selector"] == selector) {
          elements.removeAt(i);
          _logger.fine("Removed selector: $selector");
          return true;
        }
      }
    }
      _logger.severe("Can not remove selector because '$selector' can not be found");
      return false;
  }

  /**
   * A [converter] can only be added when a specific [selector] for that element is specified.
   */
  bool addConverter(String selector, Function converter) {

    if (converter != null && selector != null && selector != "") {
      for (int i=0; i < elements.length; i++) {
        Map element = elements[i];
        if (element["selector"] == selector) {
          element["converter"] = converter;
          _logger.fine("Added converter $converter to selector: $selector");
          return true;
        }
      }
    }

    _logger.severe("Converter ($converter) not added because '$selector' cannot be found.");
    return false;
  }

  /**
   * Specify which [selector] you wish to remove the [converter] from.
   */
  bool removeConverter(String selector, Function converter) {

    if (converter != null && selector != null && selector != "") {
      for (int i=0; i<elements.length; i++) {
        Map element = elements[i];
        if (element["selector"] == selector) {
          if (element.containsKey("converter") && element["converter"] == converter) {
            element.remove("converter");
            _logger.info("Removed converter $converter to selector: $selector");
            return true;
          }
        }
      }
    }

    _logger.severe("Converter ($converter) not removed because '$selector' cannot be found.");
    return false;
  }

  /**
   * To string method for testing and logging purposes.
   */
  @override
  String toString() {

    String string = "[";

    for (int i=0; i < elements.length; i++) {
      Map element = elements[i];

      if (i != 0) {
        string += ",$element";
      } else {
        string += "$element";
      }
    }

    string += "]";

    return string;
  }
}
