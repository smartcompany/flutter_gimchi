import 'package:flutter/material.dart';
import 'package:usdt_signal/theme/app_theme.dart';
import 'package:usdt_signal/utils.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
      child: Builder(
        builder: (context) {
          final List<_OnboardingSlide> slides = [
            _OnboardingSlide(
              title: l10n(context).onboardingTitle1,
              body: l10n(context).onboardingBody1,
              image: Icons.show_chart,
              imageDesc: l10n(context).onboardingImageDesc1,
            ),
            _OnboardingSlide(
              title: l10n(context).onboardingTitle2,
              body: l10n(context).onboardingBody2,
              image: Icons.swap_horiz,
              imageDesc: l10n(context).onboardingImageDesc2,
            ),
            _OnboardingSlide(
              title: l10n(context).onboardingTitle3,
              body: l10n(context).onboardingBody3,
              image: Icons.notifications_active,
              imageDesc: l10n(context).onboardingImageDesc3,
            ),
            _OnboardingSlide(
              title: l10n(context).onboardingTitle4,
              body: l10n(context).onboardingBody4,
              image: Icons.insights,
              imageDesc: l10n(context).onboardingImageDesc4,
            ),
          ];

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Material(
                    color: cs.surfaceContainerHigh.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: Icon(Icons.close, color: cs.onSurface, size: 22),
                      onPressed: () => widget.onFinish?.call(),
                    ),
                  ),
                ),
              ],
            ),
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surface,
                    cs.primaryContainer.withValues(alpha: 0.35),
                    cs.surfaceContainerLow,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: slides.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder:
                            (context, i) =>
                                _OnboardingSlideWidget(slide: slides[i]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(slides.length, (i) {
                          final active = _currentPage == i;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: active ? 28 : 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: active
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(
                                      alpha: 0.8,
                                    ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: AppTheme.screenPadding.copyWith(top: 0),
                      child: Row(
                        children: [
                          if (_currentPage > 0)
                            TextButton(
                              onPressed: () {
                                _controller.previousPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              child: Text(l10n(context).previous),
                            )
                          else
                            const SizedBox(width: 72),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              if (_currentPage < slides.length - 1) {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              } else {
                                widget.onFinish?.call();
                              }
                            },
                            child: Text(
                              _currentPage == slides.length - 1
                                  ? l10n(context).start
                                  : l10n(context).next,
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String body;
  final IconData image;
  final String imageDesc;
  _OnboardingSlide({
    required this.title,
    required this.body,
    required this.image,
    required this.imageDesc,
  });
}

class _OnboardingSlideWidget extends StatelessWidget {
  final _OnboardingSlide slide;
  const _OnboardingSlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: AppTheme.screenPadding.copyWith(top: 8, bottom: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.brandGradient[0].withValues(alpha: 0.95),
                          AppTheme.brandGradient[1].withValues(alpha: 0.95),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Icon(
                        slide.image,
                        size: 48,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    slide.imageDesc,
                    style: tt.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    slide.title,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.body,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
