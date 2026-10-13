import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Área tocável com resposta tátil: encolhe levemente (sem alterar o layout),
/// ripple e haptic. Base de todos os cards e botões customizados.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.scale = 0.97,
    this.semanticLabel,
    this.haptic = true,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double scale;
  final String? semanticLabel;
  final bool haptic;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final anim = Motion.enabled(context);
    return Semantics(
      // Nó próprio: sem isso, um botão dentro de um card (ex.: "+") é fundido ao card.
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _down && anim ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.base,
        curve: _down ? Curves.easeOut : Motion.spring,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onTap == null
                ? null
                : () {
                    if (widget.haptic) HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
            onLongPress: widget.onLongPress,
            onHighlightChanged: enabled ? _set : null,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
