import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App commands for the visible route, independent of which child has focus.
/// Text editing keys remain with the focused control unless explicitly bound.
class RouteShortcuts extends StatefulWidget {
  const RouteShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  State<RouteShortcuts> createState() => _RouteShortcutsState();
}

class _RouteShortcutsState extends State<RouteShortcuts> {
  ModalRoute<dynamic>? _route;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _enabled = TickerMode.valuesOf(context).enabled;
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!mounted || !_enabled || _route?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    // Holding a shortcut must not open several dialogs or repeat remote work.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    for (final entry in widget.bindings.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
