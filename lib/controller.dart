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
  Map model;
  Map properties;
  
  Controller() {
    modelStream = new StreamController.broadcast();
  }
  void init({Map properties, var socket});
  void loadView();
  void destroy();
}