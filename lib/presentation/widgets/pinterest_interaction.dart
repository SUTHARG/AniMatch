import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinterestMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onAction;

  PinterestMenuAction({
    required this.icon,
    required this.label,
    required this.onAction,
  });
}

class PinterestMenuWrapper extends StatefulWidget {
  final Widget child;
  final List<PinterestMenuAction> actions;

  const PinterestMenuWrapper({
    super.key,
    required this.child,
    required this.actions,
  });

  @override
  State<PinterestMenuWrapper> createState() => _PinterestMenuWrapperState();
}

class _PinterestMenuWrapperState extends State<PinterestMenuWrapper> {
  OverlayEntry? _overlayEntry;
  final GlobalKey<_PinterestMenuOverlayState> _overlayKey = GlobalKey();

  void _showMenu(BuildContext context, Offset globalPos) {
    _overlayEntry = OverlayEntry(
      builder: (context) => _PinterestMenuOverlay(
        key: _overlayKey,
        center: globalPos,
        actions: widget.actions,
        onClose: _hideMenu,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    HapticFeedback.heavyImpact();
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        _showMenu(context, details.globalPosition);
      },
      onLongPressMoveUpdate: (details) {
        _overlayKey.currentState?.updateTouch(details.globalPosition);
      },
      onLongPressEnd: (details) {
        _overlayKey.currentState?.finish();
      },
      onLongPressCancel: () {
        _overlayKey.currentState?.cancel();
      },
      child: widget.child,
    );
  }
}

class _PinterestMenuOverlay extends StatefulWidget {
  final Offset center;
  final List<PinterestMenuAction> actions;
  final VoidCallback onClose;

  const _PinterestMenuOverlay({
    super.key,
    required this.center,
    required this.actions,
    required this.onClose,
  });

  @override
  State<_PinterestMenuOverlay> createState() => _PinterestMenuOverlayState();
}

class _PinterestMenuOverlayState extends State<_PinterestMenuOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  int _selectedIndex = -1;
  static const double _radius = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller, 
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void updateTouch(Offset pos) {
    if (!mounted) return;
    final int newIndex = _getSelectedIndex(pos);
    if (newIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newIndex;
      });
      if (newIndex != -1) {
        HapticFeedback.lightImpact();
      }
    }
  }

  int _getSelectedIndex(Offset touchPos) {
    for (int i = 0; i < widget.actions.length; i++) {
      final iconPos = _getIconOffset(i);
      final dist = (touchPos - iconPos).distance;
      if (dist < 35) { // Selection radius
        return i;
      }
    }
    return -1;
  }

  Offset _getIconOffset(int index) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final center = widget.center;
    
    // Proximity detection
    final bool nearTop = center.dy < 200 + padding.top;
    final bool nearLeft = center.dx < 120;
    final bool nearRight = center.dx > screenSize.width - 120;
    
    // Determine base direction (pointing away from edges)
    double baseAngle = -math.pi / 2; // Default: Up
    double spread = 1.0; // Total arc spread in radians
    
    if (nearTop) {
      if (nearLeft) {
        baseAngle = math.pi / 4; // Down-Right
      } else if (nearRight) {
        baseAngle = 3 * math.pi / 4; // Down-Left
      } else {
        baseAngle = math.pi / 2; // Straight Down
      }
    } else {
      if (nearLeft) {
        baseAngle = -0.2; // Slightly Up-Right
      } else if (nearRight) {
        baseAngle = math.pi + 0.2; // Slightly Up-Left
      }
    }
    
    // Distribute icons around the base angle
    double angle;
    if (widget.actions.length > 1) {
      final start = baseAngle - (spread / 2);
      angle = start + (index * spread / (widget.actions.length - 1));
    } else {
      angle = baseAngle;
    }
    
    return center + Offset(
      math.cos(angle) * _radius,
      math.sin(angle) * _radius,
    );
  }

  void finish() {
    if (_selectedIndex != -1) {
      HapticFeedback.mediumImpact();
      widget.actions[_selectedIndex].onAction();
    }
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void cancel() {
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    
    // Calculate label position if an item is selected
    Widget? labelWidget;
    if (_selectedIndex != -1) {
      final rawPos = _getIconOffset(_selectedIndex);
      const double size = 58;
      const double radius = size / 2;
      final double posY = rawPos.dy.clamp(radius + padding.top + 10, screenSize.height - radius - padding.bottom - 10);

      labelWidget = Positioned(
        left: 0,
        right: 0,
        top: (posY - 80).clamp(padding.top + 10, screenSize.height - 100),
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Text(
                  widget.actions[_selectedIndex].label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.w900, 
                    fontSize: 11,
                    letterSpacing: 1.0
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Darken/Blur background
            Positioned.fill(
              child: FadeTransition(
                opacity: _controller,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
 
            // Icons
            ...List.generate(widget.actions.length, (index) {
              final rawPos = _getIconOffset(index);
              final isSelected = _selectedIndex == index;
              
              final double size = isSelected ? 58 : 48;
              final double radius = size / 2;
              final double posX = rawPos.dx.clamp(radius + 10, screenSize.width - radius - 10);
              final double posY = rawPos.dy.clamp(radius + padding.top + 10, screenSize.height - radius - padding.bottom - 10);
              
              return Positioned(
                left: posX - radius,
                top: posY - radius,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.amber : Colors.transparent,
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                    child: Center(
                      child: Icon(
                        widget.actions[index].icon,
                        color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.9),
                        size: isSelected ? 28 : 24,
                      ),
                    ),
                  ),
                ),
              );
            }),

            if (labelWidget != null) labelWidget,
          ],
        ),
      ),
    );
  }
}
