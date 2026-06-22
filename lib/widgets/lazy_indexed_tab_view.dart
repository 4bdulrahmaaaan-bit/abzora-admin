import 'package:flutter/material.dart';

class LazyIndexedTabView extends StatefulWidget {
  const LazyIndexedTabView({
    super.key,
    required this.length,
    required this.itemBuilder,
    this.controller,
  });

  final int length;
  final IndexedWidgetBuilder itemBuilder;
  final TabController? controller;

  @override
  State<LazyIndexedTabView> createState() => _LazyIndexedTabViewState();
}

class _LazyIndexedTabViewState extends State<LazyIndexedTabView> {
  TabController? _controller;
  late List<Widget?> _cache;

  @override
  void initState() {
    super.initState();
    _cache = List<Widget?>.filled(widget.length, null, growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachController(widget.controller ?? DefaultTabController.maybeOf(context));
  }

  @override
  void didUpdateWidget(covariant LazyIndexedTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.length != widget.length) {
      _cache = List<Widget?>.filled(widget.length, null, growable: false);
    }
    if (oldWidget.controller != widget.controller) {
      _attachController(widget.controller ?? DefaultTabController.maybeOf(context));
    }
  }

  void _attachController(TabController? next) {
    if (identical(_controller, next)) {
      return;
    }
    _controller?.removeListener(_handleControllerChanged);
    _controller = next;
    _controller?.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller ?? DefaultTabController.maybeOf(context);
    final currentIndex = controller?.index ?? 0;
    if (currentIndex >= 0 && currentIndex < widget.length && _cache[currentIndex] == null) {
      _cache[currentIndex] = widget.itemBuilder(context, currentIndex);
    }

    return IndexedStack(
      index: currentIndex.clamp(0, widget.length - 1),
      children: List<Widget>.generate(widget.length, (index) {
        final cached = _cache[index];
        if (cached != null) {
          return cached;
        }
        if (index == currentIndex) {
          return _cache[index] = widget.itemBuilder(context, index);
        }
        return const SizedBox.shrink();
      }),
    );
  }
}
