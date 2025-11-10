import 'dart:math';

class HRVCalculator {
  // Signal processing uchun konstanta
  static const int BUFFER_SIZE = 256;
  static const double CAMERA_FPS = 30.0; // Kamera frame rate
  static const double FILTER_CUTOFF_LOW = 0.4; // Hz - past chastota (noise)
  static const double FILTER_CUTOFF_HIGH = 4.0; // Hz - yuqori chastota
  
  late List<double> _signalBuffer;
  late List<double> _filteredBuffer;
  late List<double> _nnIntervals; // RR intervals (milliseconds)

  HRVCalculator() {
    _signalBuffer = [];
    _filteredBuffer = [];
    _nnIntervals = [];
  }

  /// Raw signal qiymatini qo'sh (0.0 - 1.0 orasida)
  void addRawSignalValue(double value) {
    if (value < 0.0 || value > 1.0) return;
    
    _signalBuffer.add(value);

    // Buffer to'la bo'lganda signal processing qil
    if (_signalBuffer.length >= BUFFER_SIZE) {
      _processSignalBuffer();
      _signalBuffer.removeAt(0);
    }
  }

  /// Signal filterini o'tkazish (bandpass filter)
  List<double> _applyBandpassFilter(List<double> signal) {
    List<double> filtered = List.from(signal);
    
    // Simple moving average filter - noise ni chiqarish
    final windowSize = 5;
    for (int i = windowSize; i < filtered.length - windowSize; i++) {
      double sum = 0;
      for (int j = -windowSize; j <= windowSize; j++) {
        sum += filtered[i + j];
      }
      filtered[i] = sum / (windowSize * 2 + 1);
    }
    
    return filtered;
  }

  /// Qalb urushni topish (peak detection)
  List<int> _detectPeaks(List<double> signal) {
    List<int> peaks = [];
    
    // Adaptive threshold - signalning o'rtasidagi farqni topish
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double std = sqrt(signal.fold<double>(0, (sum, val) => sum + pow(val - mean, 2)) / signal.length);
    double threshold = mean + (std * 0.5);

    for (int i = 1; i < signal.length - 1; i++) {
      // Local maximum topish
      if (signal[i] > threshold && 
          signal[i] > signal[i - 1] && 
          signal[i] > signal[i + 1]) {
        peaks.add(i);
      }
    }

    // Juda yaqin peakslarni filter qilish (< 300ms)
    final minDistance = (CAMERA_FPS * 0.3).toInt();
    List<int> filteredPeaks = [];
    
    for (int peak in peaks) {
      if (filteredPeaks.isEmpty || (peak - filteredPeaks.last) >= minDistance) {
        filteredPeaks.add(peak);
      }
    }

    return filteredPeaks;
  }

  /// RR intervals (beat-to-beat intervals) ni hisoblash
  void _calculateRRIntervals(List<int> peaks) {
    if (peaks.length < 2) return;

    // Peaks orasidagi vaqtni hisoblash (milliseconds)
    for (int i = 1; i < peaks.length; i++) {
      int intervalFrames = peaks[i] - peaks[i - 1];
      double intervalMs = (intervalFrames / CAMERA_FPS) * 1000;
      
      // Anomaliyani filter qilish (300-2000ms oralig'i normal)
      if (intervalMs >= 300 && intervalMs <= 2000) {
        _nnIntervals.add(intervalMs);
      }
    }

    // Buffer kattaligini cheklash
    if (_nnIntervals.length > 100) {
      _nnIntervals.removeAt(0);
    }
  }

  /// Signal buffer ni qayta ishlash
  void _processSignalBuffer() {
    if (_signalBuffer.length < BUFFER_SIZE) return;

    // 1. Filter qilish
    _filteredBuffer = _applyBandpassFilter(_signalBuffer);

    // 2. Peaksni topish
    List<int> peaks = _detectPeaks(_filteredBuffer);

    // 3. RR intervals hisoblash
    _calculateRRIntervals(peaks);
  }

  /// Qalb urishi (BPM) ni hisoblash
  int getHeartRate() {
    if (_nnIntervals.isEmpty) return 0;
    
    double meanRR = _nnIntervals.reduce((a, b) => a + b) / _nnIntervals.length;
    int bpm = (60000 / meanRR).toInt();
    
    return bpm.clamp(40, 200);
  }

  /// SDNN (Standard Deviation of NN intervals) - HRV eng asosiy ko'rsatkichi
  double getSDNN() {
    if (_nnIntervals.length < 2) return 0;
    
    double mean = _nnIntervals.reduce((a, b) => a + b) / _nnIntervals.length;
    double variance = _nnIntervals.fold<double>(0, (sum, val) => sum + pow(val - mean, 2)) / _nnIntervals.length;
    
    return sqrt(variance);
  }

  /// RMSSD (Root Mean Square of Successive Differences) - Parasympathetic activity
  double getRMSSD() {
    if (_nnIntervals.length < 2) return 0;
    
    double sumSquares = 0;
    for (int i = 1; i < _nnIntervals.length; i++) {
      double diff = _nnIntervals[i] - _nnIntervals[i - 1];
      sumSquares += pow(diff, 2);
    }
    
    return sqrt(sumSquares / (_nnIntervals.length - 1));
  }

  /// pNN50 (Percentage of successive NN intervals differing more than 50ms)
  double getPNN50() {
    if (_nnIntervals.length < 2) return 0;
    
    int count = 0;
    for (int i = 1; i < _nnIntervals.length; i++) {
      if ((_nnIntervals[i] - _nnIntervals[i - 1]).abs() > 50) {
        count++;
      }
    }
    
    return (count / (_nnIntervals.length - 1)) * 100;
  }

  /// Frequency domain analysis (LF/HF ratio)
  Map<String, double> getFrequencyDomainAnalysis() {
    if (_nnIntervals.length < 128) {
      return {'lf': 0, 'hf': 0, 'lfHfRatio': 0};
    }

    // FFT yordamida frequency spectrum hisoblash
    List<double> interpolatedSignal = _interpolateSignal(_nnIntervals, 4.0);
    
    // Simple FFT implementation
    List<Complex> fftResult = _fft(
      interpolatedSignal.map((v) => Complex(v, 0)).toList()
    );

    // Frequency bands
    double lf = _calculatePowerInBand(fftResult, 0.04, 0.15, 4.0); // Low frequency
    double hf = _calculatePowerInBand(fftResult, 0.15, 0.4, 4.0);  // High frequency
    double lfHfRatio = hf > 0 ? lf / hf : 0;

    return {
      'lf': lf,
      'hf': hf,
      'lfHfRatio': lfHfRatio,
    };
  }

  /// Simple FFT implementation using Cooley-Tukey algorithm
  List<Complex> _fft(List<Complex> input) {
    int n = input.length;
    
    // Base case
    if (n <= 1) {
      return input;
    }
    
    // Ensure n is a power of 2 by zero-padding if necessary (only at top level)
    if ((n & (n - 1)) != 0) {
      // Not a power of 2, need to pad
      int nextPowerOf2 = _nextPowerOf2(n);
      List<Complex> padded = List.from(input);
      while (padded.length < nextPowerOf2) {
        padded.add(Complex(0, 0));
      }
      return _fftPowerOf2(padded);
    }
    
    return _fftPowerOf2(input);
  }

  /// FFT for input that is guaranteed to be a power of 2
  List<Complex> _fftPowerOf2(List<Complex> input) {
    int n = input.length;
    
    // Base case
    if (n <= 1) {
      return input;
    }
    
    // Divide into even and odd indices
    List<Complex> even = [];
    List<Complex> odd = [];
    for (int i = 0; i < n; i += 2) {
      even.add(input[i]);
      odd.add(input[i + 1]);
    }
    
    // Conquer
    List<Complex> evenFFT = _fftPowerOf2(even);
    List<Complex> oddFFT = _fftPowerOf2(odd);
    
    // Combine
    List<Complex> result = List.generate(n, (i) => Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      double angle = -2 * pi * k / n;
      Complex t = Complex(cos(angle), sin(angle)) * oddFFT[k];
      result[k] = evenFFT[k] + t;
      result[k + n ~/ 2] = evenFFT[k] - t;
    }
    
    return result;
  }

  /// Find next power of 2
  int _nextPowerOf2(int n) {
    if (n <= 1) return 1;
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  /// Signal ni interpolate qilish
  List<double> _interpolateSignal(List<double> signal, double targetFreq) {
    if (signal.isEmpty) return [];
    
    List<double> interpolated = [];
    double meanInterval = signal.reduce((a, b) => a + b) / signal.length;
    int interpolationFactor = (meanInterval * targetFreq / 1000).toInt().clamp(1, 10);

    for (int i = 0; i < signal.length - 1; i++) {
      interpolated.add(signal[i]);
      for (int j = 1; j < interpolationFactor; j++) {
        double fraction = j / interpolationFactor;
        interpolated.add(signal[i] * (1 - fraction) + signal[i + 1] * fraction);
      }
    }
    interpolated.add(signal.last);

    return interpolated;
  }

  /// Frequency bandida power hisoblash
  double _calculatePowerInBand(List<Complex> fft, double lowHz, double highHz, double samplingRate) {
    int lowBin = (lowHz * fft.length / samplingRate).toInt();
    int highBin = (highHz * fft.length / samplingRate).toInt();

    double power = 0;
    for (int i = lowBin; i <= highBin && i < fft.length; i++) {
      power += fft[i].abs();
    }

    return power / (highBin - lowBin + 1);
  }

  /// HRV stress index (1-10 scale)
  int getStressIndex() {
    double rmssd = getRMSSD();
    double sdnn = getSDNN();
    
    if (rmssd == 0 || sdnn == 0) return 5;
    
    // Stress index = 1 - (RMSSD / SDNN)
    double stressRatio = 1 - (rmssd / sdnn);
    int stressIndex = (stressRatio * 10).toInt().clamp(1, 10);
    
    return stressIndex;
  }

  /// Recovery potential (1-10 scale)
  int getRecoveryPotential() {
    return 11 - getStressIndex();
  }

  /// Buffer status
  int getBufferFillPercentage() {
    return ((_nnIntervals.length / 50) * 100).toInt().clamp(0, 100);
  }

  /// Data ready status
  bool isDataReady() {
    return _nnIntervals.length >= 30; // Minimal 30 beats kerak
  }

  /// Buffer ni tozalash
  void clearBuffer() {
    _signalBuffer.clear();
    _filteredBuffer.clear();
    _nnIntervals.clear();
  }

  /// Natijalarni export qilish
  Map<String, dynamic> getFullReport() {
    Map<String, dynamic> frequencyAnalysis = getFrequencyDomainAnalysis();
    
    return {
      'timestamp': DateTime.now(),
      'heartRate': getHeartRate(),
      'sdnn': getSDNN().toStringAsFixed(2),
      'rmssd': getRMSSD().toStringAsFixed(2),
      'pnn50': getPNN50().toStringAsFixed(2),
      'lf': frequencyAnalysis['lf'],
      'hf': frequencyAnalysis['hf'],
      'lfHfRatio': frequencyAnalysis['lfHfRatio'],
      'stressIndex': getStressIndex(),
      'recoveryPotential': getRecoveryPotential(),
      'bufferFill': getBufferFillPercentage(),
      'nnIntervalsCount': _nnIntervals.length,
    };
  }
}

class Complex {
  final double real;
  final double imag;

  Complex(this.real, this.imag);

  double abs() => sqrt(real * real + imag * imag);

  Complex operator +(Complex other) {
    return Complex(real + other.real, imag + other.imag);
  }

  Complex operator -(Complex other) {
    return Complex(real - other.real, imag - other.imag);
  }

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }
}
