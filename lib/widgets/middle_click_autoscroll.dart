import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';

class MiddleClickAutoScroll extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;

  const MiddleClickAutoScroll({
    super.key,
    required this.child,
    required this.scrollController,
  });

  @override
  State<MiddleClickAutoScroll> createState() => _MiddleClickAutoScrollState();
}

class _MiddleClickAutoScrollState extends State<MiddleClickAutoScroll> {
  bool _isMiddleMouseDown = false;
  Offset? _initialPosition;
  Timer? _scrollTimer;
  double _scrollSpeed = 0;

  void _startScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (_scrollSpeed != 0) {
        widget.scrollController.jumpTo(
          (widget.scrollController.offset + _scrollSpeed).clamp(
            widget.scrollController.position.minScrollExtent,
            widget.scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSpeed = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse && event.buttons == kMiddleMouseButton) {
          _isMiddleMouseDown = true;
          _initialPosition = event.position;
        }
      },
      onPointerMove: (event) {
        if (_isMiddleMouseDown && _initialPosition != null) {
          final currentPosition = event.position;
          final dy = currentPosition.dy - _initialPosition!.dy;
          _scrollSpeed = dy * 0.5;
          _startScrolling();
        }
      },
      onPointerUp: (event) {
        if (_isMiddleMouseDown) {
          _isMiddleMouseDown = false;
          _initialPosition = null;
          _stopScrolling();
        }
      },
      onPointerCancel: (event) {
        if (_isMiddleMouseDown) {
          _isMiddleMouseDown = false;
          _initialPosition = null;
          _stopScrolling();
        }
      },
      child: widget.child,
    );
  }
}