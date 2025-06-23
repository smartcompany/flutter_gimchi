import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:intl/intl.dart';

// 사용자 ID 가져오기/생성 함수
Future<String> getOrCreateUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');
  if (userId == null) {
    userId = const Uuid().v4();
    await prefs.setString('user_id', userId);
  }
  return userId;
}

double gimchiPremium(double usdtPrice, double exchangerate) {
  return ((usdtPrice - exchangerate) / exchangerate * 100);
}

// iOS 시뮬레이터 여부 확인 함수
Future<bool> isIOSSimulator() async {
  if (!Platform.isIOS) return false;
  final deviceInfo = DeviceInfoPlugin();
  final iosInfo = await deviceInfo.iosInfo;
  return !iosInfo.isPhysicalDevice;
}

// IDFA 출력 함수 (iOS 전용)
Future<void> printIDFA() async {
  if (!kDebugMode) return;

  if (!Platform.isIOS) {
    print('IDFA는 iOS에서만 지원됩니다.');
    return;
  }
  try {
    final idfa = await AdvertisingId.id(true);
    print('IDFA: $idfa');
  } catch (e) {
    print('IDFA 가져오기 실패: $e');
  }
}

extension DateTimeCustomString on DateTime {
  /// 문자열이 DateTime으로 변환 가능하면 yyyy/MM/dd 포맷으로 반환, 아니면 null 반환
  String toCustomString() {
    return DateFormat('yyyy/MM/dd').format(this);
  }

  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

enum AdsStatus { unload, load, shown }

enum TodayCommentAlarmType { off, ai, kimchi }

extension TodayCommentAlarmTypePrefs on TodayCommentAlarmType {
  static const _prefsKey = 'todayCommentAlarmType';

  /// SharedPreferences에서 값을 읽어 TodayCommentAlarmType으로 반환
  static Future<TodayCommentAlarmType> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      return TodayCommentAlarmType.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => TodayCommentAlarmType.off,
      );
    }
    return TodayCommentAlarmType.off;
  }

  /// SharedPreferences에 값 저장
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, name);
  }
}
