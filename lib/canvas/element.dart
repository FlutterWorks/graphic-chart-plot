import 'dart:ui' show Rect, Offset;

import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector4;

import 'attrs.dart' show Attrs;
import 'cfg.dart' show Cfg;
import 'base.dart' show Base, Ctor;
import 'group.dart' show Group;
import 'container.dart' show Container;
import './shape/shape.dart' show ShapeType, Shape;
import 'canvas_controller.dart' show CanvasController;
import './event/graph_event.dart' show EventType, EventTag, GraphEvent;

enum ChangeType {
  changeSize,
  add,
  sort,
  clear,
  attr,
  show,
  hide,
  zIndex,
  remove,
  matrix,
  clip,
}

class Pause {
  Pause(this.isPaused, [this.pauseTime]);

  final bool isPaused;
  final DateTime pauseTime;
}

abstract class Element extends Base {
  Element(Cfg cfg)
    : super(cfg) 
  {
    final attrs = defaultAttrs;
    attrs.mix(cfg.attrs);
    this.attrs = attrs;
    this.initAttrs(attrs);
    this.initAnimate();
  }

  Attrs attrs;

  @override
  Cfg get defaultCfg => Cfg(
    visible: true,
    capture: true,
    zIndex: 0,
  );

  Attrs get defaultAttrs => Attrs(
    matrix: defaultMatrix,
  );

  Map<ShapeType, Ctor<Shape>> get shpeBase;

  Ctor<Group> get groupBase;

  void onCanvasChange(ChangeType changeType);

  void initAttrs(Attrs attrs);

  void initAnimate() {
    cfg.animable = true;
    cfg.animating = false;
  }

  bool get isGroup => false;

  Container get parent => cfg.parent;

  CanvasController get canvasController => cfg.canvasController;

  Element attr(Attrs attrs) {
    for (var k in attrs.keys) {
      setAttr(k, attrs[k]);
    }
    afterAttrsChange(attrs);
    return this;
  }

  Rect get bbox;

  Rect get canvasBBox;

  bool isClipped(double refX, double refY) {
    final clip = this.clip;
    return (clip != null) && !clip.isHit(refX, refY);
  }

  void setAttr(String name, Object value) {
    final originValue = attrs[name];
    if (originValue != value) {
      attrs[name] = value;
      onAttrChange(name, value, originValue);
    }
  }

  void onAttrChange(String name, Object value, Object originValue) {
    if (name == 'matrix') {
      cfg.totalMatrix = null;
    }
  }

  void afterAttrsChange(Attrs targetAttrs) {
    onCanvasChange(ChangeType.attr);
  }

  Element show() {
    cfg.visible = true;
    onCanvasChange(ChangeType.show);
    return this;
  }

  Element hide() {
    cfg.visible = false;
    onCanvasChange(ChangeType.hide);
    return this;
  }

  Element setZIndex(int zIndex) {
    cfg.zIndex = zIndex;
    final parent = this.parent;
    if (parent != null) {
      parent.sort();
    }
    return this;
  }

  void toFront() {
    final parent = this.parent;
    if (parent == null) {
      return;
    }
    final children = parent.children;
    children.remove(this);
    children.add(this);
    onCanvasChange(ChangeType.zIndex);
  }

  void toBack() {
    final parent = this.parent;
    if (parent == null) {
      return;
    }
    final children = parent.children;
    children.remove(this);
    children.insert(0, this);
    onCanvasChange(ChangeType.zIndex);
  }

  void remove([bool destroy = true]) {
    final parent = this.parent;
    if (parent != null) {
      parent.children.remove(this);
      if (!parent.cfg.clearing) {
        onCanvasChange(ChangeType.remove);
      }
    } else {
      onCanvasChange(ChangeType.remove);
    }
    if (destroy) {
      this.destroy();
    }
  }

  void resetMatrix() {
    attr(Attrs(matrix: defaultMatrix));
    onCanvasChange(ChangeType.matrix);
  }

  Matrix4 get matrix => attrs.matrix;

  void setMatrix(Matrix4 m) {
    attr(Attrs(matrix: m));
    onCanvasChange(ChangeType.matrix);
  }

  Matrix4 get totalMatrix {
    var totalMatrix = cfg.totalMatrix;
    if (totalMatrix == null) {
      final currentMatrix = attrs.matrix;
      final parentMatrix = cfg.parentMatrix;
      if (parentMatrix != null && currentMatrix != null) {
        totalMatrix = parentMatrix * currentMatrix;
      } else {
        totalMatrix = currentMatrix ?? parentMatrix;
      }
      cfg.totalMatrix = totalMatrix;
    }
    return totalMatrix;
  }

  void applyMatrix(Matrix4 matrix) {
    final currentMatrix = attrs.matrix;
    var totalMatrix;
    if (matrix != null && currentMatrix != null) {
      totalMatrix = matrix * currentMatrix;
    } else {
      totalMatrix = currentMatrix ?? matrix;
    }
    cfg.totalMatrix = totalMatrix;
    cfg.parentMatrix = matrix;
  }

  Matrix4 get defaultMatrix => null;

  Vector4 applyToMatrix(Vector4 v) {
    final matrix = attrs.matrix;
    if (matrix != null) {
      return matrix * v;
    }
    return v;
  }

  Vector4 invertFromMatrix(Vector4 v) {
    final matrix = attrs.matrix;
    if (matrix != null) {
      final invertMatrix = Matrix4.tryInvert(matrix);
      return invertMatrix * v;
    }
    return v;
  }

  Shape setClip(Cfg clipCfg) {
    final canvasController = this.canvasController;
    Shape clipShape;
    if (clipCfg != null) {
      final shapeBase = this.shpeBase;
      final shapeType = clipCfg.type;
      final cons = shapeBase[shapeType];
      if (cons != null) {
        clipShape = cons(Cfg(
          type: clipCfg.type,
          isClipShape: true,
          attrs: clipCfg.attrs,
          canvasController: canvasController,
        ));
      }
    }
    cfg.clipShape = clipShape;
    onCanvasChange(ChangeType.clip);
    return clipShape;
  }

  Shape get clip => cfg.clipShape;

  Element clone();

  void destroy() {
    if (destroyed) {
      return;
    }
    attrs = Attrs();
    super.destroy();
  }

  bool isAnimatePaused() => cfg.pause.isPaused;

  // TODO 动画系列

  void emitDelegation(EventType type, GraphEvent eventObj) {
    final paths = eventObj.propagationPath;
    final events = this.events;
    for (var element in paths) {
      final name = element.cfg.name;
      if (name != null) {
        final eventTag = EventTag(type, name);
        if (events[eventTag] != null || events[EventTag.all] != null) {
          eventObj.tag = eventTag;
          eventObj.currentTarget = element;
          eventObj.delegateTarget = this;
          eventObj.delegateObject = element.cfg.delegateObject;
          emit(eventTag, eventObj);
        }
      }
    }
  }

  Element translate(double dx, double dy) {
    final matrix = this.matrix ?? Matrix4.identity();
    matrix.leftTranslate(dx, dy);
    setMatrix(matrix);
    return this;
  }

  Element moveTo(Offset target) {
    final x = attrs.x ?? 0.0;
    final y = attrs.y ?? 0.0;
    translate(target.dx - x, target.dy - y);
    return this;
  }

  Element scale(double sx, [double sy]) {
    final matrix = this.matrix ?? Matrix4.identity();
    matrix.multiply(Matrix4.identity()..scale(sx, sy));
    setMatrix(matrix);
    return this;
  }

  Element rotate(double radians) {
    final matrix = this.matrix ?? Matrix4.identity();
    matrix.rotateZ(radians);
    setMatrix(matrix);
    return this;
  }

  Element rotateAtStart(double radians) {
    final startPoint = Offset(attrs.x ?? 0.0, attrs.y ?? 0.0);
    return rotateAtPoint(startPoint, radians);
  }

  Element rotateAtPoint(Offset point, double radians) {
    final matrix = this.matrix ?? Matrix4.identity();
    matrix
      ..translate(-point.dx, -point.dy)
      ..rotateZ(radians)
      ..translate(point.dx, point.dy);
    setMatrix(matrix);
    return this;
  }
}
