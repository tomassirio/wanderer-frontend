import 'package:flutter/material.dart';

/// Defines a contract for matching a URL path and building
/// the corresponding route (screen).
abstract class RouteStrategy {
  /// Returns `true` if this strategy can handle the given [uri].
  bool matches(Uri uri);

  /// Builds a [PageRoute] for the given [uri] and [settings].
  PageRoute build(Uri uri, RouteSettings settings);
}
