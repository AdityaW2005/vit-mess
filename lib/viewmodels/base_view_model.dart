import 'package:flutter/foundation.dart';

import '../core/utils/result.dart';

/// The coarse lifecycle every screen shares.
enum ViewState {
  /// Nothing has been requested yet.
  idle,

  /// A first load is in flight and there is nothing to show.
  busy,

  /// Content is available.
  ready,

  /// Loading failed and there is nothing to fall back on.
  error,
}

/// Common loading and error plumbing for every ViewModel.
///
/// Deliberately imports only `foundation` — a ViewModel must never reach for a
/// widget, a `BuildContext`, or a service.
abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  FailureKind? _errorKind;
  bool _disposed = false;

  /// Current lifecycle state.
  ViewState get state => _state;

  /// True while a first load is in flight with nothing to show.
  bool get isBusy => _state == ViewState.busy;

  /// True when content is available.
  bool get isReady => _state == ViewState.ready;

  /// True when the screen is in its designed error state.
  bool get hasError => _state == ViewState.error;

  /// Plain-language failure text, safe to render.
  String? get errorMessage => _errorMessage;

  /// Failure category, used to pick the right illustration and action.
  FailureKind? get errorKind => _errorKind;

  /// True once [dispose] has run. Guards late async callbacks.
  bool get isDisposed => _disposed;

  /// Moves to [next], clearing any error when leaving the error state.
  @protected
  void setState(ViewState next) {
    if (_state == next) return;
    _state = next;
    if (next != ViewState.error) {
      _errorMessage = null;
      _errorKind = null;
    }
    safeNotify();
  }

  /// Enters the error state carrying [failure]'s message and kind.
  @protected
  void setFailure(Failure<Object?> failure) {
    _errorMessage = failure.message;
    _errorKind = failure.kind;
    _state = ViewState.error;
    safeNotify();
  }

  /// Clears any recorded error without changing the lifecycle state.
  @protected
  void clearError() {
    if (_errorMessage == null && _errorKind == null) return;
    _errorMessage = null;
    _errorKind = null;
    safeNotify();
  }

  /// Notifies listeners unless this ViewModel has already been disposed.
  ///
  /// Async work that completes after a screen is torn down is normal; calling
  /// `notifyListeners` then would throw, so every notify goes through here.
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
