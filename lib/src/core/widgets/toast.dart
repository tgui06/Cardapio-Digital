import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_palette.dart';
import '../theme/tokens.dart';

OverlayEntry? _current;
Timer? _timer;

/// Aviso discreto no topo da tela (não briga com a barra da sacola embaixo).
void showToast(BuildContext context, String message, {IconData icon = LucideIcons.circleCheck, bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _timer?.cancel();
  _current?.remove();
  final key = GlobalKey<_ToastState>();
  final entry = OverlayEntry(
    builder: (_) => _Toast(key: key, message: message, icon: icon, error: error),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(const Duration(milliseconds: 2200), () async {
    await key.currentState?.hide();
    if (_current == entry) {
      entry.remove();
      _current = null;
    }
  });
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.message, required this.icon, required this.error});

  final String message;
  final IconData icon;
  final bool error;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow)..forward();

  Future<void> hide() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = CurvedAnimation(parent: _c, curve: Motion.spring, reverseCurve: Motion.exit);
    final color = widget.error ? p.danger : p.success;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + Space.md,
      left: Space.md,
      right: Space.md,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: Radii.rPill,
                      border: Border.all(color: p.outlineStrong),
                      boxShadow: [BoxShadow(color: p.shadow, blurRadius: 28, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: color, size: 22),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge,
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
      ),
    );
  }
}
