import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

// Slide left to right
class SlideLeftRoute extends PageRouteBuilder {
  final Widget widget;
  SlideLeftRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        });
}

// Slide right to left
class SlideRightRoute extends PageRouteBuilder {
  final Widget widget;
  SlideRightRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        });
}

// Slide top to bottom
class SlideTopRoute extends PageRouteBuilder {
  final Widget widget;
  SlideTopRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        });
}

// Slide top to bottom
class SlideTopRightRoute extends PageRouteBuilder {
  final Widget widget;
  SlideTopRightRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, -1.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        });
}

// Slide bottom to top
class SlideBottomRoute extends PageRouteBuilder {
  final Widget widget;
  SlideBottomRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
          // transitionDuration:Duration(seconds: 1);
        });
}

// Scale in and out animation
class ScaleRoute extends PageRouteBuilder {
  final Widget widget;

  ScaleRoute({required this.widget})
      : super(pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
          return widget;
        }, transitionsBuilder:
            (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(
                  0.00,
                  0.50,
                  curve: Curves.linear,
                ),
              ),
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 1.5,
                end: 1.0,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(
                    0.50,
                    1.00,
                    curve: Curves.linear,
                  ),
                ),
              ),
              child: child,
            ),
          );
        });
}

// Expand out as circle from given centerAlignment or centerOffset (screen center is used if omitted)
class CircularExpansionRoute extends PageRouteBuilder {
  final Widget widget;
  final Alignment? centerAlignment;
  final Offset? centerOffset;

  CircularExpansionRoute({required this.widget, this.centerAlignment, this.centerOffset})
      : super(
          pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
            return widget;
          },
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return ClipPath(
              clipper: CircularRevealClipper(
                fraction: animation.value,
                centerAlignment: centerAlignment,
                centerOffset: centerOffset,
              ),
              child: child,
            );
          },
        );
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Alignment? centerAlignment;
  final Offset? centerOffset;

  CircularRevealClipper({
    required this.fraction,
    this.centerAlignment,
    this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    final Offset center =
        centerAlignment?.alongSize(size) ?? centerOffset ?? Offset(size.width / 2, size.height / 2);

    return Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: lerpDouble(0, _calcMaxOvalRadius(size, center), fraction)!),
      );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;

  // Calculates the maximum radius of an oval that can fit inside a rectangle with the given size and center
  // by finding the maximum horizontal and vertical radii of the oval
  // and then calculating the maximum radius using the Pythagorean theorem.
  static double _calcMaxOvalRadius(Size size, Offset center) {
    final w = max(center.dx, size.width - center.dx);
    final h = max(center.dy, size.height - center.dy);
    return sqrt(w * w + h * h);
  }
}
