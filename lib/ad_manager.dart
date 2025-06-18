import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

typedef OnAdLoaded = void Function();
typedef OnAdFailed = void Function();
typedef OnAdClosed = void Function();

class AdManager {
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  final VoidCallback? onRewardedAdLoaded;
  final VoidCallback? onRewardedAdFailed;
  final VoidCallback? onRewardedAdClosed;
  final VoidCallback? onInterstitialAdLoaded;
  final VoidCallback? onInterstitialAdFailed;
  final VoidCallback? onInterstitialAdClosed;

  AdManager({
    this.onRewardedAdLoaded,
    this.onRewardedAdFailed,
    this.onRewardedAdClosed,
    this.onInterstitialAdLoaded,
    this.onInterstitialAdFailed,
    this.onInterstitialAdClosed,
  });

  RewardedAd? get rewardedAd => _rewardedAd;
  InterstitialAd? get interstitialAd => _interstitialAd;

  Future<void> loadRewardedAd(String adUnitId) async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          onRewardedAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          onRewardedAdFailed?.call();
        },
      ),
    );
  }

  Future<void> loadInterstitialAd(String adUnitId) async {
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          onInterstitialAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          onInterstitialAdFailed?.call();
        },
      ),
    );
  }

  void showRewardedAd({
    required BuildContext context,
    required VoidCallback onRewarded,
  }) {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) => debugPrint('보상형 광고가 표시됨'),
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          onRewardedAdClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          onRewardedAdFailed?.call();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onRewarded();
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  void showInterstitialAd({
    required BuildContext context,
    VoidCallback? onShown,
  }) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('전면 광고가 표시됨');
          onShown?.call();
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          onInterstitialAdClosed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          onInterstitialAdFailed?.call();
        },
      );
      _interstitialAd!.show();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}