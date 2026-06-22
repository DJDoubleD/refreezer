import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Widget that holds a custom navigator with all the basics functionality.
/// A common use for such widget is when you need to implement an "Always presenting bottom navigation bar"
/// so you need the navigation to be handled not by the default "App Navigator" but by this widget.
class CustomNavigator extends StatefulWidget {
  /// {@macro flutter.widgets.widgetsApp.navigatorKey}
  final GlobalKey<NavigatorState>? navigatorKey;

  /// {@macro flutter.widgets.widgetsApp.initialRoute}
  final String? initialRoute;

  final RouteFactory? onGenerateRoute;

  /// The application's top-level routing table.
  ///
  /// When a named route is pushed with [Navigator.pushNamed], the route name is
  /// looked up in this map. If the name is present, the associated
  /// [WidgetBuilder] is used to construct a [MaterialPageRoute] that performs
  /// an appropriate transition, including [Hero] animations, to the new route.
  ///
  /// {@macro flutter.widgets.widgetsApp.routes}
  final Map<String, WidgetBuilder> routes;

  /// Choose your [PageRoute] as follows [PageRoutes.materialPageRoute] or [PageRoutes.cupertinoPageRoute]
  /// The [PageRoute] generator callback used when the app is navigated to a
  /// named route.
  ///
  /// This callback can be used, for example, to specify that a [MaterialPageRoute]
  /// or a [CupertinoPageRoute] should be used for building page transitions.
  final PageRouteFactory? pageRoute;

  /// @macro flutter.widgets.widgetsApp.home
  final Widget? home;

  /// {@macro flutter.widgets.widgetsApp.onUnknownRoute}
  final RouteFactory? onUnknownRoute;

  /// {@macro flutter.widgets.widgetsApp.navigatorObservers}
  final List<NavigatorObserver> navigatorObservers;

  const CustomNavigator({
    Key? key,
    this.navigatorKey,
    this.initialRoute,
    this.onGenerateRoute,
    this.routes = const <String, WidgetBuilder>{},
    this.pageRoute,
    this.home,
    this.onUnknownRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
  }) : super(key: key);

  @override
  createState() => _CustomNavigatorState();
}

class _CustomNavigatorState extends State<CustomNavigator>
    implements WidgetsBindingObserver {
  GlobalKey<NavigatorState>? _navigator;

  void _setNavigator() =>
      _navigator = widget.navigatorKey ?? GlobalObjectKey<NavigatorState>(this);

  @override
  void initState() {
    _setNavigator();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigator,
      // If PlatformDispatcher.instance.defaultRouteName isn't '/', we should assume it was set
      // intentionally via `setInitialRoute`, and should override whatever
      // is in [widget.initialRoute].
      initialRoute: PlatformDispatcher.instance.defaultRouteName !=
              Navigator.defaultRouteName
          ? PlatformDispatcher.instance.defaultRouteName
          : widget.initialRoute ?? PlatformDispatcher.instance.defaultRouteName,
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onUnknownRoute,
      observers: widget.navigatorObservers,
    );
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void didChangeLocales(List<Locale>? locale) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  void handleStatusBarTap() {}

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    return didPushRoute(routeInformation.uri.toString());
  }

  // A system method that get invoked when user press back button on Android or back slide on iOS
  @override
  Future<bool> didPopRoute() async {
    assert(mounted);
    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null) return false;
    return await navigator.maybePop();
  }

  @override
  Future<bool> didPushRoute(String route) async {
    assert(mounted);
    final NavigatorState? navigator = _navigator?.currentState;
    if (navigator == null) return false;
    navigator.pushNamed(route);
    return true;
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final Widget Function(BuildContext context)? pageContentBuilder =
        name == Navigator.defaultRouteName && widget.home != null
            ? (BuildContext context) => widget.home!
            : widget.routes[name];

    if (pageContentBuilder != null) {
      assert(
          widget.pageRoute != null,
          'The default onGenerateRoute handler for CustomNavigator must have a '
          'pageRoute set if the home or routes properties are set.');
      final Route<dynamic> route = widget.pageRoute!<dynamic>(
        settings,
        pageContentBuilder,
      );
      return route;
    }
    if (widget.onGenerateRoute != null) {
      return widget.onGenerateRoute!(settings);
    }
    return null;
  }

  Route<dynamic>? _onUnknownRoute(RouteSettings settings) {
    assert(() {
      if (widget.onUnknownRoute == null) {
        throw FlutterError(
            'Could not find a generator for route $settings in the $runtimeType.\n'
            'Generators for routes are searched for in the following order:\n'
            ' 1. For the "/" route, the "home" property, if non-null, is used.\n'
            ' 2. Otherwise, the "routes" table is used, if it has an entry for '
            'the route.\n'
            ' 3. Otherwise, onGenerateRoute is called. It should return a '
            'non-null value for any valid route not handled by "home" and "routes".\n'
            ' 4. Finally if all else fails onUnknownRoute is called.\n'
            'Unfortunately, onUnknownRoute was not set.');
      }
      return true;
    }());
    final Route<dynamic>? result = widget.onUnknownRoute?.call(settings);
    assert(() {
      if (result == null) {
        throw FlutterError('The onUnknownRoute callback returned null.\n'
            'When the $runtimeType requested the route $settings from its '
            'onUnknownRoute callback, the callback returned null. Such callbacks '
            'must never return null.');
      }
      return true;
    }());
    return result;
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    return AppExitResponse.exit;
  }

  @override
  void handleCancelBackGesture() {
    // No-ops. Out of scope
  }

  @override
  void handleCommitBackGesture() {
    // No-ops. Out of scope
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    throw UnimplementedError();
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    // No-ops. Out of scope
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    // No-ops. Out of scope
  }
}

class PageRoutes {
  static MaterialPageRoute<T> materialPageRoute<T>(
          RouteSettings settings, WidgetBuilder builder) =>
      MaterialPageRoute<T>(settings: settings, builder: builder);

  static CupertinoPageRoute<T> cupertinoPageRoute<T>(
          RouteSettings settings, WidgetBuilder builder) =>
      CupertinoPageRoute<T>(settings: settings, builder: builder);
}
