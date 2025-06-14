import 'dart:convert';
import 'package:http/http.dart' as http;

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
}
