library controller;

import 'dart:async';
import 'package:logging/logging.dart';
import 'view.dart';

abstract class Controller {
  View view;
  var socket;
  StreamController modelStream;
  Stream get onModelLoaded => modelStream.stream;
  Logger logger;
  Map _model;
  get model => _model;
  set model(Map value) => _model = value;
  Map properties;
  
  Controller() {
    modelStream = new StreamController.broadcast();
  }
  
  void init({Map properties, var socket});
  void loadView();
  void destroy(String templateContainerId);
}