import 'dart:async';

class LayoutChangeStream {
  final _controller = StreamController<LayoutChangeEvent>.broadcast();

  Stream<LayoutChangeEvent> get changes => _controller.stream;

  void reportChange(LayoutChangeEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

class LayoutChangeEvent {
  final String changeType;
  final String elementId;
  final dynamic data;

  LayoutChangeEvent({
    required this.changeType,
    required this.elementId,
    this.data,
  });
}
