import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // ===========================================================================
  // PRODUCTION AD UNIT IDs
  // Replace these test IDs with your real AdMob Ad Unit IDs before uploading
  // your app to the Play Store / App Store!
  // ===========================================================================
  static const String _prodAndroidBannerId = 'ca-app-pub-9864215119305409/3791094823';
  static const String _prodIosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  
  static const String _prodAndroidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';
  static const String _prodIosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ';

  // ===========================================================================
  // TEST AD UNIT IDs (Google Provided Official Test IDs)
  // Always use test IDs during development to avoid policy violations.
  // ===========================================================================
  static const String _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  static const String _testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  /// Get Banner Ad Unit ID based on platform & environment
  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) return _testAndroidBannerId;
      if (Platform.isIOS) return _testIosBannerId;
    }
    
    // In Release mode:
    if (Platform.isAndroid) {
      return _prodAndroidBannerId.contains('XXXXX') ? _testAndroidBannerId : _prodAndroidBannerId;
    } else if (Platform.isIOS) {
      return _prodIosBannerId.contains('XXXXX') ? _testIosBannerId : _prodIosBannerId;
    }
    throw UnsupportedError('Unsupported platform for Mobile Ads');
  }

  /// Get Interstitial Ad Unit ID based on platform & environment
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) return _testAndroidInterstitialId;
      if (Platform.isIOS) return _testIosInterstitialId;
    }

    // In Release mode:
    if (Platform.isAndroid) {
      return _prodAndroidInterstitialId.contains('XXXXX') ? _testAndroidInterstitialId : _prodAndroidInterstitialId;
    } else if (Platform.isIOS) {
      return _prodIosInterstitialId.contains('XXXXX') ? _testIosInterstitialId : _prodIosInterstitialId;
    }
    throw UnsupportedError('Unsupported platform for Mobile Ads');
  }

  /// Utility method to load and show an Interstitial Ad easily
  static void loadAndShowInterstitialAd({
    Function()? onAdDismissed,
    Function(LoadAdError error)? onAdFailedToLoad,
  }) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              if (onAdDismissed != null) onAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              if (onAdDismissed != null) onAdDismissed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          if (onAdFailedToLoad != null) {
            onAdFailedToLoad(error);
          } else if (onAdDismissed != null) {
            onAdDismissed();
          }
        },
      ),
    );
  }
}
