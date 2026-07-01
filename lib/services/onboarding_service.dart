import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış onboarding (Nasıl çalışır?) — güncelleme sonrası bir kez gösterilir.
class OnboardingService {
  OnboardingService._();

  static const _howItWorksSeenKey = 'how_it_works_onboarding_seen_v1';

  static Future<bool> shouldShowHowItWorks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_howItWorksSeenKey) != true;
  }

  static Future<void> markHowItWorksSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_howItWorksSeenKey, true);
  }
}
