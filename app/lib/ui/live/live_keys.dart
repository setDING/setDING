import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'page_turner.dart';

/// Keys that turn forward / back, exactly like the right / left tap zones
/// (ADR-0007); see [pageTurnNextKeys]. Like the tap zones, the arrows
/// up/down scroll a song that does not fit before turning.
final _nextKeys = pageTurnNextKeys;
final _previousKeys = pageTurnPreviousKeys;

/// Keys that start and stop the beat (ADR-0026); Space too when
/// [AppSettings.spaceStartsBeat] is on (#969).
final _beatKeys = {LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter};

/// A forward key held this long starts or stops the beat instead of
/// turning (ADR-0026).
const beatLongPress = Duration(milliseconds: 600);

/// The keys of live mode (ADR-0007, ADR-0026): turning, the beat and
/// Escape.
class LiveKeys {
  LiveKeys({
    required this._active,
    required this._spaceStartsBeat,
    required this._onPageTurnKey,
    required this._current,
    required this._canBeat,
    required this._toggleBeat,
    required this._next,
    required this._previous,
    required this._escape,
  });

  /// Whether live mode is on top and takes the keys.
  final bool Function() _active;

  /// Space starts and stops the beat instead of turning (#969).
  final bool Function() _spaceStartsBeat;

  /// A key of a page turner was pressed (#911).
  final VoidCallback _onPageTurnKey;

  /// The item on stage.
  final int Function() _current;
  final bool Function(int index) _canBeat;
  final void Function(int index) _toggleBeat;
  final VoidCallback _next;
  final VoidCallback _previous;

  /// Escape: ends drawing mode, otherwise leaves live mode.
  final VoidCallback _escape;

  /// Long press of a forward key (ADR-0026).
  Timer? _longPress;
  bool _longPressed = false;
  bool _disposed = false;

  /// Page turner and keyboard (ADR-0007). An early handler of the focus
  /// manager: it sees every key before the focused widget, so the keys work
  /// whichever widget of live mode has the focus (a button of the control
  /// bar, the PDF viewer) or none, and Space never presses a focused button.
  KeyEventResult handle(KeyEvent event) {
    if (!_active()) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // Space starts and stops the beat instead of turning, when chosen
    // (#969).
    final spaceBeat = key == LogicalKeyboardKey.space && _spaceStartsBeat();
    final next = !spaceBeat && _nextKeys.contains(key);
    if (event is KeyDownEvent && !spaceBeat && isPageTurnKey(key)) {
      _onPageTurnKey();
    }
    if (next && _canBeat(_current())) {
      // With a beat, a forward key held for [beatLongPress] starts or stops
      // it and does not turn (ADR-0026); a shorter press turns when it is
      // released. Key repeat is ignored as before.
      if (event is KeyDownEvent) {
        _longPress?.cancel();
        _longPressed = false;
        final index = _current();
        _longPress = Timer(beatLongPress, () {
          _longPressed = true;
          if (!_disposed) _toggleBeat(index);
        });
      } else if (event is KeyUpEvent) {
        final pending = _longPress?.isActive ?? false;
        _longPress?.cancel();
        _longPress = null;
        if (pending && !_longPressed) _next();
      }
      return KeyEventResult.handled;
    }
    if (next || _previousKeys.contains(key)) {
      // One press turns once. A held key (key repeat) does not turn again,
      // so it never races through the pages and songs of the set.
      if (event is KeyDownEvent) next ? _next() : _previous();
      return KeyEventResult.handled;
    }
    if (spaceBeat || _beatKeys.contains(key)) {
      if (event is KeyDownEvent && _canBeat(_current())) {
        _toggleBeat(_current());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _escape();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void dispose() {
    _disposed = true;
    _longPress?.cancel();
  }
}
