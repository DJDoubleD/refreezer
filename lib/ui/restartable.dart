import 'package:flutter/widgets.dart';

import '../utils/navigator_keys.dart';

/// Wrap the root App widget with this widget and call [Restartable.restart] to simulate app restart.
/// This restarts the application at the application level, rebuilding the application widget tree from scratch, losing any previous state.
/// It won't fully restart the application process at the OS level.
class Restartable extends StatefulWidget {
  final Widget child;

  const Restartable({super.key, required this.child});

  @override
  _RestartableState createState() => _RestartableState();

  static restart() {
    mainNavigatorKey.currentContext!.findAncestorStateOfType<_RestartableState>()!.restartApp();
  }
}

class _RestartableState extends State<Restartable> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
