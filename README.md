# USDT Signal

USDT 시세 매매 도우미 앱 - 환율과 김치 프리미엄을 실시간으로 분석하여 테더 매매 타이밍을 알려주는 Flutter 앱입니다.

## 📱 주요 기능

### 핵심 기능
- **김치 프리미엄 자동 계산**: USDT 가격과 공식 USD/KRW 환율의 차이를 실시간으로 계산
- **AI 기반 매매 전략**: AI가 분석한 매수/매도 타이밍 및 전략 제공
- **김치 프리미엄 기반 전략**: 김치 프리미엄 트렌드를 활용한 매매 전략
- **실시간 차트**: USDT 가격, 환율, 김치 프리미엄을 시각화한 인터랙티브 차트
- **매매 시뮬레이션**: 과거 데이터를 기반으로 전략의 수익률을 시뮬레이션

### 추가 기능
- **푸시 알림**: 매매 타이밍 알림 (AI 전략 또는 김치 프리미엄 전략 선택 가능)
- **익명 채팅**: 앱 내 익명 채팅 기능
- **뉴스 통합**: 최신 암호화폐 뉴스 제공
- **다국어 지원**: 한국어, 영어, 중국어 지원
- **인앱 구매**: 광고 제거 옵션

## 🛠 기술 스택

- **Framework**: Flutter
- **상태 관리**: Flutter StatefulWidget
- **차트 라이브러리**: Syncfusion Flutter Charts, FL Chart
- **백엔드**: Firebase (Analytics, Crashlytics, Messaging, Auth, Firestore)
- **광고**: Google Mobile Ads
- **인앱 결제**: In-App Purchase

## 📦 설치 및 실행

### 사전 요구사항
- Flutter SDK (3.7.2 이상)
- Dart SDK
- iOS 개발: Xcode 및 CocoaPods
- Android 개발: Android Studio

### 실행 방법

```bash
# 의존성 설치
flutter pub get

# iOS (CocoaPods 설치 필요)
cd ios && pod install && cd ..

# 앱 실행
flutter run
```

## 📂 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점 및 메인 화면
├── api_service.dart         # API 통신 서비스
├── simulation_page.dart     # 매매 시뮬레이션 페이지
├── simulation_model.dart    # 시뮬레이션 로직
├── ChartOnlyPage.dart       # 차트 전용 페이지
├── OnboardingPage.dart     # 온보딩 페이지
├── anonymous_chat_page.dart # 익명 채팅 페이지
├── dialogs/                 # 다이얼로그 위젯
├── l10n/                    # 다국어 지원 파일
└── utils.dart               # 유틸리티 함수
```

## 🔗 다운로드

- **iOS**: [App Store](https://apps.apple.com/us/app/usdt-signal/id6746846210)
- **웹**: [웹 버전](https://smartcompany.github.io/flutter_gimchi/)

## 📧 문의

- 이메일: gunnylove@gmail.com

## 🔐 개인정보처리방침

[개인정보처리방침 보기](https://smartcompany.github.io/flutter_gimchi/web/privacy.html)

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.
