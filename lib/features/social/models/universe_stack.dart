import 'orb_universe.dart';

class UniverseStack {
  const UniverseStack([this._items = const <OrbUniverse>[]]);

  final List<OrbUniverse> _items;

  List<OrbUniverse> get items => List.unmodifiable(_items);

  OrbUniverse? get current => _items.isEmpty ? null : _items.last;

  bool get canGoBack => _items.length > 1;

  OrbUniverse? get parent =>
      _items.length > 1 ? _items[_items.length - 2] : null;

  int get depth => _items.length;

  UniverseStack push(OrbUniverse universe) {
    return UniverseStack([..._items, universe]);
  }

  UniverseStack pop() {
    if (_items.length <= 1) return this;
    return UniverseStack(_items.sublist(0, _items.length - 1));
  }

  UniverseStack popTo(int index) {
    if (index < 0 || index >= _items.length) return this;
    return UniverseStack(_items.sublist(0, index + 1));
  }

  UniverseStack clear() => const UniverseStack();
}
