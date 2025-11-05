import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

/// 뉴스 스플래시 뷰 위젯
/// 전체 화면 오버레이로 최신 뉴스를 표시합니다.
class NewsSplashView extends StatelessWidget {
  final NewsItem news;
  final VoidCallback onDismiss;

  const NewsSplashView({
    super.key,
    required this.news,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7), // 반투명 배경
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더 (아이콘 + 닫기 버튼)
                _buildHeader(),
                // 스크롤 가능한 내용
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목
                        _buildTitle(),
                        const SizedBox(height: 16),
                        // 작성자 정보
                        _buildAuthorInfo(),
                        const SizedBox(height: 20),
                        // 내용
                        _buildContent(),
                        const SizedBox(height: 24),
                        // 코인 정보 더 보기 링크
                        _buildMoreInfoLink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.article, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Coin News',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.close, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      news.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.4,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
    );
  }

  Widget _buildAuthorInfo() {
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          news.author,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.visibility_outlined,
          color: Colors.white.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          '${news.views}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return SelectableText(
      news.content,
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.7,
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
        shadows: [
          Shadow(
            offset: const Offset(0, 1),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreInfoLink() {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://coinpang.org');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '코인 정보 더 보기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
