library orchestrator;

import 'controller.dart';
import 'router.dart';
import 'package:logging/logging.dart';

/**
 * Manages all application controllers. Tells them when to render and when to reap.
 *
 * The parameters are based off the url and are represented in the same order of appearance as a list.
 * The [UrlPattern]
 *      new UrlPattern(r'/page1/([a-zA-Z]+)/([0-9]+)')
 * will match a url like this: "www.example.com/page1/view/78654" Whose [parameters] are
 * represented as follows:
 *      ["page1","view","78654"]
 */
abstract class Orchestrator {

  Controller currentController;
  
  Orchestrator() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
    });

  }
  
  /**
   * Must initialize a new [Router] instance with a default route and [Router.addRoute]'s.
   * Usage of hash is added automatically based on browser support/needs. It should be possible to
   * map multiple urls to a single controller if needed.
   */
  void initialize();

  /**
   * Invokes the [_currentController]'s [BaseController.destroy] method. Then dereferences the
   * [_currentController].
   */
  void reapView() {
    if (currentController != null) {
      ///Reap current view, destroy controller.
      currentController.destroy();

      ///Remove [_currentController].
      currentController = null;
    }
  }

  /**
   * Initializes a new [BaseController] instance specific to the page request via the url.
   */
  void marshalController(String identifier, Controller newController, 
                         Map aProperties, var socketConnection) {
    ///Initialize new [BaseController] instance.
    currentController = newController;
    currentController.onModelLoaded.listen((model) {
      currentController.loadView();
    });
    currentController.init(properties: aProperties, socket: socketConnection);    
  }

  /**
   * Remove the controller identifier from the parameters. Make sure the identifier's name is the
   * same as it appears in the urls, otherwise this won't work.
   */
  List removeControllerIdentifier(String controllerID, List parameters) {
    if (parameters != null) {
      parameters.remove(controllerID);
    }
    return parameters;
  }
}