import 'package:camera/camera.dart';

class CameraSignalProcessor {
  /// Camera frame dan barmoq qonining o'zgarishini hisoblash
  /// Photoplethysmography (PPG) usulida
  static double processFrame(CameraImage image) {
    try {
      // Agar available bo'lsa NV21 (Android) yoki BGRA32 (iOS) formatida olamiz
      if (image.format.group == ImageFormatGroup.nv21) {
        return _processNV21Frame(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _processBGRA8888Frame(image);
      } else if (image.format.group == ImageFormatGroup.yuv420) {
        return _processYUV420Frame(image);
      }
      
      return 0.5;
    } catch (e) {
      print('Frame processing error: $e');
      return 0.5;
    }
  }

  /// NV21 format processing (Android)
  static double _processNV21Frame(CameraImage image) {
    final y = image.planes[0].bytes;
    
    // Markaziy region (barmoq qo'yilgan joy) dan yaxlitlik hisoblash
    final width = image.width;
    final height = image.height;
    
    // Center region - 50x50 pixel
    final startX = (width / 2 - 25).toInt();
    final startY = (height / 2 - 25).toInt();
    
    int sum = 0;
    int count = 0;
    
    for (int py = startY; py < startY + 50 && py < height; py++) {
      for (int px = startX; px < startX + 50 && px < width; px++) {
        sum += y[py * width + px];
        count++;
      }
    }
    
    if (count == 0) return 0.5;
    
    // Brightness ni normalize qilish (0.0 - 1.0)
    double brightness = sum / (count * 255);
    return brightness.clamp(0.0, 1.0);
  }

  /// BGRA8888 format processing (iOS)
  static double _processBGRA8888Frame(CameraImage image) {
    final bgra = image.planes[0].bytes;
    
    final width = image.width;
    final height = image.height;
    
    final startX = (width / 2 - 25).toInt();
    final startY = (height / 2 - 25).toInt();
    
    int sum = 0;
    int count = 0;
    
    // BGRA formatida - har 4 byte = 1 pixel (B, G, R, A)
    for (int py = startY; py < startY + 50 && py < height; py++) {
      for (int px = startX; px < startX + 50 && px < width; px++) {
        int pixelIndex = (py * width + px) * 4;
        
        if (pixelIndex + 2 < bgra.length) {
          // Red channel - PPG uchun eng yaxshi
          int red = bgra[pixelIndex + 2];
          sum += red;
          count++;
        }
      }
    }
    
    if (count == 0) return 0.5;
    
    double brightness = sum / (count * 255);
    return brightness.clamp(0.0, 1.0);
  }

  /// YUV420 format processing (Universal)
  static double _processYUV420Frame(CameraImage image) {
    final yPlane = image.planes[0].bytes;
    
    final width = image.width;
    final height = image.height;
    final bytesPerRow = image.planes[0].bytesPerRow;
    
    final startX = (width / 2 - 25).toInt();
    final startY = (height / 2 - 25).toInt();
    
    int sum = 0;
    int count = 0;
    
    for (int py = startY; py < startY + 50 && py < height; py++) {
      for (int px = startX; px < startX + 50 && px < width; px++) {
        int index = py * bytesPerRow + px;
        
        if (index < yPlane.length) {
          sum += yPlane[index];
          count++;
        }
      }
    }
    
    if (count == 0) return 0.5;
    
    double brightness = sum / (count * 255);
    return brightness.clamp(0.0, 1.0);
  }

  /// Signalning o'rtacha qiymatini hisoblash
  static double calculateMeanBrightness(List<double> signals) {
    if (signals.isEmpty) return 0.5;
    return signals.reduce((a, b) => a + b) / signals.length;
  }

  /// Signalning standart chetlanishini hisoblash
  static double calculateStdDeviation(List<double> signals) {
    if (signals.length < 2) return 0;
    
    double mean = calculateMeanBrightness(signals);
    double variance = signals.fold<double>(0, (sum, val) {
      return sum + ((val - mean) * (val - mean));
    }) / signals.length;
    
    return (variance * variance).abs().toStringAsFixed(4) as double;
  }

  /// Signal quality ni baholash (0-100%)
  static int assessSignalQuality(List<double> signals) {
    if (signals.length < 50) return 0;
    
    double mean = calculateMeanBrightness(signals);
    double std = calculateStdDeviation(signals);
    
    // Ideal brightness: 0.3 - 0.7 orasida
    int brightnessScore = 0;
    if (mean >= 0.3 && mean <= 0.7) {
      brightnessScore = 100;
    } else if (mean >= 0.2 && mean <= 0.8) {
      brightnessScore = 80;
    } else if (mean >= 0.1 && mean <= 0.9) {
      brightnessScore = 60;
    } else {
      brightnessScore = 40;
    }
    
    // Variability score: std dev 0.1 - 0.3 orasida yaxshi
    int variabilityScore = 0;
    if (std >= 0.1 && std <= 0.3) {
      variabilityScore = 100;
    } else if (std >= 0.05 && std <= 0.4) {
      variabilityScore = 80;
    } else if (std >= 0.02 && std <= 0.5) {
      variabilityScore = 60;
    } else {
      variabilityScore = 40;
    }
    
    // Average quality
    return ((brightnessScore + variabilityScore) ~/ 2).clamp(0, 100);
  }

  /// LED flashni yonish tavsiyasi
  static String getFlashRecommendation(int qualityScore, double meanBrightness) {
    if (qualityScore > 75) {
      return 'Signal sifati yaxshi ✓';
    } else if (meanBrightness < 0.3) {
      return 'Juda qorong\'i: Flashni yoqing yoki barmoqni quyoshga ko\'taring';
    } else if (meanBrightness > 0.8) {
      return 'Juda yorug\': Barmoqni oz o\'tkazing yoki flashni o\'chirib ko\'ring';
    } else {
      return 'Signal sifatini yaxshilash uchun barmoqni qayta qo\'ying';
    }
  }
}
