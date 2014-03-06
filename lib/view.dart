library view;
import 'dart:async';
import 'dart:html';
import 'package:mustache/mustache.dart' as mustache;
import 'package:logging/logging.dart';

abstract class View {
  Logger logger;
  StreamController viewStream;
  Stream get onViewLoaded => viewStream.stream;
  String templateRootPath;
  String templatePath;
  String templateName;
  Map model;
  TemplateRenderer templateRenderer;
  List<View> childViews;

  View(this.model, this.templateRootPath) {
    childViews = new List<View>();
    viewStream = new StreamController.broadcast();
    templateRenderer = new TemplateRenderer();
  }
  
  void decorateModel() {
  }
  
  void render() {
    // Locate proper parent element for view.
    Element parent = querySelector('#templateContainer');
    
    // Bind model to template, load style, and append output to parent element.
    templateRenderer.renderTemplate(this.model, this.templatePath)
      .whenComplete(() {
        parent.appendHtml(templateRenderer.output);
        postRender();
        viewStream.add(templateRenderer.output);
    });
  }
  
  void postRender() {    
  }
  
  void destroy() {
    for (var childView in childViews) {
      childView.destroy();
    }
    this.childViews = null;
    
    if (templateRenderer != null) {
      templateRenderer.clear();
      this.templateRenderer = null;      
    }  
    this.model = null;
    this.templateRootPath = null;
    this.templatePath = null;
    this.templateName = null;
    querySelector('#templateContainer').innerHtml = "";
  }
  
  void openChildView({String type, String data}) {  
  }
}

/**
 * Wrapper class for Mustache, or current templating engine.
 */
class TemplateRenderer {
  
  TemplateRenderer(){
    
  }
  
  Logger _logger = new Logger("TemplateRenderer");
  Future _request;
  
  String _output; 
  String get output => _output;
  
  String _templatePath; 
  String get templatePath => _templatePath;
  
  Map _model;
  Map get model => _model;

  Future<String> renderTemplate(Map model, String templatePath) {
    this._model = model;
    this._templatePath = templatePath;
    
    _request = _getTemplate().then((template) {
      _bindModel(template);
    });
    
    return _request;
  }
  
  Future<String> _getTemplate() {    
    return HttpRequest.getString(_templatePath);
  }
  
  void _bindModel(String template) {    
    try {
      mustache.Template parsedTemplate = mustache.parse(template);
      this._output = parsedTemplate.renderString(this._model, htmlEscapeValues: false);
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