import 'dart:ui';
import 'package:flutter/material.dart';

/// 리퀴드 글래스 색상 팔레트
class _GlassColors {
  static const primaryGradient = [
    Color(0xFF667EEA), // 보라색
    Color(0xFF764BA2), // 진한 보라색
  ];

  static const glassWhite = Color(0xFFFFFFFF);
  static const glassBorder = Color(0x30FFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
}

/// 리퀴드 글래스 스타일의 다이얼로그
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _GlassColors.glassWhite.withOpacity(0.95),
                  _GlassColors.glassWhite.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _GlassColors.glassBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _GlassColors.primaryGradient[0].withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _GlassColors.textPrimary,
                      ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          color: _GlassColors.textPrimary,
                          height: 1.5,
                        ),
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

  /// 간단한 AlertDialog 스타일의 리퀴드 글래스 다이얼로그 표시
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

