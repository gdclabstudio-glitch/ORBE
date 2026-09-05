import 'package:flutter/material.dart';

typedef ReactionChanged = void Function(String emoji, bool added);

class ReactionBar extends StatefulWidget {
  final Map<String, int> initialCounts;
  final ReactionChanged? onChanged;

  const ReactionBar({super.key, this.initialCounts = const {}, this.onChanged});

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late Map<String, int> _counts;
  late Set<String> _selected;

  final List<String> _available = ['❤️', '🔥', '👍', '😂', '😮'];

  @override
  void initState() {
    super.initState();
    _counts = Map<String, int>.from(widget.initialCounts);
    for (var a in _available) {
      _counts.putIfAbsent(a, () => 0);
    }
    _selected = <String>{};
  }

  void _toggle(String emoji) {
    setState(() {
      final was = _selected.contains(emoji);
      if (was) {
        _selected.remove(emoji);
        _counts[emoji] = (_counts[emoji] ?? 1) - 1;
      } else {
        _selected.add(emoji);
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      }
      widget.onChanged?.call(emoji, !was);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _available.map((e) {
        final count = _counts[e] ?? 0;
        final active = _selected.contains(e);
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: GestureDetector(
            onTap: () => _toggle(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white24 : Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(e, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text('$count', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
