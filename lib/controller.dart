library controller;

import 'dart:async';
import 'model.dart';
import 'view.dart';
import 'package:logging/logging.dart';

abstract class Controller {
  View view;
  var socket;
  StreamController modelStream;
  Stream get onModelLoaded => modelStream.stream;
  Logger logger;
  Model model;
  Map properties;

  Controller() {
    modelStream = new StreamController.broadcast();
  }

  void init({Map properties, var socket});
  void loadView();
  void destroy(String templateContainerId);
}