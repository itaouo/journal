import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ExpandableFabItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ExpandableFabItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class ExpandableFab extends StatefulWidget {
  final List<ExpandableFabItem> items;

  const ExpandableFab({
    super.key,
    required this.items,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> {
  bool _isOpen = false;

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _onItemTap(ExpandableFabItem item) {
    _close();
    item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_isOpen,
          child: AnimatedOpacity(
            opacity: _isOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black54),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _FabMenuItem(
                  item: widget.items[i],
                  isOpen: _isOpen,
                  index: i,
                  onTap: () => _onItemTap(widget.items[i]),
                ),
              FloatingActionButton(
                onPressed: _toggle,
                tooltip: _isOpen ? '關閉' : '新增',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isOpen ? Icons.close : Icons.add,
                    key: ValueKey(_isOpen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FabMenuItem extends StatelessWidget {
  final ExpandableFabItem item;
  final bool isOpen;
  final int index;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.item,
    required this.isOpen,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isOpen,
      child: AnimatedSlide(
        offset: isOpen ? Offset.zero : const Offset(0, 0.5),
        duration: Duration(milliseconds: 200 + index * 50),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: isOpen ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200 + index * 50),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: context.journalColors.cardBackground,
              elevation: 2,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: context.journalColors.sectionHeader,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: context.journalColors.sectionHeader,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
