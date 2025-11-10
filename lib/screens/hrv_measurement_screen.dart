import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hrv_calculator.dart';
import '../services/camera_signal_processor.dart';
import '../services/hrv_database.dart';
import 'dart:async';
import 'dart:math' as math;

class HRVMeasurementScreen extends StatefulWidget {
  @override
  _HRVMeasurementScreenState createState() => _HRVMeasurementScreenState();
}

class _HRVMeasurementScreenState extends State<HRVMeasurementScreen>
    with TickerProviderStateMixin {
  late CameraController _cameraController;
  late HRVCalculator _hrvCalculator;
  late AnimationController _heartbeatController;
  late AnimationController _pulseController;
  late Animation<double> _heartbeatAnimation;
  late Animation<double> _pulseAnimation;

  List<double> _signalValues = [];
  int _heartRate = 0;
  int _stressIndex = 5;
  int _qualityScore = 0;
  String _statusMessage = 'Tayyor. O\'lchashni boshlang';
  bool _isInitialized = false;
  bool _isMeasuring = false;
  bool _hasError = false;
  bool _permissionDenied = false;
  int _measurementDuration = 0;
  Timer? _measurementTimer;
  int _totalMeasurementTime = 30; // 30 soniya

  @override
  void initState() {
    super.initState();
    _hrvCalculator = HRVCalculator();

    // Yurak urishi animatsiyasi
    _heartbeatController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _heartbeatController,
        curve: Curves.easeInOut,
      ),
    );

    // Pulse wave animatsiyasi
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _hasError = false;
      _permissionDenied = false;
      _statusMessage = 'Kamerani tekshirib ko\'rayotgan...';
    });

    // Kamera ruxsati
    final PermissionStatus status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _hasError = true;
        _permissionDenied = true;
        _statusMessage = 'Kamera ruxsati rad etildi';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Kamera topilmadi';
        });
        return;
      }

      // Back camera ni tanlash
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        fps: 30,
      );

      await _cameraController.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Tayyor. O\'lchashni boshlang';
      });

      _startImageStream();
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = 'Xato: $e';
      });
    }
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) {
      if (!_isMeasuring) return;

      // Raw signal o'lchash
      final brightness = CameraSignalProcessor.processFrame(image);
      _signalValues.add(brightness);

      // HRV calculator ga signal qo'shish
      _hrvCalculator.addRawSignalValue(brightness);

      // Signal sifatini baholash
      _qualityScore = CameraSignalProcessor.assessSignalQuality(_signalValues);

      // Data ready bo'lganda natijalarni yangilash
      if (_hrvCalculator.isDataReady()) {
        setState(() {
          _heartRate = _hrvCalculator.getHeartRate();
          _stressIndex = _hrvCalculator.getStressIndex();
        });

        // Yurak urishi animatsiyasini trigger qilish
        if (_heartRate > 0) {
          _heartbeatController.forward().then((_) {
            _heartbeatController.reverse();
          });
        }
      }

      // Buffer tozalash (memory management)
      if (_signalValues.length > 512) {
        _signalValues.removeAt(0);
      }
    });
  }

  void _startMeasurement() {
    if (_isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _measurementDuration = 0;
      _signalValues.clear();
      _hrvCalculator.clearBuffer();
      _statusMessage = 'Barmoqni kameraga qo\'ying va flash yonganini tekshiring';
    });

    // Pulse animatsiyasini boshlash
    _pulseController.repeat();

    // Timer - 30 soniya
    _measurementTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _measurementDuration = timer.tick;
        if (_measurementDuration % 10 == 0 && _measurementDuration > 0) {
          _statusMessage =
              '${30 - _measurementDuration} soniya qoldi. Barmoqni qimirlatmang';
        }
      });

      // 30 soniya tugaganda
      if (_measurementDuration >= _totalMeasurementTime) {
        _stopMeasurement();
      }
    });
  }

  void _stopMeasurement() {
    _measurementTimer?.cancel();
    _pulseController.stop();

    if (!_hrvCalculator.isDataReady()) {
      setState(() {
        _statusMessage = 'Yetarli ma\'lumot yo\'q. Qayta urinib ko\'ring';
        _isMeasuring = false;
      });
      return;
    }

    // Natijalarni saqlash
    _showResultsDialog();

    setState(() {
      _isMeasuring = false;
      _measurementDuration = 0;
      _statusMessage = 'Tayyor. O\'lchashni boshlang';
    });
  }

  void _showResultsDialog() {
    final report = _hrvCalculator.getFullReport();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Container(
              margin: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(27),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'O\'lchash Yakunlandi',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Main Results Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultCard(
                          icon: Icons.favorite,
                          label: 'Yurak',
                          value: '${report['heartRate']}',
                          unit: 'BPM',
                          gradient: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildResultCard(
                          icon: Icons.psychology,
                          label: 'Stress',
                          value: '${report['stressIndex']}',
                          unit: '/10',
                          gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultCard(
                          icon: Icons.battery_charging_full,
                          label: 'Recovery',
                          value: '${report['recoveryPotential']}',
                          unit: '/10',
                          gradient: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildResultCard(
                          icon: Icons.timeline,
                          label: 'HRV',
                          value: '${report['sdnn']}',
                          unit: 'ms',
                          gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Advanced Metrics
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _MetricRow('RMSSD', '${report['rmssd']} ms'),
                        Divider(color: Colors.white.withOpacity(0.1)),
                        _MetricRow('pNN50', '${report['pnn50']}%'),
                        Divider(color: Colors.white.withOpacity(0.1)),
                        _MetricRow('LF/HF Ratio',
                            '${(report['lfHfRatio'] as double).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Yopish'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _saveToDatabase(report);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Saqlash'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 2),
              Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveToDatabase(Map<String, dynamic> report) async {
    final measurement = HRVMeasurement(
      timestamp: report['timestamp'],
      heartRate: report['heartRate'],
      sdnn: double.parse(report['sdnn']),
      rmssd: double.parse(report['rmssd']),
      pnn50: double.parse(report['pnn50']),
      lf: report['lf'],
      hf: report['hf'],
      lfHfRatio: report['lfHfRatio'],
      stressIndex: report['stressIndex'],
      recoveryPotential: report['recoveryPotential'],
    );

    await HRVDatabase().saveMeasurement(measurement);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('O\'lchash natijasi saqlandi'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Yurak Urishi'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
              Color(0xFF4C1D95),
              Color(0xFF6B21A8),
            ],
          ),
        ),
        child: SafeArea(
          child: _isInitialized
              ? _buildMainContent()
              : _buildLoadingOrError(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Message
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 48),

              // Heart Animation with Circular Progress
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse waves
                  if (_isMeasuring) ...[
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 250 + (_pulseAnimation.value * 100),
                          height: 250 + (_pulseAnimation.value * 100),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.pinkAccent
                                  .withOpacity(0.3 * (1 - _pulseAnimation.value)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Circular Progress
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: _isMeasuring
                          ? _measurementDuration / _totalMeasurementTime
                          : 0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFEC4899),
                      ),
                    ),
                  ),

                  // Heart Icon with Animation
                  AnimatedBuilder(
                    animation: _heartbeatAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _heartbeatAnimation.value,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFEC4899),
                                Color(0xFFF43F5E),
                                Color(0xFFEF4444),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFEC4899).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 90,
                          ),
                        ),
                      );
                    },
                  ),

                  // Heart Rate Display
                  if (_isMeasuring && _heartRate > 0)
                    Positioned(
                      bottom: 50,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_heartRate BPM',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 48),

              // Timer
              if (_isMeasuring)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '${_totalMeasurementTime - _measurementDuration} soniya',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 24),

              // Signal Quality
              if (_isMeasuring)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Signal sifati',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            '$_qualityScore%',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _qualityScore > 70
                                  ? Color(0xFF10B981)
                                  : _qualityScore > 40
                                      ? Color(0xFFF59E0B)
                                      : Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _qualityScore / 100,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _qualityScore > 70
                                ? Color(0xFF10B981)
                                : _qualityScore > 40
                                    ? Color(0xFFF59E0B)
                                    : Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Bottom Button
        Padding(
          padding: EdgeInsets.all(32),
          child: _isMeasuring
              ? ElevatedButton(
                  onPressed: _stopMeasurement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_outlined, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'To\'xtatish',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ElevatedButton(
                  onPressed: _startMeasurement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'O\'lchashni Boshlash',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoadingOrError() {
    if (_hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _permissionDenied
                      ? Icons.camera_alt_outlined
                      : Icons.error_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 32),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              if (_permissionDenied)
                Text(
                  'Dasturni ishlatish uchun kamera ruxsati kerak.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              SizedBox(height: 32),
              if (_permissionDenied)
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Sozlamalarni Ochish'),
                ),
              SizedBox(height: 12),
              OutlinedButton(
                onPressed: _initializeCamera,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('Qayta Urinish'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          SizedBox(height: 24),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _measurementTimer?.cancel();
    _heartbeatController.dispose();
    _pulseController.dispose();
    if (_isInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  _MetricRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
