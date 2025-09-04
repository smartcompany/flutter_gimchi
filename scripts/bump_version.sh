#!/bin/bash

# pubspec.yaml 파일 경로
PUBSPEC_FILE="pubspec.yaml"

# 현재 버전 읽기
CURRENT_VERSION=$(grep "^version:" $PUBSPEC_FILE | sed 's/version: //')

# 버전을 분리 (예: 1.0.21+20)
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# 빌드 번호 증가
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))

# 새 버전 생성
NEW_VERSION="$VERSION_NAME+$NEW_BUILD_NUMBER"

# pubspec.yaml 업데이트
sed -i.bak "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC_FILE

# 백업 파일 삭제
rm -f $PUBSPEC_FILE.bak

echo "Version updated from $CURRENT_VERSION to $NEW_VERSION"

# App Bundle 빌드
echo "Building App Bundle..."
flutter build appbundle --release

echo "Build completed with version $NEW_VERSION"
