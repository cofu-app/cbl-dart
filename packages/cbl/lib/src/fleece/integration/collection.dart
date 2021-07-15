import 'package:meta/meta.dart';

import '../encoder.dart';
import 'context.dart';
import 'value.dart';

abstract class MCollection {
  MCollection({
    MContext? context,
    bool isMutable = true,
  })  : _context = context,
        _isMutable = isMutable,
        _hasMutableChildren = isMutable,
        _isMutated = true;

  MCollection.asCopy(
    MCollection original, {
    required bool isMutable,
  })  : _context = original.context,
        _isMutable = isMutable,
        _hasMutableChildren = isMutable,
        _isMutated = true;

  MCollection.asChild(
    MValue slot,
    MCollection parent, {
    required bool isMutable,
  })  : _isMutable = isMutable,
        _hasMutableChildren = isMutable,
        _isMutated = slot.isMutated {
    updateParent(slot, parent);
  }

  MContext? get context => _context;
  MContext? _context;

  MValue? _slot;

  MCollection? get parent => _parent;
  MCollection? _parent;

  Iterable<MValue> get values;

  bool get isMutable => _isMutable;
  final bool _isMutable;

  bool _hasMutableChildren;

  bool get hasMutableChildren => _hasMutableChildren;

  set hasMutableChildren(bool hasMutableChildren) {
    assert(isMutable);
    _hasMutableChildren = hasMutableChildren;
  }

  bool get isMutated => _isMutated;
  bool _isMutated;

  void encodeTo(FleeceEncoder encoder);

  @protected
  void mutate() {
    assert(isMutable);

    if (!_isMutated) {
      _isMutated = true;
      _slot?.mutate();
      _parent?.mutate();
    }
  }

  /// Called when this collection is assigned to a new slot in a parent
  /// collection or removed from its current parent collection.
  void updateParent(MValue? slot, MCollection? parent) {
    assert(slot == null && parent == null || slot != null && parent != null);

    final parentContext = parent?.context;

    // Nothing changed.
    if (_slot == slot && _parent == parent && _context == parentContext) {
      return;
    }

    _slot = slot;
    _parent = parent;

    if (_isMutated) {
      _slot?.mutate();
      _parent?.mutate();
    }

    _updateContext(parentContext);
  }

  void _updateContext(MContext? context) {
    if (context == null || _context == context) return;

    assert(
      _context == null || _context == context,
      'once set the context of a MCollection cannot change',
    );

    _context = context;

    // Propagate context to children.
    values.forEach((value) => value.updateParent(this));
  }
}
