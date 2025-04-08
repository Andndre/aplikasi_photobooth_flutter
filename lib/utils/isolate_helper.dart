import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';

/// Helper class for working with isolates and ensuring proper initialization
/// of the binary messenger for platform channel communication
class IsolateHelper {
  /// Runs a computation in an isolate with proper binary messenger initialization
  static Future<T> computeWithMessenger<T, U>(
    FutureOr<T> Function(U) callback,
    U message,
  ) async {
    // Try to get the root isolate token - this is needed for binary messenger setup
    final rootIsolateToken = RootIsolateToken.instance;

    // If we can't get a token, fall back to the regular compute function
    if (rootIsolateToken == null) {
      print(
        'Warning: RootIsolateToken is null, falling back to main isolate processing',
      );
      return await callback(message);
    }

    // Create ports for communication with the isolate
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();

    // Create isolate data package
    final isolateData = _IsolateData<T, U>(
      rootIsolateToken: rootIsolateToken,
      callback: callback,
      message: message,
      sendPort: receivePort.sendPort,
    );

    // Spawn the isolate
    final isolate = await Isolate.spawn<_IsolateData<T, U>>(
      _isolateEntryPoint,
      isolateData,
      onError: errorPort.sendPort,
      debugName: 'IsolateHelper worker',
    );

    // Set up error handling
    Object? error;
    StackTrace? stackTrace;

    errorPort.listen((errorData) {
      if (errorData is List && errorData.length >= 2) {
        error = errorData[0];
        stackTrace =
            errorData[1] is StackTrace ? errorData[1] as StackTrace : null;
      } else {
        error = 'Unknown error in isolate';
        stackTrace = StackTrace.current;
      }
    });

    // Wait for result from the isolate
    final result = await receivePort.first;

    // Clean up
    receivePort.close();
    errorPort.close();
    isolate.kill();

    // If there was an error, rethrow it
    if (error != null) {
      Error.throwWithStackTrace(error!, stackTrace ?? StackTrace.current);
    }

    return result as T;
  }

  /// Entry point for the isolate
  static Future<void> _isolateEntryPoint<T, U>(_IsolateData<T, U> data) async {
    try {
      // Initialize the binary messenger to allow platform channel communication
      BackgroundIsolateBinaryMessenger.ensureInitialized(data.rootIsolateToken);

      // Run the computation
      final result = await data.callback(data.message);

      // Send back the result
      data.sendPort.send(result);
    } catch (error, stackTrace) {
      print('Error in isolate: $error\n$stackTrace');
      Isolate.exit();
    }
  }
}

/// Data container for passing information to the isolate
class _IsolateData<T, U> {
  final RootIsolateToken rootIsolateToken;
  final FutureOr<T> Function(U) callback;
  final U message;
  final SendPort sendPort;

  _IsolateData({
    required this.rootIsolateToken,
    required this.callback,
    required this.message,
    required this.sendPort,
  });
}
