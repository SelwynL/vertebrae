library view;
import 'dart:async';
import 'dart:html';
import 'model.dart';
import 'package:mustache/mustache.dart' as mustache;
import 'package:logging/logging.dart';

abstract class View {
  Logger logger;
  StreamController viewStream;
  Stream get onViewLoaded => viewStream.stream;
  String templateRootPath;
  String templatePath;
  String templateName;
  Model model;
  TemplateRenderer templateRenderer;
  List<View> childViews;

  View(this.model) {
    childViews = new List<View>();
    viewStream = new StreamController.broadcast();
    templateRenderer = new TemplateRenderer();
  }

  void decorateModel() {
  }

  void render(String parentId) {
    // Locate proper parent element for view.
    Element parent = querySelector("#" + parentId);
    if(parent == null){
      return;
    }

    // Bind model to template, load style, and append output to parent element.
    templateRenderer.renderTemplate(this.model.getDataSet(), this.templatePath)
      .whenComplete(() {
        if(templateRenderer == null){
          return;
        }
        // parent.appendHtml(templateRenderer.output);
        parent.appendHtml(templateRenderer.output);
        postRender();
        viewStream.add(templateRenderer.output);
    });
  }

  void postRender() {
  }

  void destroy(String templateContainerId) {
    for (var childView in childViews) {
      childView.destroy("#" + templateContainerId);
    }
    this.childViews = null;

    if (templateRenderer != null) {
      templateRenderer.clear();
      this.templateRenderer = null;
    }
    this.model = null;
    this.templatePath = null;
    this.templateName = null;
    this.viewStream = null;

    DivElement templateContainer = querySelector("#" + templateContainerId);
    if(templateContainer == null){
      logger.fine("Template Container not found: " + templateContainerId);
      return;
    }
    templateContainer.innerHtml = "";
  }
}

/**
 * Wrapper class for Mustache, or current templating engine.
 */
class TemplateRenderer {

  TemplateRenderer(){
    if (_rootTemplatePath == null) {
      throw new Exception("Please call static .configure of TemplateRenderer before using.");
    }
  }

  Logger _logger = new Logger("TemplateRenderer");
  Future _request;

  String _output;
  String get output => _output;

  String _templatePath;
  String get templatePath => _templatePath;

  Map _model;
  Map get model => _model;

  static String _rootTemplatePath = "";
  static Map _cache = new Map();

  static void configure(String rootTemplatePath) {
    TemplateRenderer._rootTemplatePath = rootTemplatePath;
  }

  Future<String> renderTemplate(Map model, String templatePath) {
    this._model = model;
    this._templatePath = templatePath;

	if (!_cache.containsKey(_templatePath)) {
      _request = _getTemplate().then((template) {
        _cache[_templatePath] = template;
        _bindModel(template);
        _output = _output.replaceAll('&#x2F;', '/');
      }).catchError((error) {
        _logger.severe(error.toString());
      });
    } else {
      _request = new Future.sync(() => _bindModel(_cache[_templatePath]));
      _output = _output.replaceAll('&#x2F;', '/');
    }

    return _request;
  }

  Future<String> _getTemplate() {
    return HttpRequest.getString(_rootTemplatePath + _templatePath);
  }

  void _bindModel(String template) {
    try {
      mustache.Template parsedTemplate = mustache.parse(template);
      this._output = parsedTemplate.renderString(this._model);
    } catch (e) {
      _logger.severe("Template Parsing Error: ${e.toString()}");
    }
  }

  void clear() {
    _request = null;
    _model = null;
    _templatePath = null;
    _output = null;
  }
}