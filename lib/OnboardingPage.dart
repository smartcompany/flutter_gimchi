import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback? onFinish;
  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> slides = [
    _OnboardingSlide(
      title: "USDT는 단순한 달러가 아닙니다",
      body:
          "1 USDT ≒ 1 USD이지만, 거래소·시세·환율에 따라 실제 가격은 달라요.\n"
          "특히 한국에서는 ‘김치 프리미엄’과 ‘환율 차이’로 시세 차이가 자주 발생합니다.",
      image: Icons.show_chart, // 실제 앱에서는 이미지로 교체
      imageDesc: "한국 vs 해외 USDT 가격 비교 그래프",
    ),
    _OnboardingSlide(
      title: "똑같은 1달러, 왜 가격이 다를까?",
      body:
          "예: 해외에서 1 USDT를 1,350원에 사고, 한국에서 1,370원에 팔면 20원 이익.\n"
          "이런 식으로 시세 차이만으로 수익을 낼 수 있습니다.",
      image: Icons.swap_horiz,
      imageDesc: "1 USDT → 사고 → 송금 → 팔기 흐름 다이어그램",
    ),
    _OnboardingSlide(
      title: "매수/매도 타이밍? 우리가 알려드려요",
      body:
          "김치 프리미엄, 환율, 해외 시세를 실시간 분석해서\n"
          "“지금 사세요 / 지금 파세요”를 AI가 시그널로 알려줍니다.",
      image: Icons.notifications_active,
      imageDesc: "실제 앱 화면 캡처 예시 (매수 시그널 알림)",
    ),
    _OnboardingSlide(
      title: "만약 100만원으로 시작했다면?",
      body: "실제 과거 데이터를 기반으로, 우리 전략을 썼을 때 수익률 보여주기",
      image: Icons.show_chart,
      imageDesc: "날짜별 자산 변화 시각화",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      child: const Text("이전"),
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
                      _currentPage == slides.length - 1 ? "시작하기" : "다음",
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
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          ),
        ],
      ),
    );
  }
}
