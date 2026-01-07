import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usdt_signal/utils.dart';

typedef StrategyMap = Map<String, dynamic>;

class ChartData {
  final DateTime time;
  double value;
  ChartData(this.time, this.value);
}

class USDTChartData {
  final DateTime time;
  double open;
  double close;
  double high;
  double low;
  USDTChartData(this.time, this.open, this.close, this.high, this.low);
}

class ApiService {
  // 싱글톤 인스턴스
  static final ApiService shared = ApiService._internal();

  // Private 생성자
  ApiService._internal();

  static const int days = 200;
  static const String host = "https://rate-history.vercel.app";
  static const String upbitUsdtUrl = "$host/api/usdt-history?days=all";
  static const String rateHistoryUrl = "$host/api/rate-history?days=$days";
  static const String gimchHistoryUrl = "$host/api/gimch-history?days=$days";
  static const String strategyUrl = "$host/api/analyze-strategy";
  static const String fcmTokenUrl = "$host/api/fcm-token";
  static const String userDataUrl = "$host/api/user-data";
  static const String settingsUrl = "$host/api/settings";
  static const String airdropInfoUrl = "$host/api/airdrop-info";
  static const String latestUsdtUrl =
      'https://api.upbit.com/v1/ticker?markets=KRW-USDT';
  static const latestExchangeRateUrl = '$host/api/rate-history';

  // Settings 캐시
  Map<String, dynamic>? settings;

  Future<double?> fetchLatestUSDTData() async {
    try {
      // 업비트 API에서 최신 USDT 환율 정보 가져오기
      final response = await http.get(Uri.parse(latestUsdtUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)[0]; // API 응답에서 첫 번째 데이터 가져오기
        return data['trade_price']?.toDouble(); // trade_price 필드에서 환율 값 추출
      } else {
        print('USDT 데이터 가져오기 실패: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      print('USDT 데이터 가져오기 실패: $error');
      return null;
    }
  }

  Future<double?> fetchLatestExchangeRate() async {
    try {
      final resut = await fetchExchangeRateData(justLatest: true);
      if (resut.isNotEmpty) {
        // 가장 최근의 환율 데이터 반환
        resut.sort((a, b) => b.time.compareTo(a.time));
        return resut.first.value;
      } else {
        print('환율 데이터가 비어 있습니다.');
        return null;
      }
    } catch (e) {
      print('환율 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // USDT 데이터
  Future<Map<DateTime, USDTChartData>> fetchUSDTData() async {
    final response = await http.get(Uri.parse(upbitUsdtUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final Map<DateTime, USDTChartData> result = {};
      data.forEach((key, val) {
        final dateTime = DateTime.parse(key);
        final usdtChartData = USDTChartData(
          dateTime,
          val['open'].toDouble(),
          val['close'].toDouble(),
          val['high'].toDouble(),
          val['low'].toDouble(),
        );
        result[dateTime] = usdtChartData;
      });

      return result;
    } else {
      throw Exception("Failed to fetch USDT data: ${response.statusCode}");
    }
  }

  // 환율 데이터
  Future<List<ChartData>> fetchExchangeRateData({
    bool justLatest = false,
  }) async {
    try {
      final url = justLatest ? latestExchangeRateUrl : rateHistoryUrl;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<ChartData> rate = [];
        data.forEach((key, value) {
          rate.add(ChartData(DateTime.parse(key), value.toDouble()));
        });
        rate.sort((a, b) => a.time.compareTo(b.time));
        return rate;
      } else {
        print('환율 데이터 가져오기 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('환율 데이터 가져오기 실패: $e');
      return [];
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
  Future<List<StrategyMap>?> fetchStrategy() async {
    final response = await http.get(Uri.parse(strategyUrl));
    if (response.statusCode == 200) {
      final strategyText = utf8.decode(response.bodyBytes);
      try {
        final rawList = json.decode(strategyText);
        final converted =
            (rawList as List).map((item) {
              final map = StrategyMap.from(item);
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

  // 전략 데이터 + 김치 프리미엄 트렌드 데이터
  Future<Map<String, dynamic>?> fetchStrategyWithKimchiTrends() async {
    final response = await http.get(
      Uri.parse('$strategyUrl?includeKimchiTrends=true'),
    );
    if (response.statusCode == 200) {
      final responseText = utf8.decode(response.bodyBytes);
      try {
        final data = json.decode(responseText);

        // strategies 배열 변환
        if (data['strategies'] != null) {
          final strategies =
              (data['strategies'] as List).map((item) {
                // Map<String, dynamic>으로 안전하게 변환
                final Map<String, dynamic> map = {};
                (item as Map).forEach((key, value) {
                  final stringKey = key.toString();
                  map[stringKey] = value is int ? value.toDouble() : value;
                });
                return map;
              }).toList();
          data['strategies'] = strategies;
        }

        return data;
      } catch (e) {
        print('전략 + 김치 트렌드 파싱 에러: $e');
      }
      return null;
    } else {
      throw Exception(
        "Failed to fetch strategy with kimchi trends: ${response.statusCode}",
      );
    }
  }

  // FCM 토큰을 서버에 저장하는 함수
  Future<void> saveFcmTokenToServer(String token) async {
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

  // Settings 내부 로드 메서드
  Future<Map<String, dynamic>?> loadSettings() async {
    try {
      print('Settings 로드 시작: $settingsUrl');
      final response = await http.get(Uri.parse(settingsUrl));
      print('Settings 응답 상태: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('Settings 로드 성공: $json');

        // upbit_fees 확인
        final upbitFees = json['upbit_fees'] as Map<String, dynamic>?;
        if (upbitFees != null) {
          print('upbit_fees 발견: $upbitFees');
          print(
            'buy_fee: ${upbitFees['buy_fee']}, sell_fee: ${upbitFees['sell_fee']}',
          );
        } else {
          print('경고: upbit_fees가 없습니다!');
        }

        settings = json;
        return json;
      } else {
        print('Settings 로드 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Settings fetch 실패: $e');
      print('스택 트레이스: $stackTrace');
    }
    return null;
  }

  // Rewarded Ad Unit ID getter
  MapEntry<String, String>? get rewardedAdUnitId {
    try {
      final json = settings;
      if (json != null) {
        if (Platform.isIOS) {
          final key = json['ios_ad'] as String?;
          final iosRef = json['ref']?['ios'] as Map<String, dynamic>?;
          if (key != null && iosRef != null && iosRef.containsKey(key)) {
            final value = iosRef[key] as String?;
            if (value != null) {
              return MapEntry(key, value);
            }
          }
        } else if (Platform.isAndroid) {
          final key = json['android_ad'] as String?;
          final androidRef = json['ref']?['android'] as Map<String, dynamic>?;
          if (key != null &&
              androidRef != null &&
              androidRef.containsKey(key)) {
            final value = androidRef[key] as String?;
            if (value != null) {
              return MapEntry(key, value);
            }
          }
        }
      }
    } catch (e) {
      print('광고 ID 가져오기 실패: $e');
    }
    return null;
  }

  // Banner Ad Unit ID getter
  MapEntry<String, String>? get bannerAdUnitId {
    try {
      final json = settings;
      if (json != null) {
        if (Platform.isIOS) {
          final key = json['ios_banner_ad'] as String?;
          final iosRef = json['ref']?['ios'] as Map<String, dynamic>?;
          if (key != null && iosRef != null && iosRef.containsKey(key)) {
            final value = iosRef[key] as String?;
            if (value != null) {
              return MapEntry(key, value);
            }
          }
        } else if (Platform.isAndroid) {
          final key = json['android_banner_ad'] as String?;
          final androidRef = json['ref']?['android'] as Map<String, dynamic>?;
          if (key != null &&
              androidRef != null &&
              androidRef.containsKey(key)) {
            final value = androidRef[key] as String?;
            if (value != null) {
              return MapEntry(key, value);
            }
          }
        }
      }
    } catch (e) {
      print('배너 광고 ID 가져오기 실패: $e');
    }
    return null;
  }

  Future<bool> saveAndSyncUserData(
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

  // Air drop 정보 조회
  static Future<AirdropInfo?> fetchAirdropInfo() async {
    try {
      final response = await http.get(Uri.parse(airdropInfoUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return AirdropInfo.fromJson(json['data']);
        }
      }
      return null;
    } catch (e) {
      print('Air drop 정보 조회 실패: $e');
      return null;
    }
  }

  // 최신 뉴스 조회
  static Future<NewsItem?> fetchLatestNews() async {
    try {
      final response = await http
          .get(Uri.parse('https://coinpang.org/api/news?limit=1'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true &&
            json['data'] != null &&
            json['data'].isNotEmpty) {
          return NewsItem.fromJson(json['data'][0]);
        }
      }
      return null;
    } catch (e) {
      print('최신 뉴스 조회 실패: $e');
      return null;
    }
  }
}

// 뉴스 아이템 모델
class NewsItem {
  final int id;
  final String title;
  final String content;
  final String author;
  final DateTime createdAt;
  final int views;
  final int likes;

  NewsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.views,
    required this.likes,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      author: json['author'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
    );
  }
}

// Air drop 정보 모델
class AirdropInfo {
  final String id;
  final String title;
  final String description;
  final String reward;
  final String? link;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int priority;
  final String? imageUrl;

  AirdropInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    this.link,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.priority,
    this.imageUrl,
  });

  factory AirdropInfo.fromJson(Map<String, dynamic> json) {
    return AirdropInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      reward: json['reward'] ?? '',
      link: json['link'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      priority: json['priority'] ?? 0,
      imageUrl: json['imageUrl'],
    );
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
