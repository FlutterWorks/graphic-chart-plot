import 'package:flutter/gestures.dart';

import '../element.dart' show Element;
import '../shape/shape.dart' show Shape;

// Simulate web event types.
enum EventType {
  pointerDown,
  pointerUp,
  doubleClick,
  pointerMove,
  touchStart,
  touchMove,
  touchEnd,
  dragEnter,
  dragOver,
  dragLeave,
  drop,
}

class EventTag {
  /// wildcard
  static EventTag all = EventTag(null, '*');

  EventTag(this.type, [this.name]);

  final EventType type;

  /// Refers to Element.name
  final String name;

  bool operator ==(Object other) =>
    other is EventTag && type == other.type && name == other.name;
  
  @override
  int get hashCode => type.hashCode * 31 + name.hashCode;
}

class OriginalEvent {
  OriginalEvent(this.type, this.pointerEvent);

  final EventType type;

  final PointerEvent pointerEvent;
}

class GraphEvent {
  GraphEvent(EventTag tag, OriginalEvent event) {
    this.tag = tag;
    originalEvent = event;
    timeStamp = event.pointerEvent.timeStamp;
  }

  EventTag tag;

  Offset localPosition;

  Offset globalPosition;

  bool bubbles = true;

  Element target;

  Element currentTarget;

  Element delegateTarget;

  Element delegateObject;

  bool propagationStopped = false;

  Shape shape;

  Shape fromShape;

  Shape toShape;

  Duration timeStamp;

  OriginalEvent originalEvent;

  List<Element> propagationPath = [];

  void stopPropagation() {
    propagationStopped = true;
  }
}
