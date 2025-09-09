import 'dart:math';
import 'utils.dart';
import 'simulation_page.dart';
import 'api_service.dart';

class SimulationModel {
  // 임계값 조정 민감도 계수 (필요시 손쉽게 조정 가능)
  static const double buyTrendCoefficient = 0.6; // 매수: 추세 반응 강도
  static const double buyMa5Coefficient = 0.3; // 매수: MA5 반응 강도
  static const double sellTrendCoefficient = 1.2; // 매도: 추세 반응 강도
  static const double sellMa5Coefficient = 0.5; // 매도: MA5 반응 강도
  // 특정 날짜부터 usdtMap 데이터를 조회하는 함수
  static List<MapEntry<DateTime, dynamic>> getEntriesFromDate(
    Map<DateTime, dynamic> usdtMap,
    DateTime? startDate,
  ) {
    if (startDate == null) {
      // startDate가 null인 경우 전체 데이터를 반환
      return usdtMap.entries.toList();
    }

    // 날짜 오름차순 정렬
    final sortedEntries =
        usdtMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // 특정 날짜 이후의 데이터 필터링
    return sortedEntries
        .where((entry) => entry.key.compareTo(startDate) >= 0)
        .toList();
  }

  // simResults 생성 로직을 별도 함수로 분리
  static List<SimulationResult> simulateResults(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    // 날짜 오름차순 정렬
    strategyList.sort((a, b) {
      final dateA = a['analysis_date'];
      final dateB = b['analysis_date'];
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    final Map<DateTime, StrategyMap> strategyMap = {
      for (var strat in strategyList)
        if (strat['analysis_date'] != null)
          DateTime.parse(strat['analysis_date']): strat,
    };

    // 2. usdExchangeRateMap 생성
    final usdExchangeRateMap = {
      for (var rate in usdExchangeRates) rate.time: rate.value,
    };

    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    DateTime? sellDate;
    DateTime? buyDate;
    DateTime? strategyDate = DateTime.parse(
      strategyList.first['analysis_date'],
    );

    final filteredEntries = getEntriesFromDate(usdtMap, strategyDate);

    Map<String, dynamic>? strategy = strategyMap[strategyDate];
    double buyPrice = 0;

    for (final entry in filteredEntries) {
      final date = entry.key;
      final newStrategy = strategyMap[date];
      if (newStrategy != null) {
        strategy = newStrategy;
        strategyDate = date;
      }

      final double? buyStrategyPrice = _toDouble(strategy?['buy_price']);
      final double? sellStrategyPrice = _toDouble(strategy?['sell_price']);
      final lowPrice = usdtMap[date]?.low ?? 0;
      final highPrice = usdtMap[date]?.high ?? 0;

      if (buyStrategyPrice == null || sellStrategyPrice == null) {
        continue;
      }

      if (buyDate == null && sellDate == null) {
        if (lowPrice <= buyStrategyPrice) {
          buyDate = date;
          // 매수 예상가가 고가 보다 낮은 경우는 고가로 매수가 현실적
          buyPrice = min(buyStrategyPrice, highPrice);
        }
        if (buyDate == null) continue;
      }

      final high = usdtMap[date]?.high ?? 0;
      final canSell = _isSellCondition(usdtMap, date, buyDate!);

      if (canSell && high >= sellStrategyPrice) {
        sellDate = date;

        // 매도 예상가가 저가 보다 높은 경우는 저가로 매도가 현실적
        final sellPrice = max(sellStrategyPrice, lowPrice);

        totalKRW = _addResultCard(
          sellDate,
          date,
          buyPrice,
          sellPrice,
          totalKRW,
          simResults,
          buyDate,
          usdExchangeRateMap,
        );

        buyDate = null;
        sellDate = null;
        unselledResult = null;
      } else {
        final usdtPrice = usdtMap[date]?.close;
        final usdtCount = totalKRW / buyPrice;
        final finalKRW = usdtCount * (usdtPrice ?? 0);

        unselledResult = SimulationResult(
          analysisDate: date,
          buyDate: buyDate,
          buyPrice: buyPrice,
          sellDate: null,
          sellPrice: null,
          profit: 0,
          profitRate: 0,
          finalKRW: finalKRW,
          finalUSDT: usdtCount,
          usdExchangeRateAtBuy: usdExchangeRateMap[buyDate],
          usdExchangeRateAtSell: null, // 매도 시점은 아직 없음
        );
      }
    }

    if (unselledResult != null) {
      simResults.add(unselledResult);
    }

    return simResults;
  }

  static double _addResultCard(
    DateTime sellDate,
    DateTime date,
    double buyPrice,
    double? sellPrice,
    double totalKRW,
    List<SimulationResult> simResults,
    DateTime? buyDate,
    Map<DateTime, double> usdExchangeRateMap,
  ) {
    print('Sell condition met: sellDate=$sellDate anaysisDate=$date');

    double usdtAmount = totalKRW / buyPrice;
    double? finalKRW;
    double? profit;
    double? profitRate;

    finalKRW = usdtAmount * (sellPrice ?? 0); // 매도 시 최종 원화 계산
    profit = finalKRW - totalKRW;
    profitRate = profit / totalKRW * 100;
    totalKRW = finalKRW; // 누적 투자금 갱신(복리)
    print(
      'Transaction complete: finalKRW=$finalKRW, profit=$profit, profitRate=$profitRate',
    );

    simResults.add(
      SimulationResult(
        analysisDate: date,
        buyDate: buyDate!,
        buyPrice: buyPrice,
        sellDate: sellDate,
        sellPrice: sellPrice,
        profit: profit,
        profitRate: profitRate,
        finalKRW: finalKRW,
        finalUSDT: null,
        usdExchangeRateAtBuy: usdExchangeRateMap[buyDate],
        usdExchangeRateAtSell: usdExchangeRateMap[sellDate],
      ),
    );
    return totalKRW;
  }

  // 김치 프리미엄 추세, 환율 추세, USDT 추세를 고려해 김치 프리미엄 매매 전략을 생성하는 함수
  static Map<DateTime, Map<String, double>> generatePremiumTrends(
    List<ChartData> usdExchangeRates,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    Map<DateTime, Map<String, double>> strategies = {};

    // 1. 김치 프리미엄 데이터 계산
    List<ChartData> kimchiPremiumData = _calculateKimchiPremiumData(
      usdExchangeRates,
      usdtMap,
    );

    // 2. 김치 프리미엄 추세 분석
    List<double> kimchiTrends = _calculateKimchiTrends(kimchiPremiumData);

    // 3. 환율 추세 분석
    List<double> exchangeRateTrends = _calculateExchangeRateTrends(
      usdExchangeRates,
    );

    // 4. USDT 추세 분석
    List<double> usdtTrends = _calculateUsdtTrends(usdtMap);

    // 5. 추세를 기반으로 매수/매도 임계값 동적 조정
    for (int i = 0; i < kimchiPremiumData.length; i++) {
      final date = kimchiPremiumData[i].time;

      // 현재 추세 값들
      final kimchiTrend = i < kimchiTrends.length ? kimchiTrends[i] : 0.0;
      final exchangeRateTrend =
          i < exchangeRateTrends.length ? exchangeRateTrends[i] : 0.0;
      final usdtTrend = i < usdtTrends.length ? usdtTrends[i] : 0.0;

      // 5일 이동평균 계산
      double kimchiMA5 = 0.0;
      if (i >= 4) {
        // 5일 이상의 데이터가 있을 때
        double sum = 0.0;
        for (int j = i - 4; j <= i; j++) {
          sum += kimchiPremiumData[j].value;
        }
        kimchiMA5 = sum / 5.0;
      }

      // 추세를 기반으로 매수/매도 임계값 계산 (kimchiMA5도 고려)
      final adjustedBuyThreshold = _calculateAdjustedThreshold(
        SimulationCondition.instance.kimchiBuyThreshold,
        kimchiTrend,
        exchangeRateTrend,
        usdtTrend,
        true, // 매수 임계값
        kimchiMA5, // 5일 이동평균 추가
      );

      final adjustedSellThreshold = _calculateAdjustedThreshold(
        SimulationCondition.instance.kimchiSellThreshold,
        kimchiTrend,
        exchangeRateTrend,
        usdtTrend,
        false, // 매도 임계값
        kimchiMA5, // 5일 이동평균 추가
      );

      // 전략 저장
      strategies[date] = {
        'buy_threshold': adjustedBuyThreshold,
        'sell_threshold': adjustedSellThreshold,
        'kimchi_trend': kimchiTrend,
        'kimchi_ma5': kimchiMA5,
        'exchange_rate_trend': exchangeRateTrend,
        'usdt_trend': usdtTrend,
      };
    }

    return strategies;
  }

  // 김치 프리미엄 데이터 계산
  static List<ChartData> _calculateKimchiPremiumData(
    List<ChartData> usdExchangeRates,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    List<ChartData> kimchiData = [];

    for (final rate in usdExchangeRates) {
      final usdtData = usdtMap[rate.time];
      if (usdtData != null) {
        final kimchiPremium =
            ((usdtData.close - rate.value) / rate.value * 100);
        kimchiData.add(ChartData(rate.time, kimchiPremium));
      } else {
        // 날짜 매칭을 위해 가장 가까운 날짜 찾기
        DateTime? closestDate;
        double minDiff = double.infinity;

        for (final usdtDate in usdtMap.keys) {
          final diff = (rate.time.difference(usdtDate).inDays).abs();
          if (diff < minDiff) {
            minDiff = diff.toDouble();
            closestDate = usdtDate;
          }
        }

        if (closestDate != null && minDiff <= 1) {
          // 1일 이내 차이
          final usdtData = usdtMap[closestDate]!;
          final kimchiPremium =
              ((usdtData.close - rate.value) / rate.value * 100);
          kimchiData.add(ChartData(rate.time, kimchiPremium));
        }
      }
    }

    return kimchiData;
  }

  // 김치 프리미엄 추세 계산 (이동평균 기반)
  static List<double> _calculateKimchiTrends(List<ChartData> kimchiData) {
    List<double> trends = [];
    const int windowSize = 5; // 5일 이동평균

    for (int i = 0; i < kimchiData.length; i++) {
      if (i < windowSize - 1) {
        trends.add(0.0); // 초기 데이터는 추세 없음
        continue;
      }

      // 이동평균 계산
      double sum = 0.0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        sum += kimchiData[j].value;
      }
      final movingAverage = sum / windowSize;

      // 추세 계산 (현재값 - 이동평균)
      final trend = kimchiData[i].value - movingAverage;
      trends.add(trend);
    }

    return trends;
  }

  // 환율 추세 계산
  static List<double> _calculateExchangeRateTrends(
    List<ChartData> exchangeRates,
  ) {
    List<double> trends = [];
    const int windowSize = 5;

    for (int i = 0; i < exchangeRates.length; i++) {
      if (i < windowSize - 1) {
        trends.add(0.0);
        continue;
      }

      double sum = 0.0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        sum += exchangeRates[j].value;
      }
      final movingAverage = sum / windowSize;
      final trend = exchangeRates[i].value - movingAverage;
      trends.add(trend);
    }

    return trends;
  }

  // USDT 추세 계산
  static List<double> _calculateUsdtTrends(
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    List<double> trends = [];
    final sortedDates = usdtMap.keys.toList()..sort();
    const int windowSize = 5;

    for (int i = 0; i < sortedDates.length; i++) {
      if (i < windowSize - 1) {
        trends.add(0.0);
        continue;
      }

      double sum = 0.0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        sum += usdtMap[sortedDates[j]]?.close ?? 0.0;
      }
      final movingAverage = sum / windowSize;
      final currentPrice = usdtMap[sortedDates[i]]?.close ?? 0.0;
      final trend = currentPrice - movingAverage;
      trends.add(trend);
    }

    return trends;
  }

  // 추세에 따라 조정된 임계값 계산 (김치 프리미엄 추세와 5일 이동평균 고려)
  static double _calculateAdjustedThreshold(
    double baseThreshold,
    double kimchiTrend,
    double exchangeRateTrend, // 사용하지 않음
    double usdtTrend, // 사용하지 않음
    bool isBuyThreshold,
    double kimchiMA5, // 5일 이동평균 추가
  ) {
    // 연속 스케일 조정: 추세와 수준을 모두 반영 (단위: %)
    // - kimchiTrend: 현재값 - MA5 (방향/속도) → 더 크게 반응
    // - kimchiMA5: 절대 수준 (고/저 수준) → 보조 가중치
    final double trendCoefficient =
        isBuyThreshold ? buyTrendCoefficient : sellTrendCoefficient;
    final double ma5Coefficient =
        isBuyThreshold ? buyMa5Coefficient : sellMa5Coefficient;

    double adjustedThreshold =
        baseThreshold +
        trendCoefficient * kimchiTrend +
        ma5Coefficient * kimchiMA5;

    // 임계값 범위 제한 (기본값의 20% ~ 500%)
    final double minThreshold = baseThreshold * 0.2;
    final double maxThreshold = baseThreshold * 5.0;
    return adjustedThreshold.clamp(minThreshold, maxThreshold);
  }

  // 디버그용: 김치 프리미엄 전략 생성 테스트
  static void testGeneratePremiumTrends() {
    print('=== 김치 프리미엄 전략 생성 테스트 ===');

    // 테스트 데이터 생성
    final exchangeRates = [
      ChartData(DateTime(2024, 1, 1), 1300.0),
      ChartData(DateTime(2024, 1, 2), 1310.0),
      ChartData(DateTime(2024, 1, 3), 1320.0),
      ChartData(DateTime(2024, 1, 4), 1315.0),
      ChartData(DateTime(2024, 1, 5), 1330.0),
      ChartData(DateTime(2024, 1, 6), 1325.0),
      ChartData(DateTime(2024, 1, 7), 1340.0),
    ];

    final usdtMap = {
      DateTime(2024, 1, 1): USDTChartData(
        DateTime(2024, 1, 1),
        1300.0,
        1305.0,
        1310.0,
        1295.0,
      ),
      DateTime(2024, 1, 2): USDTChartData(
        DateTime(2024, 1, 2),
        1305.0,
        1315.0,
        1320.0,
        1300.0,
      ),
      DateTime(2024, 1, 3): USDTChartData(
        DateTime(2024, 1, 3),
        1315.0,
        1325.0,
        1330.0,
        1310.0,
      ),
      DateTime(2024, 1, 4): USDTChartData(
        DateTime(2024, 1, 4),
        1325.0,
        1320.0,
        1325.0,
        1315.0,
      ),
      DateTime(2024, 1, 5): USDTChartData(
        DateTime(2024, 1, 5),
        1320.0,
        1335.0,
        1340.0,
        1315.0,
      ),
      DateTime(2024, 1, 6): USDTChartData(
        DateTime(2024, 1, 6),
        1335.0,
        1330.0,
        1335.0,
        1325.0,
      ),
      DateTime(2024, 1, 7): USDTChartData(
        DateTime(2024, 1, 7),
        1330.0,
        1345.0,
        1350.0,
        1325.0,
      ),
    };

    final strategies = generatePremiumTrends(exchangeRates, usdtMap);

    print('생성된 전략 수: ${strategies.length}');
    print('기본 매수 기준: 0.5%, 기본 매도 기준: 2.0%');
    print('');

    final sortedDates = strategies.keys.toList()..sort();
    for (final date in sortedDates) {
      final strategy = strategies[date]!;
      print('=== ${date.toIso8601String().split('T')[0]} ===');
      print('매수 기준: ${strategy['buy_threshold']?.toStringAsFixed(2)}%');
      print('매도 기준: ${strategy['sell_threshold']?.toStringAsFixed(2)}%');
      print('김치 추세: ${strategy['kimchi_trend']?.toStringAsFixed(3)}');
      print('김치 MA5: ${strategy['kimchi_ma5']?.toStringAsFixed(3)}%');
      print('환율 추세: ${strategy['exchange_rate_trend']?.toStringAsFixed(3)}');
      print('USDT 추세: ${strategy['usdt_trend']?.toStringAsFixed(3)}');
      print('');
    }
  }

  // 김치 프리미엄 계산 헬퍼 함수
  static double _calculateKimchiPremium(double usdtPrice, double exchangeRate) {
    return ((usdtPrice - exchangeRate) / exchangeRate * 100);
  }

  static (double, double) getKimchiThresholds({
    required Map<String, double>? trendData,
  }) {
    double buyThreshold;
    double sellThreshold;
    if (SimulationCondition.instance.useTrend) {
      buyThreshold =
          trendData?['buy_threshold'] ??
          SimulationCondition.instance.kimchiBuyThreshold;
      sellThreshold =
          trendData?['sell_threshold'] ??
          SimulationCondition.instance.kimchiSellThreshold;
    } else {
      buyThreshold = SimulationCondition.instance.kimchiBuyThreshold;
      sellThreshold = SimulationCondition.instance.kimchiSellThreshold;
    }

    return (buyThreshold, sellThreshold);
  }

  // 김치 시뮬레이션 결과 계산
  static List<SimulationResult> gimchiSimulateResults(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap, {
    bool useTrend = true,
  }) {
    List<SimulationResult> simResults = [];
    double initialKRW = 1000000;
    double totalKRW = initialKRW;
    SimulationResult? unselledResult;

    DateTime? sellDate;
    DateTime? buyDate;
    double? buyPrice;
    double? sellPrice;

    // 날짜 오름차순 정렬
    final sortedDates = usdtMap.keys.toList()..sort();

    // 날짜 오름차순 정렬
    strategyList.sort((a, b) {
      final dateA = a['analysis_date'];
      final dateB = b['analysis_date'];
      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    if (SimulationCondition.instance.matchSameDatesAsAI) {
      final strategyFirstDate = DateTime.parse(
        strategyList.first['analysis_date'],
      );
      sortedDates.removeWhere((date) => date.compareTo(strategyFirstDate) < 0);
    }

    final usdExchangeRatesMap = {
      for (var rate in usdExchangeRates) rate.time: rate.value,
    };

    Map<DateTime, Map<String, double>>? premiumTrends;
    if (SimulationCondition.instance.useTrend) {
      premiumTrends = SimulationModel.generatePremiumTrends(
        usdExchangeRates,
        usdtMap,
      );
    }

    for (final date in sortedDates) {
      final usdtDay = usdtMap[date];
      final usdExchangeRate = usdExchangeRatesMap[date] ?? 0.0;
      final usdtLow = usdtDay?.low ?? 0.0;
      final usdtHigh = usdtDay?.high ?? 0.0;

      double buyTargetPrice = 0.0;
      double sellTargetPrice = 0.0;

      final (buyThreshold, sellThreshold) = getKimchiThresholds(
        trendData: premiumTrends?[date],
      );

      buyTargetPrice = usdExchangeRate * (1 + buyThreshold / 100);
      sellTargetPrice = usdExchangeRate * (1 + sellThreshold / 100);

      // 매수 조건: 프리미엄 buyThreshold% 미만, 아직 매수 안한 상태
      if (buyPrice == null) {
        // 매도 대기 상태가 아니어야 매수
        if (sellPrice == null) {
          if (buyTargetPrice >= usdtLow) {
            // 100원에 매수 하려고 했는데 고가가 90원이라면 그냥 90원에 매수 하겠지
            buyPrice = min(buyTargetPrice, usdtHigh);
            buyDate = date;

            print(
              'Buy condition met: buyDate=$buyDate, buyPrice=$buyPrice, buyTargetPrice=$buyTargetPrice, usdtLow=$usdtLow',
            );
          }
        }
      }

      if (buyPrice == null) continue;

      bool canSell = _isSellCondition(usdtMap, date, buyDate);

      // 매도 조건: 프리미엄 sellThreshold% 초과, 이미 매수한 상태
      if (canSell && sellTargetPrice <= usdtHigh) {
        sellDate = date;
        // 매도 가격이 100원인데 저가가 110원 이면 그냥 110원에 매도 그래서 둘중 높은값
        sellPrice = max(sellTargetPrice, usdtLow);
        print(
          'Sell condition met: sellDate=$sellDate, buyDate=$buyDate, buyPrice=$buyPrice, sellPrice=$sellPrice',
        );

        // 수익 계산
        final usdtAmount = totalKRW / buyPrice;
        final finalKRW = usdtAmount * sellPrice;
        final profit = finalKRW - totalKRW;
        final profitRate = profit / totalKRW * 100;

        simResults.add(
          SimulationResult(
            analysisDate: date,
            buyDate: buyDate,
            buyPrice: buyPrice,
            sellDate: sellDate,
            sellPrice: sellPrice,
            profit: profit,
            profitRate: profitRate,
            finalKRW: finalKRW,
            finalUSDT: null,
            usdExchangeRateAtBuy: usdExchangeRatesMap[buyDate],
            usdExchangeRateAtSell: usdExchangeRatesMap[sellDate],
          ),
        );

        // 다음 거래를 위해 초기화 (복리)
        totalKRW = finalKRW;
        buyDate = null;
        buyPrice = null;
        sellPrice = null;
        unselledResult = null;
      } else {
        final usdtPrice = usdtMap[date]?.close;
        final usdtCount = totalKRW / buyPrice;
        final finalKRW = usdtCount * (usdtPrice ?? 0);

        unselledResult = SimulationResult(
          analysisDate: date,
          buyDate: buyDate,
          buyPrice: buyPrice,
          sellDate: null,
          sellPrice: null,
          profit: 0,
          profitRate: 0,
          finalKRW: finalKRW,
          finalUSDT: usdtCount,
          usdExchangeRateAtBuy: usdExchangeRatesMap[buyDate],
          usdExchangeRateAtSell: null,
        );
      }
    }

    if (unselledResult != null) {
      simResults.add(unselledResult);
    }

    return simResults;
  }

  static bool _isSellCondition(
    Map<dynamic, dynamic> usdtMap,
    DateTime date,
    DateTime? buyDate,
  ) {
    final open = usdtMap[date]?.open ?? 0;
    final close = usdtMap[date]?.close ?? 0;
    final canSell = (buyDate == date) ? (open < close) : true;

    return canSell;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // 시뮬레이션 결과를 기반으로 수익률 데이터를 계산하는 내부 함수
  static SimulationYieldData _calculateYieldData(
    List<SimulationResult> results,
  ) {
    if (results.isEmpty) {
      return SimulationYieldData(
        totalReturn: 0.0,
        tradingDays: 0,
        annualYield: 0.0,
      );
    }

    final firstDate = results.first.buyDate;
    final lastDate = results.last.analysisDate;

    if (firstDate == null || lastDate == null) {
      return SimulationYieldData(
        totalReturn: 0.0,
        tradingDays: 0,
        annualYield: 0.0,
      );
    }

    final days = lastDate.difference(firstDate).inDays;
    final totalReturn =
        (results.last.finalKRW / 1000000 - 1) * 100; // 총 수익률 (%)
    final annualYield = _calculateAnnualYield(results);

    return SimulationYieldData(
      totalReturn: totalReturn,
      tradingDays: days,
      annualYield: annualYield,
    );
  }

  // results를 입력으로 받아 annualYield를 리턴하는 static 함수
  static double _calculateAnnualYield(List<SimulationResult> results) {
    if (results.isEmpty) return 0.0;

    final firstDate = results.first.buyDate;
    final lastDate = results.last.analysisDate;
    if (firstDate == null || lastDate == null) return 0.0;

    final days = lastDate.difference(firstDate).inDays;
    if (days < 1) return 0.0;

    final years = days / 365.0;
    final totalReturn = results.last.finalKRW / 1000000;
    final annualYield =
        (years > 0) ? (pow(totalReturn, 1 / years) - 1) * 100 : 0.0;

    return (annualYield.isNaN || annualYield.isInfinite ? 0.0 : annualYield)
        .toDouble();
  }

  static SimulationYieldData getYieldForAISimulation(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    final results = SimulationModel.simulateResults(
      usdExchangeRates,
      strategyList,
      usdtMap,
    );
    return _calculateYieldData(results);
  }

  // 김치 시뮬레이션 수익률 계산
  static SimulationYieldData? getYieldForGimchiSimulation(
    List<ChartData> usdExchangeRates,
    List<StrategyMap> strategyList,
    Map<DateTime, USDTChartData> usdtMap,
  ) {
    final simResults = gimchiSimulateResults(
      usdExchangeRates,
      strategyList,
      usdtMap,
    );

    return _calculateYieldData(simResults);
  }
}
