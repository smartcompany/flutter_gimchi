import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usdt_signal/utils.dart';

class ChartData {
  final DateTime time;
  final double value;
  ChartData(this.time, this.value);
}

class USDTChartData {
  final DateTime time;
  final double open;
  final double close;
  final double high;
  final double low;
  USDTChartData(this.time, this.open, this.close, this.high, this.low);
}

class ApiService {
  static const int days = 200;
  static const String upbitUsdtUrl =
      "https://rate-history.vercel.app/api/usdt-history?days=$days";
  static const String rateHistoryUrl =
      "https://rate-history.vercel.app/api/rate-history?days=$days";
  static const String gimchHistoryUrl =
      "https://rate-history.vercel.app/api/gimch-history?days=$days";
  static const String strategyUrl =
      "https://rate-history.vercel.app/api/analyze-strategy";
  static const String fcmTokenUrl =
      "https://rate-history.vercel.app/api/fcm-token";
  static const String userDataUrl =
      "https://rate-history.vercel.app/api/user-data";

  // USDT 데이터
  Future<Map<String, dynamic>> fetchUSDTData() async {
    final response = await http.get(Uri.parse(upbitUsdtUrl));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to fetch USDT data: ${response.statusCode}");
    }
  }

  // 환율 데이터
  Future<List<ChartData>> fetchExchangeRateData() async {
    final response = await http.get(Uri.parse(rateHistoryUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<ChartData> rate = [];
      data.forEach((key, value) {
        rate.add(ChartData(DateTime.parse(key), value.toDouble()));
      });
      rate.sort((a, b) => a.time.compareTo(b.time));
      return rate;
    } else {
      throw Exception("Failed to fetch data: ${response.statusCode}");
    }
  }

  // 김치 프리미엄 데이터
  Future<List<ChartData>> fetchKimchiPremiumData() async {
    final response = await http.get(Uri.parse(gimchHistoryUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final List<ChartData> premium = [];
      data.forEach((key, value) {
        premium.add(ChartData(DateTime.parse(key), value.toDouble()));
      });
      premium.sort((a, b) => a.time.compareTo(b.time));
      return premium;
    } else {
      throw Exception("Failed to fetch kimchi premium: ${response.statusCode}");
    }
  }

  // 전략 데이터
  Future<List?> fetchStrategy() async {
    final response = await http.get(Uri.parse(strategyUrl));
    if (response.statusCode == 200) {
      final strategyText = utf8.decode(response.bodyBytes);
      try {
        final rawList = json.decode(strategyText);
        // 모든 숫자 필드를 double로 변환
        final converted =
            (rawList as List).map((item) {
              final map = Map<String, dynamic>.from(item);
              map.updateAll(
                (key, value) => value is int ? value.toDouble() : value,
              );
              return map;
            }).toList();
        return converted;
      } catch (e) {
        print('전략 파싱 에러: $e');
      }
      return null;
    } else {
      throw Exception("Failed to fetch strategy: ${response.statusCode}");
    }
  }

  // FCM 토큰을 서버에 저장하는 함수
  static Future<void> saveFcmTokenToServer(String token) async {
    try {
      final userId = await getOrCreateUserId();
      final response = await http.post(
        Uri.parse(ApiService.fcmTokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'userId': userId,
        }),
      );
      if (response.statusCode == 200) {
        print('FCM 토큰 서버 저장 성공');
      } else {
        print('FCM 토큰 서버 저장 실패: ${response.body}');
      }
    } catch (e) {
      print('FCM 토큰 서버 저장 에러: $e');
    }
  }

  static Future<bool> saveAndSyncUserData(
    Map<UserDataKey, dynamic> newUserData,
  ) async {
    final userId = await getOrCreateUserId();
    final prefs = await SharedPreferences.getInstance();
    // 기존 데이터 읽기
    final oldJson = prefs.getString('userData');

    Map<UserDataKey, dynamic> oldUserData = {};
    if (oldJson != null) {
      final data = Map<String, dynamic>.from(jsonDecode(oldJson));
      // 키를 UserDataKey로 변환
      oldUserData = {
        for (var key in UserDataKey.values) key: data[key.key] ?? null,
      };
    }

    // merge
    final mergedUserData = {...oldUserData, ...newUserData};

    try {
      final response = await http.post(
        Uri.parse(ApiService.userDataUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'userData': {
            for (var entry in mergedUserData.entries)
              entry.key.key: entry.value,
          },
        }),
      );
      if (response.statusCode == 200) {
        print('사용자 데이터 서버 저장 성공');
        // 서버 저장 성공 시에만 로컬에도 저장
        await prefs.setString(
          'userData',
          jsonEncode({
            for (var entry in mergedUserData.entries)
              entry.key.key: entry.value,
          }),
        );
        return true;
      } else {
        print('사용자 데이터 서버 저장 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('사용자 데이터 서버 저장 에러: $e');
      // 에러 발생 시 로컬에 저장하지 않음
      return false;
    }
  }
}

enum UserDataKey { pushType, gimchiBuyPercent, gimchiSellPercent }

extension UserDataKeyExt on UserDataKey {
  String get key {
    switch (this) {
      case UserDataKey.pushType:
        return 'pushType';
      case UserDataKey.gimchiBuyPercent:
        return 'gimchiBuyPercent';
      case UserDataKey.gimchiSellPercent:
        return 'gimchiSellPercent';
    }
  }
}
