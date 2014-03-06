library router;

import "dart:html";
import 'package:logging/logging.dart';
part "src/url_pattern.dart";

/**
 * Instance to store the method used to marshal a new controller. It returns the
 * parsed parameters passed in from the url.
 */
typedef Route(List parameters);


/**
 * Handles all browser URL path navigation events. Also handles all [AnchorElement] click
 * events for internal navigation links. Determines the correct controller and necessary parameters
 * to invoke a controller instance for the given url/link.
 *
 * Note: "path" denotes all elements after the host in a url.
 *
 */
class Router {

  final bool _useHashChange;

  Logger _logger = new Logger("Router");
  Map<UrlPattern, Route> _routes;
  bool _listenerOn;
  Route _defaultRoute;
  UrlPattern _defaultPath;
  bool _defaultRouteSet;


  /** Accessors **/
  Map get routes => _routes;
  bool get isListening => _listenerOn;
  bool get defaultRouteSet => _defaultRouteSet;
  Route get defaultController => _defaultRoute;
  UrlPattern get defaultPath => _defaultPath;

  /**
   * Contructor with ternary operator to set [_useHash] to determine browser support
   * for HTML5 [History] API. Constructor uses something called an "initializer list"
   * because final fields must be set before the constructor body is run.
   *
   * Constructor sets the [_defaultRoute] and [_defaultPath]. These can not be null, but may
   * later be overridden by setting the "defaultRoute" flag to "true" in the [addRoute] method:
   *     addRoute(loginUrl, login, defaultRoute:true);
   *
   * Ternary operation presented as if statement:
   *     if (useHash != null)
   *       _useHashChange = useHash;
   *     else
   *       _useHashChange = History.supportState;
   */
  Router(Map defaultRoute, {List<Map> routes, bool useHash}) :
    _useHashChange = useHash != null ? useHash : !History.supportsState,
    _listenerOn = false,
    _routes = new Map()
  {
    if (defaultRoute != null) {
      addRoute(defaultRoute["route"], defaultRoute["path"], defaultRoute:true);
    } else {
      throw new NullThrownError();
    }

    if (routes != null) {
      for (Map route in routes) {
        addRoute(route["route"], route["path"]);
      }
    }

    if (_useHashChange) {
      ///Remove hash
      String path = (window.location.hash).replaceFirst("#", "");
      _handleRoute(path);
    }

    _logger.info("Router initialized - UseHashChange:$_useHashChange");
  }


  /**
   * Adds a method to [_routes] that will be invoked to marshal a new controller
   * instance when the [path] is encountered in a URL. If default flag is set initialize
   * [_defaultRoute] and [_defaultPath] with [route] and [path] respectively, overwrite it if default
   * route already exists.
   */
  bool addRoute(Route route, UrlPattern path, {bool defaultRoute}) {

    if (route != null && path != null) {

      ///Set [_defaultRoute] and [_defaultPath].
      if (defaultRoute == true) {
        if (_defaultRouteSet == true) {
          _logger.warning('Only one route can be the default! Current default route will be overwritten');
        }
        if (route != null && path != null) {
          _defaultRoute = route;
          _defaultPath = path;
          _defaultRouteSet = true;
        } else {
          _logger.warning("Default Route Not Added...");
          return false;
        }
        _logger.fine("Default Route Added - $path");
      }

      ///Add route, even if it is a default route, it should also be a regular route in the
      ///[_routes] collection.
      _logger.fine("Route Added - $path");
      _routes[path] = route;
      return true;
    }

    _logger.warning("Route $path Not Added...");
    return false;
  }


  /**
   * Listens for history events and invokes the router. On older
   * browsers the [window.onhashChange] event is used instead.
   */
  void listen() {
    if (_listenerOn) {
      throw new StateError('Listen should ONLY be called once.');
    }
    _listenerOn = true;
    _logger.fine("Router is listening...");

    ///If the browser does not support [History] check for changes to the location hash.
    if (_useHashChange) {
      window.onHashChange.listen((_) {
        ///Remove hash
        String path = (window.location.hash).replaceFirst("#", "");
        _logger.fine('onHashChange - loadController($path)');
        _handleRoute(path);
      });
    } else {
      window.onPopState.listen((_) {
        String path = window.location.pathname;
        _logger.fine('onPopState - loadController($path)');
        _handleRoute(path);
      });
    }

    /**
     * Listener handles internal navigation link elements that contain the "asc-nav"
     * attribute set to "true" Below is an example url:
     *
     *   <a href="/demographics/view/1234" asc-nav="true" title="Demographics">Demographics</a>
     **/
    window.onClick.listen((e) {
      if (e.target is AnchorElement) {
        AnchorElement anchor = e.target;

        bool internal = (anchor.host == window.location.host);
        bool nav =
             (anchor.getAttribute("asc-nav") != null) &&
             (anchor.getAttribute("asc-nav") == "true")
             ? true : false;

        if (internal && nav) {
          e.preventDefault();

          String hash = anchor.hash;
          String path = anchor.pathname;
          String title = anchor.title;

          _logger.fine("Link Clicked - hash: $hash");
          _logger.fine("Link Clicked - pathname: ${anchor.pathname}");
          handleLink("$path$hash", anchor.title);

        } else if (internal && !nav) {
          _logger.fine("Internal Link Executed, but not handled by router: ${anchor.host}${anchor.pathname}");
        } else {
          _logger.fine("external Link Executed: ${anchor.host}${anchor.pathname}");
        }
      }
    });
  }

  /**
   * Uses the browser compatible method to update the url. HTML5 browsers use history.pushState() and
   * other's, that do not support [History], use location.assign()
   */
  void _updateLocationUrl(String path, String title) {

    _logger.fine("UpdateLocationUrl - $path , $title");

    ///Ensure title is not null.
    if (title == null) {
      title = "";
    }

    ///Use the browser supported method for updating the title and url.
    if (_useHashChange) {
      HtmlDocument document = window.document;
      //window.location.assign(path);
      window.location.hash = path;
      document.title = title;
    } else {
      window.history.pushState(null, title, path);
    }
  }

  /**
   * Matches the [path] to a [Route]. Will invoke the correct [Route] instance in
   * [_routes] based on the [path].
   *
   * NOTE: This method only routes direct browser input urls, not internal navigation links
   *   within the application, therefore it does NOT need to update the Url or browser history
   *   via [_updateLocationUrl]. Unless the route is bad/invalid, then the default route is executed
   *   which is pushed to the browserhistory.
   */
  void _handleRoute(String path) {

    UrlPattern url;

    if (path == null) {
      path = "";
    }

    ///Returns null with [StateError] if path is not implemented.
    try {
      url = _getUrl(path);
    } catch (e) {
      _logger.warning("${e.toString()} - Executing Default Route");
      _updateLocationUrl(_defaultPath.toString(), null);
      _defaultRoute(null);
    }

    if (url != null) {
      _executeRoute(url, path);
    }
  }

  /**
   * In charge of internal link navigation. This method is executed whenever a qualified anchor element
   * on a page is clicked. See [listen]'s window.onClick.listen().
   */
  void handleLink(String path, String title) {

    UrlPattern url;

    if (path == null) {
      path = "";
    }

    ///Returns null with [StateError] if path is not implemented.
    try {
      url = _getUrl(path);
    } catch (e) {
      _logger.warning("${e.toString()} - Executing Default Route");
      _updateLocationUrl(_defaultPath.toString(), null);
      _defaultRoute(null);
    }

    _logger.fine("HandleLink - $path : $title");

    if (url != null) {
      _updateLocationUrl(path, title);
      if (!_listenerOn || !_useHashChange) {
        _executeRoute(url, path);
      }
    }
  }

  /**
   * Retrieves the correct [URL] pattern from [_routes] based on the current [path].
   */
  UrlPattern _getUrl(String path) {
    Iterable matches = _routes.keys.where((UrlPattern url) => url.matches(path));
    if (matches.isEmpty) {
      throw new StateError("ERROR! No Route found for $path"); //Throw a custom exception/Error?
      return null;
    }
    return matches.first;
  }

  /**
   * Parses a string that contains a [window.location.pathname] or a
   * [window.location.hash]. Returns a list of the path's paramenters, split on "/".
   */
  List _extractParameters(String path) {
    ///Remove leading slash "/"
    path = path.replaceFirst("/", "");
    return path.split("/");
  }

  /**
   * Executes the correct route based on the [path], and [url].
   */
  void _executeRoute(UrlPattern url, String path) {
    ///Take the hash out of the url path
    List urlPieces = url.parse(path);
    String fixedPath = url.reverse(urlPieces, useFragment: _useHashChange);

    ///Execute the correct Route.
    _logger.fine("Executing Route - $url");
    List parameters = _extractParameters(fixedPath);
    _routes[url](parameters);
  }
}