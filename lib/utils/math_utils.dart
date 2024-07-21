import 'dart:math';

/// Computes `sqrt(x^2 + y^2)` without under/overflow
num hypot(num x, num y) {
  var first = x.abs();
  var second = y.abs();

  if (y > x) {
    first = y.abs();
    second = x.abs();
  }

  if (first == 0.0) {
    return second;
  }

  final t = second / first;
  return first * sqrt(1 + t * t);
}
