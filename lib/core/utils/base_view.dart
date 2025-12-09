import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/base_view_model.dart';

/// Base View widget that provides common functionality for all Views
/// Automatically manages ViewModel lifecycle and provides error handling
abstract class BaseView<T extends BaseViewModel> extends StatefulWidget {
  /// Optional: supply a ready ViewModel and a builder directly (builder-mode)
  final T? model;
  final Widget Function(BuildContext context, T viewModel, Widget? child)? builder;

  const BaseView({Key? key, this.model, this.builder}) : super(key: key);

  /// Create the ViewModel instance
  T createViewModel();

  /// Build the UI with the ViewModel
  Widget buildView(BuildContext context, T viewModel);

  /// Called when the ViewModel is initialized
  void onViewModelReady(T viewModel) {
    viewModel.init();
  }

  /// Called when an error occurs
  void onError(BuildContext context, String error) {
    // Default error handling - show snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  State<BaseView<T>> createState() => _BaseViewState<T>();
}

class _BaseViewState<T extends BaseViewModel> extends State<BaseView<T>> {
  late T _viewModel;
  bool _isHandlingError = false; // Prevent infinite loop
  String? _lastHandledError; // Track last handled error to prevent duplicates

  @override
  void initState() {
    super.initState();
    // If a model is provided, use it; otherwise create via subclass
    _viewModel = widget.model ?? widget.createViewModel();

    // Listen for errors
    _viewModel.addListener(_onViewModelChanged);

    // Initialize ViewModel after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onViewModelReady(_viewModel);
    });
  }

  void _onViewModelChanged() {
    // Prevent infinite loop - if we're already handling an error, don't process again
    if (_isHandlingError) return;

    // Handle errors
    if (_viewModel.errorMessage != null && mounted) {
      final errorMessage = _viewModel.errorMessage!;
      
      // Prevent handling the same error multiple times
      if (errorMessage == _lastHandledError) return;
      
      _isHandlingError = true; // Set flag to prevent recursion
      _lastHandledError = errorMessage;
      
      widget.onError(context, errorMessage);

      // Clear the error after handling - use microtask to break synchronous call chain
      // This prevents the infinite loop by deferring clearError() to next event loop
      Future.microtask(() {
        if (mounted && !_viewModel.isDisposed) {
          // Temporarily remove listener to prevent recursion
          _viewModel.removeListener(_onViewModelChanged);
          // Clear error silently without triggering listeners
          _viewModel.clearErrorSilently();
          // Re-add listener after clearing
          _viewModel.addListener(_onViewModelChanged);
        }
        _isHandlingError = false; // Reset flag
        _lastHandledError = null; // Reset last handled error
      });
      return; // Exit early to prevent further processing
    }

    // 🔹 listen for busy state (loading spinner support)
    if (_viewModel.busy && mounted) {
      // could be hooked into a global loading overlay
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>.value(
      value: _viewModel,
      child: Consumer<T>(
        builder: (context, viewModel, child) {
          // If a custom builder is provided, use it; else call subclass buildView
          if (widget.builder != null) {
            return widget.builder!(context, viewModel, child);
          }
          return widget.buildView(context, viewModel);
        },
      ),
    );
  }
}

/// Concrete builder-based BaseView for cases where you don't want to
/// subclass `BaseView`. Supply a `model` and a `builder`.
class BaseViewBuilder<T extends BaseViewModel> extends StatefulWidget {
  final T model;
  final Widget Function(BuildContext context, T viewModel, Widget? child) builder;

  const BaseViewBuilder({Key? key, required this.model, required this.builder}) : super(key: key);

  @override
  State<BaseViewBuilder<T>> createState() => _BaseViewBuilderState<T>();
}

class _BaseViewBuilderState<T extends BaseViewModel> extends State<BaseViewBuilder<T>> {
  late T _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.model;

    // listen for changes (optional behaviors similar to BaseView)
    _viewModel.addListener(_onViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.init();
    });
  }

  void _onViewModelChanged() {
    // observers for error/busy can be implemented here if needed
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>.value(
      value: _viewModel,
      child: Consumer<T>(
        builder: (context, viewModel, child) {
          return widget.builder(context, viewModel, child);
        },
      ),
    );
  }
}

/// Base StatelessView for simpler views that don't need lifecycle management
abstract class BaseStatelessView<T extends BaseViewModel> extends StatelessWidget {
  final T viewModel;

  const BaseStatelessView({
    Key? key,
    required this.viewModel,
  }) : super(key: key);

  /// Build the UI with the ViewModel
  Widget buildView(BuildContext context, T viewModel);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<T>.value(
      value: viewModel,
      child: Consumer<T>(
        builder: (context, viewModel, child) {
          return buildView(context, viewModel);
        },
      ),
    );
  }
}

/// Mixin for Views that need loading state management
mixin LoadingStateMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  /// Show loading overlay
  Widget buildWithLoading({
    required Widget child,
    Widget? loadingWidget,
  }) {
    return Stack(
      children: [
        child,
        if (_isLoading)
          Positioned.fill( // 🔹 ensures overlay covers full screen
            child: Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: loadingWidget ?? const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

/// Mixin for Views that need error handling
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  void setError(String? error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  void clearError() {
    setError(null);
  }

  void showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
