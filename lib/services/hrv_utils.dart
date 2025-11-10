/// HRV natijalarini tasniflab berish
class HRVInterpretation {
  static String getHeartRateStatus(int bpm) {
    if (bpm < 60) return 'Past - Istirahatlash rejimi yoki sportchi';
    if (bpm < 80) return 'Normal - Sog\'lom qalb urishi';
    if (bpm < 100) return 'Yuqori - Stresslangan yoki faol';
    return 'Juda yuqori - Taqdirota yoki xal';

  }

  static String getStressStatus(int stressIndex) {
    if (stressIndex <= 2) return 'Juda Past - Maksimal relaksatsiya';
    if (stressIndex <= 4) return 'Past - Yaxshi recovery';
    if (stressIndex <= 6) return 'O\'rtacha - Balansli holat';
    if (stressIndex <= 8) return 'Yuqori - Stress darajasi ko\'paygan';
    return 'Juda Yuqori - Darhol istirahat qiling';
  }

  static String getRecoveryStatus(int recovery) {
    if (recovery >= 8) return 'Juda Yuqori - O\'zini toza sezmoqdasiz';
    if (recovery >= 6) return 'Yuqori - Yaxshi qayta tiklaning';
    if (recovery >= 4) return 'O\'rtacha - Saltqinch istirahatingiz kerak';
    if (recovery >= 2) return 'Past - Kuchli stress holatida';
    return 'Juda Past - Zaifs yoki kaslang';
  }

  static String getSDNNStatus(double sdnn) {
    if (sdnn < 20) return 'Yomon - Juda past variability';
    if (sdnn < 50) return 'Past - Reduced parasympathetic tone';
    if (sdnn < 100) return 'Normal - Healthy variability';
    if (sdnn < 150) return 'Yaxshi - High variability va adaptability';
    return 'Juda Yaxshi - Maksimal cardiovascular fitness';
  }

  static String getRMSSDStatus(double rmssd) {
    if (rmssd < 20) return 'Past - Stresslangan autonomic tone';
    if (rmssd < 50) return 'O\'rtacha - Balansli';
    return 'Yaxshi - High parasympathetic activation';
  }

  static String getLFHFStatus(double lfhf) {
    if (lfhf < 1.0) return 'Yuqori Parasympathetic - Relaksatsiya';
    if (lfhf < 2.5) return 'Balansli - Normal autonomic balance';
    if (lfhf < 4.0) return 'Yuqori Sympathetic - Stress yoki faollik';
    return 'Juda Yuqori Sympathetic - Juda stresslangan';
  }
}

/// HRV tavsiyalar
class HRVRecommendations {
  static String getRecommendation(int stressIndex, double rmssd) {
    if (stressIndex >= 7) {
      return '''
⚠️ YUQORI STRESS DARAJASI

Tavsiyalar:
• 10-15 minuta respiration exercises (4-7-8 breathing)
• Meditatsiya yoki yoga
• Juda 20 min gidish/yugurish
• Kafein va shukerdan sa'nab turish
• Yetarli uyqu (7-9 soat)
• Tarkibiga gul qaytarish üncü
      ''';
    } else if (stressIndex >= 5) {
      return '''
⚠️ O\'RTACHA STRESS - FAVAKALANG EHTIYOT

Tavsiyalar:
• Deep breathing (10 daqiqa)
• Choyxonaga chiqish yoki tashvisha
• Light exercise
• Stressli aktivlarni cheklash
      ''';
    } else {
      return '''
✅ YAXSHI HOLAT - RECOVERY OPTIMALI

Tavsiyalar:
• Shu holatingizni saqlang
• Kundalik o'lchashlarni davom ettiring
• Sog\'lom lifestyle'ni qo'llab-quvvatlang
      ''';
    }
  }

  static String getTrainingRecommendation(int heartRate, int stressIndex) {
    if (stressIndex > 7) {
      return 'REST DAY - Juda stresslangan, o\'qitish kerak emas';
    } else if (stressIndex > 5) {
      return 'EASY WORKOUT - Yengil treningi tavsiya qilamiz (50-60% Max HR)';
    } else if (stressIndex > 3) {
      return 'MODERATE WORKOUT - O\'rtacha intensivlik tavsiya qilamiz (60-70% Max HR)';
    } else {
      return 'HARD WORKOUT - Yuqori intensivlik tavsiya qilamiz (70-85% Max HR)';
    }
  }
}

/// HRV trendini tahlil qilish
class HRVTrendAnalyzer {
  static Map<String, dynamic> analyzeTrend(List<double> values) {
    if (values.isEmpty) return {'trend': 'N/A', 'change': 0};

    // Oxirgi 7 ta o'lchash (yoki boshqasi)
    final recentValues = values.length > 7 ? values.sublist(values.length - 7) : values;
    final olderValues = values.length > 14 ? values.sublist(values.length - 14, values.length - 7) : [];

    double recentAvg = recentValues.reduce((a, b) => a + b) / recentValues.length;
    double olderAvg = olderValues.isNotEmpty ? olderValues.reduce((a, b) => a + b) / olderValues.length : recentAvg;

    double percentChange = ((recentAvg - olderAvg) / olderAvg * 100);
    String trend = percentChange > 5 ? 'Yaxshilanmoqda ↑' : percentChange < -5 ? 'Buzilanmoqda ↓' : 'Barqaror →';

    return {
      'trend': trend,
      'change': percentChange.toStringAsFixed(1),
      'recentAvg': recentAvg.toStringAsFixed(2),
      'olderAvg': olderAvg.toStringAsFixed(2),
    };
  }

  static String getTrendMessage(Map<String, dynamic> trendData) {
    String trend = trendData['trend'];
    double change = double.parse(trendData['change']);

    if (change > 10) {
      return '$trend: Katta yaxshilasha! Davom ettiring 💪';
    } else if (change > 0) {
      return '$trend: Sekin yaxshilashmoqda, davom ettiring 👍';
    } else if (change < -10) {
      return '$trend: Buzilanmoqda, istirahat qiling 😴';
    } else if (change < 0) {
      return '$trend: Sekin buzilanmoqda, ehtiyot bolin ⚠️';
    } else {
      return '$trend: Barqaror holat 👍';
    }
  }
}

/// HRV target o'rnatish
class HRVTargets {
  // Yosh bo'yicha HRV target qiymatlar
  static Map<String, dynamic> getTargetsByAge(int age) {
    if (age < 20) {
      return {
        'sdnn': {'min': 120, 'max': 200},
        'rmssd': {'min': 80, 'max': 150},
        'heartRate': {'min': 60, 'max': 90},
        'stressIndex': {'min': 1, 'max': 4},
      };
    } else if (age < 30) {
      return {
        'sdnn': {'min': 100, 'max': 180},
        'rmssd': {'min': 60, 'max': 130},
        'heartRate': {'min': 60, 'max': 100},
        'stressIndex': {'min': 2, 'max': 5},
      };
    } else if (age < 40) {
      return {
        'sdnn': {'min': 80, 'max': 150},
        'rmssd': {'min': 40, 'max': 100},
        'heartRate': {'min': 60, 'max': 100},
        'stressIndex': {'min': 2, 'max': 6},
      };
    } else if (age < 50) {
      return {
        'sdnn': {'min': 70, 'max': 130},
        'rmssd': {'min': 30, 'max': 80},
        'heartRate': {'min': 65, 'max': 105},
        'stressIndex': {'min': 3, 'max': 7},
      };
    } else {
      return {
        'sdnn': {'min': 50, 'max': 100},
        'rmssd': {'min': 20, 'max': 60},
        'heartRate': {'min': 70, 'max': 110},
        'stressIndex': {'min': 3, 'max': 8},
      };
    }
  }

  static bool isValueInTarget(String metric, double value, int age) {
    final targets = getTargetsByAge(age);
    if (!targets.containsKey(metric)) return true;

    final target = targets[metric];
    return value >= target['min'] && value <= target['max'];
  }
}

/// Time-based analisis
class TimeBasedAnalysis {
  static String getTimeOfDayMessage(DateTime time) {
    final hour = time.hour;

    if (hour >= 6 && hour < 9) {
      return '🌅 Ertalab - Stress ko\'payishiga tayyor bo\'ling';
    } else if (hour >= 9 && hour < 12) {
      return '☀️ Ertalab o\'rta - Pik produktivlik vaqti';
    } else if (hour >= 12 && hour < 14) {
      return '🍽️ Tushlik - Oilish payti, energiya kam bo\'ladi';
    } else if (hour >= 14 && hour < 17) {
      return '💪 Tushlik oxiri - Energiya qayta ko\'payga';
    } else if (hour >= 17 && hour < 21) {
      return '🌆 Kechqurun - Stress/energiya ko\'payishiga qidir';
    } else {
      return '😴 Kecha - Relaksatsiya vaqti, uyqu uchun tayyorlanish';
    }
  }

  static String getDayOfWeekMessage(DateTime date) {
    const days = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
    final dayName = days[date.weekday - 1];

    if (date.weekday == 5) {
      return '🎉 $dayName - Weekend boshlanmoqda, relaksatsiya vaqti';
    } else if (date.weekday >= 6) {
      return '🌟 $dayName - Weekend, stress past bo\'lishi kerak';
    } else if (date.weekday == 1) {
      return '📅 $dayName - Hafta boshlanmoqda, stress ko\'payishi mumkin';
    }
    return '📅 $dayName - O\'rtacha stressli kun';
  }
}

/// Export/Share utilities
class HRVExportUtils {
  static String generateReport(Map<String, dynamic> measurement) {
    return '''
╔════════════════════════════════════════╗
║        HRV O'LCHASH NATIJALARI          ║
╚════════════════════════════════════════╝

📅 Vaqti: ${measurement['timestamp']}

❤️  QO'LB URISHI: ${measurement['heartRate']} BPM

HRV METRIKALARI:
  • SDNN: ${measurement['sdnn']} ms (Variability)
  • RMSSD: ${measurement['rmssd']} ms (Parasympathetic)
  • pNN50: ${measurement['pnn50']}% (Vagal tone)
  • LF/HF: ${measurement['lfHfRatio']} (Balance)

STRESS VA RECOVERY:
  • Stress Index: ${measurement['stressIndex']}/10
  • Recovery Potential: ${measurement['recoveryPotential']}/10

═════════════════════════════════════════
''';
  }

  static String generateWeeklyReport(List<Map<String, dynamic>> measurements) {
    String report = '''
╔════════════════════════════════════════╗
║    HAFTALIK HRV SUMMARY REPORT          ║
╚════════════════════════════════════════╝

📊 Jami O'lchashlar: ${measurements.length}

''';

    if (measurements.isNotEmpty) {
      double avgHeartRate = measurements.fold<double>(0, (sum, m) => sum + double.parse(m['heartRate'].toString())) / measurements.length;
      double avgStress = measurements.fold<double>(0, (sum, m) => sum + double.parse(m['stressIndex'].toString())) / measurements.length;

      report += '''
O'RTACHA QIYMATLAR:
  • Qalb Urishi: ${avgHeartRate.toStringAsFixed(1)} BPM
  • Stress Index: ${avgStress.toStringAsFixed(1)}/10

TRENDLAR: Tahlil qilinmoqda...
      ''';
    }

    return report;
  }
}
