import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    final List<_OnboardingSlide> slides = [
      _OnboardingSlide(
        title: l10n(context).onboardingTitle1,
        body: l10n(context).onboardingBody1,
        image: Icons.show_chart, // 실제 앱에서는 이미지로 교체
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
        image: Icons.show_chart,
        imageDesc: l10n(context).onboardingImageDesc4,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // 왼쪽 뒤로가기 버튼 제거
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87, size: 20),
              onPressed: () {
                widget.onFinish?.call(); // 온보딩 종료
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder:
                    (context, i) => _OnboardingSlideWidget(slide: slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16,
                  ),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == i
                            ? Colors.deepPurple
                            : Colors.grey[300],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                      },
                      child: Text(l10n(context).previous),
                    )
                  else
                    const SizedBox(width: 60),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < slides.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                      } else {
                        widget.onFinish?.call(); // 온보딩 종료 콜백
                      }
                    },
                    child: Text(
                      _currentPage == slides.length - 1
                          ? l10n(context).start
                          : l10n(context).next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.image, size: 100, color: Colors.deepPurple),
          const SizedBox(height: 16),
          Text(
            slide.imageDesc,
            style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
            softWrap: true, // 자동 줄바꿈 허용
            maxLines: 5, // 최대 5줄까지만 표시
          ),
        ],
      ),
    );
  }
}
