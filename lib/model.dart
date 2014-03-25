library model;

import 'dart:html';
import 'dart:async';
import 'src/model_binder.dart';
import 'package:logging/logging.dart';

abstract class Model {

  Map _data;
  Logger logger;
  ModelBinder _binder;
  StreamController _changeController;


  /**
   * New model's are created from a flat map.
   */
  Model({Map data}) {

    ///If no data, or an empty map, is passed in, add a map with defult values to the model.
    if (data == null || data.length == 0) {
      data = setDefaultModelValues();
    }

    /// Even though child classes should initialize their own logger: A default is set incase they don't.
    logger = new Logger("ModelWithoutInitializedLogger");

    _binder = new ModelBinder();
    _changeController = new StreamController.broadcast();
    _data = data;
  }

  /**
   * Default values for a new model when no [Map] has been passed into.
   */
  Map setDefaultModelValues();

  /**
   * Notifies listeners of a change event to the [Model].
   */
  Stream get onChange => _changeController.stream;

  /**
   * Bind model to a view.
   */
  void bind(Element rootEl, {Map bindings, Element submitButton, Function validation}) {
    _binder.bind(this, rootEl, bindings: bindings, submitButton: submitButton, validation: validation);
  }

  /**
   * Unbind model from view.
   */
  void unbind() {
    _binder.unbind();
  }

  /**
   * Find all elements under [rootEl] which have the [elementAttribute]. By default this is the "name"
   * attribute, but can be set with the named parameter to another attribute.
   */
  Map createDefaultAttributeBindings(Element rootEl, {String elementAttribute: "name"}) {
    return _binder.createDefaultAttributeBindings(rootEl, defaultAttribute: elementAttribute);
  }

  /**
   * Returns the entire internal data structure of the [Model].
   */
  Map getDataSet() {
    return _data;
  }

  /**
   * Returns the data value associated with the specified [key].
   */
  dynamic get(String key) {
    if (key == null || key == "") {
      logger.severe("Can not get value for NULL key");
      return null;
    } else if (!_data.containsKey(key)) {
      logger.severe("Can not get value for '$key', key does not exist");
      return null;
    } else {
      logger.fine("Retrieving '$key' from model");
      return _data[key];
    }
  }

  /**
   * Takes a [Map] and sets it equal to [Model._data].
   */
  bool initializeModelFromMap(Map data) {
    if (data != null) {
      _data = data;
      return true;
    }

    return false;
  }

  /**
   * Removes the specified [key] from the [Model]. Fires an [onChange] event.
   * Returns true on success.
   */
  bool delete(String key) {
    if (key == null || key == "") {
      logger.severe("Can not remove NULL key");
      return false;
    } else {
      _data.remove(key);
      _changeController.add({"key":"$key", "change":"delete"});

      logger.fine("Deleted '$key' from model");
      return true;
    }
  }

  /**
   * Updates the specified [key]'s value, OR adds the key if it does not exist.
   * Fires an [onChange] event.
   * Returns true on success.
   */
  bool set(String key, dynamic value) {
    if (key == null || key == "") {
      logger.severe("Can not set value '${value}' for NULL key");
      return false;

    } else {

      String change;
      if (_data.containsKey(key)) {
        change = "edit";
      } else {
        change = "add";
      }

      _data[key] = value;

      ///Fire an event that states whether the key was added or edited.
      Map changeReport = {"key":"$key", "change":"$change"};
      _changeController.add(changeReport);

      logger.fine("Set '$key' equal to '$value': $change");
      return true;
    }
  }

  String toString() {
    return _data.toString();
  }
}
