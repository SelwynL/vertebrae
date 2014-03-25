library model_binder;

import "dart:html";
import "dart:async";
import "../model.dart";
import "attribute_binding.dart";
import "package:logging/logging.dart";

/**
 * TODO:
 * Questions -
 *      * What if an element is bound to a name that does not exist in the model?
 *        When this element changes, a new key is added to the model with the attributes name along
 *        with a key of its value. Should it be handled this way? Or should it always check first if
 *        the key exists, and never add new keys(attributes) to the model?
 *      * What if the name attribute is defined but it is an empty string?
 *
 * Extra Features -
 *      * Support formating between the model and the view, by specifying a "converter" function
 *        in the bindings. This function would be told whether it is an attribute going to the model
 *        or to the view. For example, a phone number may be stored as 2096754333 in the model, but
 *        shown as (209) 675-4333 in the view
 *      * Binding to html element attributes; setting element attributes from user specified bindings.
 */

/**
  * In the example below, the <span> and the <input> elements are both bound to the "firstname"
  * attribute. If you modified the firstName <input> element you would see the <span> automatically
  * updated because the [model] would have been updated.
  *
  *     <div id="example_container">
  *       Welcome, <span name="firstname"></span>
  *
  *       Edit your information:
  *       <input type="text" name="firstname"/>
  *     </div>
  *
  * This is the main idea behind model binding; the model's attributes (instances in the model) are
  * tied to one or more elements that present or manipulate them in the view.
  */
class ModelBinder {

  ///The different types of user input element tags
  final List<String> _inputElementTagNames = ["INPUT","SELECT","TEXTAREA",
                                              "CHECKBOX"];
  // add Radio button to list

  Model _model;
  Map<String,AttributeBinding> _attributeBindings;
  List<StreamSubscription> _bindingListeners;
  Element _rootEl;
  Element _submitButton;
  bool _requiresValidation;
  Function _validate;
  Logger _logger;
  bool get validateModel => _validateModel();

  /** Constructor **/
  ModelBinder() {
    _logger  = new Logger("ModelBinder");
  }

  /**
   *  [Event] triggered when [_model] changes, passes along the attribute that was changed. Used
   *  internally.
   */
  //Stream get _onModelChange => _modelController.stream;

  /**
   * The [model] is required, it is the model you're binding to.
   * The [rootEl] is required, is the root html [Element] containing the elements you want to bind to.
   * The [bindings] instance is optional.
   * The [options] instance is optional.
   *
   * If [bindings] IS NOT defined, then bind() will locate all of the child elements under the
   * [rootEl] that define a "name" attribute. This includes nested child elements that define the
   * "name" attribute. Each of the elements with a "name" attribute will be bound to the model's
   * attributes - the value of the element's name attribute will be used as the model's attribute
   * name.
   *
   * If [bindings] IS defined, then bind() will bind the model to all [bindings]'s elements if they
   * are children under the [rootEl] - it will NOT locate any child elements with the "name" attribute.
   * The [bindings] Map consists of a model attribute name as key and a [querySelector] parameter
   * as value:
   *
   *     <div id="example_container">
   *       <input type="text" name="address"/>
   *       <input type="text" id="city"/>
   *     </div>
   *
   *     Map bindings = {"address": "[name=address]", "city": "#city"};
   *     binder.bind(this.model, querySelector("#example_container"), bindings);
   *
   * Calling [bind] will automatically internally call the unbind() function to unbind the previous
   * model. You can reuse the same ModelBinder instance with multiple models or even [rootEl]s - just
   * be aware that all previous bindings will be removed.
   *
   * The [options] are used to set a validation method. Validation will be ran on changed fields to
   * ensure they are valid before being changed in the [model].
   */
  void bind(Model model, Element rootEl, {Map bindings, Element submitButton, Function validation}) {

    ///Check for required parameters.
    if (model == null || rootEl == null) {
      throw new NullThrownError();
    }

    /// First [unbind].
    unbind();

    _model = model;
    _rootEl = rootEl;

    /// Check which if we need to perform validation, a submit button is required for validation
    /// This validation method should return true if the value is valid and false if it is not valid.
    if (validation != null) {
      if (submitButton == null) {
        throw new NullThrownError();
      }
      _submitButton = submitButton;
      _requiresValidation = true;
      _validate = validation;
    }

    /// Check whether we initialize our bindings via user specified [bindings] or default bindings.
    if (bindings == null) {
      _attributeBindings = createDefaultAttributeBindings(_rootEl);
    } else {
      _setCustomAttributeBindings(bindings);
    }

    ///Bind model and view both ways. When the view changes, update the model, and when the model changes
    ///update the view.
    _bindModelToView();
    _bindViewToModel();

    ///Once the submit button is clicked, validate all fields once more to address fields that have
    ///not been changed.
    ///TODO: should this trigger an event if it fails. Or prevent default?
    _submitButton.onClick.listen((var event) {
      event.preventDefault();
      bool valid = _validateModel();

      if (!valid) {
        ///Don't allow the submit button in the controller to submit the data if it is not valid.
        event.stopImmediatePropagation();
        _logger.info("OnSubmit Validation Failed");
      }
    });
  }

  /**
   * Unbinds listeners from the current model that [bind] has bound to.
   * When your views are closed you should always call the unbind() function. The unbind() function
   * will un-register from the model's change events and the view's jQuery change delegate. If you
   * don't call unbind() you might end up with zombie views and ModelBinders. This is particularly
   * important for large client side applications that are not frequently refreshed.
   */
  void unbind() {
    _logger.fine("Unbinding model from view");

    ///Remove all listeners from elements.
    if (_bindingListeners != null && _bindingListeners.length > 0) {
      _bindingListeners.forEach((link) => link.cancel());
    }

    ///Revert all class attribute instances to initial usable state.
    _bindingListeners = new List();
    _attributeBindings = new Map();
    _requiresValidation = false;
    _validate = null;
    _model = null;
    _rootEl = null;
  }


  /**
   * Sets a listener on all the elements in the [_attributeBindings]. If one element is changed,
   * change the attribute in the model accordingly.
   *
   * NOTE: It is important that cyclical updates are not introduced. We can therefore not simply
   * update the model on a field change becuase of this situation:
   *
   * Imagine there are two fields in the view that are bound to the same attribute in the model,
   * a user comes along and changes one of the fields, this should trigger a change to change the
   * model, which should trigger a change to change the view to match the model again. This will
   * cause the other field to be updated on its own, however, when this field is updated, it
   * should not trigger a change to change the model, becuase that attribute has already changed.
   *
   * Two ways around:
   *  - When an attribute is changed (onChange), ensure it is different than the model's value.
   *  - Only check for a change when a field is blurred (a user click in and then out of the field)
   *    since that can't be triggered by changing the view systematically.
   */
  void _bindViewToModel() {
    ///Create listeners on elements that call _changeModel() when they are changed. Loop through
    ///[_attributeBindings] and query all selectors that are associated with an attribute.

    ///Loop through each attribute's selectors and assign listeners. Since [_attributeBindings] is
    ///a [Map] with [String] keys associated to a value of a [List] of [Map]s the internal structure
    ///looks like this:
    ///
    ///     {
    ///       "<attrName1>":[
    ///           {"selector":"<selectorValue1>"},
    ///           {"selector":"selectorValue2", "converter":"convert()"},
    ///           {"selector":"selectorValue3"},
    ///          ],
    ///       "<attrName2>":[
    ///           {"selector":"selectorValue1", "converter":"convert()"},
    ///           {"selector":"selectorValue2"}
    ///          ]
    ///     }
    ///
    ///TODO: "converter" is optional, but not implemented yet.
    Iterable attributeKeys = _attributeBindings.keys;

    for (String attribute in attributeKeys) {
      AttributeBinding attributeBinding = _attributeBindings[attribute];
      _logger.fine("AttributeBinding to: $attribute");

      for (Map element in attributeBinding.elements) {
        _logger.fine("   element:$element");

        _logger.fine("Current selector: ${element['selector']}");
        ///Query all elements with the given selector; has to be supported.
        List<Element> elements = querySelectorAll(element["selector"]);
        for (var el in elements) {

          StreamSubscription elListener = el.onChange.listen((e) {
            _logger.fine("OnChange (Key: $attribute): $el");
            var value = _extractValue(el);
            if (_requiresValidation) {
              ///Validate without using the "required" validators
              bool valid = _validate(attribute,value,el, false);
              if (valid) {
                ///Since the value is valid, change the model. Here the model will fire an event that it changed
                _model.set(attribute, value);

                ///Fire event that model has changed, pass the name of the attribute.
                //_logger.info("Model has changed.");
                //_modelController.add(attribute);

              } else {
                _logger.severe("Invalid value for $attribute: '$value' is invalid.");
              }
            } else {
              ///Change the model without validation, since validation was not specified for this instance
              ///of the [ModelBinder].
              _logger.severe("Changing the model without validation!");
              _model.set(attribute, value);
            }
          });

          _bindingListeners.add(elListener);
        }
      }
    }
  }


  /**
   * Gets the correct value from an [element].
   * NOTE: This assumes that the Element is an InputElement and has a "value" accessor. May need
   * to be fixed if we want to use this on editable divs, etc.
   */
  _extractValue(var element) {
    var value;

    if (_inputElementTagNames.contains(element.tagName)) {
      switch(element.type) {
        case "text":
        case "textarea":
          value = (element.value as String).trim();
          break;
        case "select-one":
          value = (element.selectedOptions[0].value as String).trim();
          break;
        case "checkbox":
          value = element.checked;
          break;
        default:
          value = element.value.trim();
      }
    } else {
      value = element.innerHtml.trim();
    }

    return value;
  }

  /**
   * Validate all the bound elements to each attribute in the model.
   * NOTE: This only validates the elements that allow for input. if an attribute is bound to a
   * span that just displays the attribute, it is not validated.
   */
  bool _validateModel() {

    int error = 0;

    List<Element> done = new List();

    ///Iterate through each bound attribute.
    for (String attribute in _attributeBindings.keys) {

      ///Iterate through the binding element selectors for each attribute
      List elementBindings = _attributeBindings[attribute].elements;
      for (Map binding in elementBindings) {
        if (binding.containsKey("selector")) {

          ///Iterate through elements that have that selector (mutiple elements may have the same selector.
          List elements = _rootEl.querySelectorAll(binding["selector"]);
          for (Element element in elements) {

            ///Make sure the same element is not validated more than once
            ///AND Only validate elements that allow for user input, make sure to validate with the
            ///"Required" validators
            if (!done.contains(element) && _inputElementTagNames.contains(element.tagName)) {
              bool valid = _validate(attribute, _model.get(attribute), element, true);
              if (!valid) {
                error++;
              }
              ///Signify that this element has been validated
              done.add(element);
            }
          }
        }
      }
    }

    if (error > 0) {
      return false;
    } else {
      return true;
    }
  }

  /**
   * Sets a listener on the model. If it changes, make sure to change the view.
   */
  void _bindModelToView() {

    List<String> usedSelectors;

    ///Create listener to custom event. This event is triggered when the view makes a change to the
    ///[_model] in _changeModel() and [attribute] denotes the changed attribute in the [_model].
    _model.onChange.listen((Map changeEvent) {

      String attribute = changeEvent["key"];

      _logger.fine("New model:\n$_model");

      usedSelectors = new List();
      ///Find bound elements to given attribute.
      AttributeBinding bindings = _attributeBindings[attribute];
      if(bindings == null){
        _logger.info("No bindings found for: " + attribute);
        return;
      }
      for (Map element in bindings.elements) {
        ///Find all elements attached to the given selector.
        String selector = element["selector"];
        List<Element> elements = querySelectorAll(selector);

        ///Check if the selector has already been used to update elements. This could happen due to
        ///mutiple elements being tied to the same "name" attribute, and each being stored in
        ///[AttributeBinding.elements] separately. Otherwise, set the new value for the element
        ///in the view.
        if (!usedSelectors.contains(selector)) {
          for (var el in elements) {
            ///Set the element value to the new attribute value.
            ///For user input elements, check what their type is and handle accordingly, otherwise
            ///set the innerHtml equal to the [_model] value of the attribute.
            if (_inputElementTagNames.contains(el.tagName)) {
              switch(el.type) {
                case "text":
                case "textarea":
                  el.value = (_model.get(attribute) as String).trim();
                  break;
                case "select-one":
                  int index = 0;
                  for(OptionElement option in el.options){
                    if(option.value == el.value){
                      el.selectedIndex = index;
                      break;
                    }
                    index++;
                  }
                  break;
                case "checkbox":
                  el.checked = _model.get(attribute);
                  break;
                default:
                  el.value = (_model.get(attribute) as String).trim();
              }
            } else {
              el.innerHtml = (_model.get(attribute) as String).trim();
            }
          }
          _logger.info("Element updated: $selector");
          usedSelectors.add(selector);
        } else {
          _logger.info("Element has already been updated: $selector");
        }
      }
    });
  }


  /**
   * Searches for elements with a set default attribute. Default attribute in this case is "name".
   * NOTE: This method uses the value of the default attribute as the reference to the model. So
   * ensure that the value of the default attribute corresponds accordingly.
   */
  Map<String,AttributeBinding> createDefaultAttributeBindings(Element rootEl, {String defaultAttribute: "name"}) {

    _logger.fine("Default attribute for binding is: $defaultAttribute");

    List<Element> elements;
    String name;
    Element matchedEl;
    Map elementInfo;
    AttributeBinding attributeBinding;

    Map<String, List<String>> usedSelectors = new Map();
    Map<String,AttributeBinding> bindings = new Map();

    ///Query by defaultAttribute.
    elements = rootEl.querySelectorAll("[$defaultAttribute]");

    ///Loop through all elements, ensuring to only add a single key. Add an attribute binding for
    ///each attribute found. If key already exists, add element to list of elements for that
    ///attribute binding.
    for(int index = 0; index < elements.length; index++) {

      matchedEl = elements[index];
      name = matchedEl.attributes[defaultAttribute];
      String selector = "[$defaultAttribute=$name]";
      elementInfo = {"selector": selector};

      ///Check if attribute exists in the bindings, if it doesn't create a new key and
      ///add the element to the list, if it does exist, add the element to the bound elements list.
      if(!bindings.containsKey(name)) {

        _logger.fine("Adding attribute '$name'...");

        attributeBinding = new AttributeBinding();
        attributeBinding.name = name;
        attributeBinding.elements.add(elementInfo);

        ///Add used selectors to make sure not to add multiple of the same selectors for one attribute.
        usedSelectors[name] = [selector];

        ///Add binding to attribute key.
        bindings[name] = attributeBinding;

      } else if (!usedSelectors[name].contains(selector)) {
        ///If the attribute already exists make sure the selector only gets added if the selector
        ///does not yet exist for that attribute
        _logger.info("Attribute '$name' exists: Adding additional element to bound elements.");
        bindings[name].elements.add(elementInfo);
        usedSelectors[name].add(selector);
      } else {
        _logger.fine("Selector '$selector' already exists for attribute '$name'.");
      }
    }

    return bindings;
  }

  /**
   * Converts the input bindings, which might be [String]s, [List]s, or [Map]s to an [AttributeBinding]
   * to add as a value to the attribute in [_attributeBindings]. Bindings can be specified by the
   * user in three ways:
   *
   * String
   *      ///Bindings specified with direct key/value pair, where the key is the model attribute and
   *      ///the query selector is the value represented as a string.
   *      Map bindings = {
   *                      "homeAddress": "#homeAddress",
   *                      "workAddress" : "[name=workAddress]"
   *                     };
   *
   *  Map
   *      ///Bindings specfied with attributes tied to maps, where the key is the model attribute
   *      ///and the value is a map of specific element binding options such as specifying a "selector"
   *      ///and/or a "converter".
   *      Map bindings = {
   *                      "phoneNumber": {"selector": "[name=phoneNumber]", "converter": phoneConverter},
   *                      "firstName": {"selector": "#fname"}
   *                     }
   *
   *  List
   *      ///Bindings specified with attributes tied to List's of maps, where the key is the
   *      ///attribute and the value is a list which holds multiple element binding maps (above). This
   *      ///is used to specify/bind multiple elements to a single model attribute.
   *      Map bindings = {
   *                      "phoneNumber":
   *                        [
   *                          {"selector": "[name=phoneNumber]", "converter": phoneConverter},
   *                          {"selector": "#phone"}
   *                        ],
   *                      "address":
   *                        [
   *                          {"selector": "[name=address]"},
   *                          {"selector": "[name=mailingAddress]"},
   *                          {"selector": "#displayAddress"}
   *                        ]
   */
  void _setCustomAttributeBindings(Map bindings) {

    bool validSelectors;

    ///Iterate through the provided bindings, and place them in [_attributeBindings].
    for (String attribute in bindings.keys) {
      validSelectors = true;
      var tempBinding = bindings[attribute];

      AttributeBinding attributeBinding = new AttributeBinding();
      attributeBinding.name = attribute;

      if (tempBinding is String) {
        attributeBinding.elements = [{"selector": tempBinding}];
      } else if (tempBinding is Map) {
        attributeBinding.elements = [tempBinding];
      } else if (tempBinding is List) {
        attributeBinding.elements = tempBinding;
      } else if (tempBinding is AttributeBinding) {
        attributeBinding = tempBinding;
      } else {
        throw new StateError("Error! Unsupported bindings type found: $tempBinding");
      }

      ///Check if selector is valid. Report error if no element is returned on query.
      for (Map boundElement in attributeBinding.elements) {
        String selector = boundElement["selector"];
        try {
          List<Element> els = querySelectorAll(selector);
          if (els == null || els.length == 0) {
            validSelectors = false;
            throw new StateError("Error! Invalid binding selector found: $selector ");
          }
        } catch (e,s) {
          validSelectors = false;
          throw new StateError("Error! Invalid binding selector found: $selector ");
        }
      }

      ///Only add elementBindings if selectors are valid and return at least one element.
      if (validSelectors) {
        _attributeBindings[attribute] = attributeBinding;
      }
    }
  }
}
