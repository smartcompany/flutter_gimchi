import 'dart:ui';
import 'package:flutter/material.dart';

/// 리퀴드 글래스 스타일의 다이얼로그 (라이트/다크 테마 연동)
class LiquidGlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool barrierDismissible;
  final EdgeInsetsGeometry? contentPadding;
  final double? width;
  final double? height;

  const LiquidGlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.barrierDismissible = true,
    this.contentPadding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final glassTop = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.92)
        : cs.surfaceContainerHighest.withValues(alpha: 0.96);
    final glassBottom = isDark
        ? cs.surfaceContainerHigh.withValues(alpha: 0.88)
        : cs.surfaceContainerHigh.withValues(alpha: 0.9);
    final borderColor = cs.outline.withValues(alpha: isDark ? 0.45 : 0.25);
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ) ??
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: cs.onSurface,
          height: 1.5,
        ) ??
        TextStyle(
          fontSize: 16,
          color: cs.onSurface,
          height: 1.5,
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [glassTop, glassBottom],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: DefaultTextStyle(
                      style: titleStyle,
                      child: title!,
                    ),
                  ),
                if (content != null)
                  Flexible(
                    child: Padding(
                      padding: contentPadding ??
                          EdgeInsets.fromLTRB(
                            24,
                            0,
                            24,
                            actions != null && actions!.isNotEmpty ? 8 : 24,
                          ),
                      child: DefaultTextStyle(
                        style: bodyStyle,
                        child: content!,
                      ),
                    ),
                  ),
                if (actions != null && actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!
                          .map((action) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: action,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    EdgeInsetsGeometry? contentPadding,
    double? width,
    double? height,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LiquidGlassDialog(
        title: title,
        content: content,
        actions: actions,
        contentPadding: contentPadding,
        width: width,
        height: height,
      ),
    );
  }
}
