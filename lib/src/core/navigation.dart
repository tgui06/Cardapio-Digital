import 'package:flutter/material.dart';

import 'theme/app_palette.dart';
import 'theme/tokens.dart';

/// Página cheia com fade + leve subida (sensação de "camada" acima do cardápio).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings, super.fullscreenDialog})
    : super(
        transitionDuration: Motion.page,
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          if (!Motion.enabled(context)) return child;
          final a = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
              child: child,
            ),
          );
        },
      );
}

/// Painel modal centralizado (tablet/totem) com scrim e escala de entrada.
class AppDialogRoute<T> extends PageRouteBuilder<T> {
  AppDialogRoute({required WidgetBuilder builder, required Color barrier, super.settings})
    : super(
        opaque: false,
        barrierDismissible: true,
        barrierColor: barrier,
        barrierLabel: 'Fechar',
        transitionDuration: Motion.slow + const Duration(milliseconds: 40),
        reverseTransitionDuration: Motion.base,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          if (!Motion.enabled(context)) return FadeTransition(opacity: animation, child: child);
          final a = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
          return FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
          );
        },
      );
}

Future<T?> pushPage<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(AppPageRoute<T>(builder: builder));

/// Abre como página no celular e como painel modal no tablet.
Future<T?> pushAdaptive<T>(BuildContext context, WidgetBuilder builder) {
  if (context.isCompact) return pushPage<T>(context, builder);
  return Navigator.of(context).push<T>(AppDialogRoute<T>(builder: builder, barrier: context.palette.scrim));
}
