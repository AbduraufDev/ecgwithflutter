import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hrv_calculator.dart';
import '../services/camera_signal_processor.dart';
import '../services/hrv_database.dart';
import 'dart:async';

class HRVMeasurementScreen extends StatefulWidget {
  @override
  _HRVMeasurementScreenState createState() => _HRVMeasurementScreenState();
}

class _HRVMeasurementScreenState extends State<HRVMeasurementScreen> {
  late CameraController _cameraController;
  late HRVCalculator _hrvCalculator;
  List<double> _signalValues = [];
  int _heartRate = 0;
  int _stressIndex = 5;
  int _qualityScore = 0;
  String _statusMessage = 'Kamerani tekshirib ko\'rayotgan...';
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
        _statusMessage = 'Barmoqni kameraga qo\'ying va flash yonib turganini tekshiring';
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
      _statusMessage = 'O\'lchash jarayoni boshlanmoqda... Barmoqni qo\'ying';
    });

    // Timer - 30 soniya
    _measurementTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _measurementDuration = timer.tick;
        if (_measurementDuration % 10 == 0) {
          _statusMessage = 'O\'lchash davom etmoqda... ${30 - _measurementDuration} soniya qoldi';
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
    });
  }

  void _showResultsDialog() {
    final report = _hrvCalculator.getFullReport();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('O\'lchash Natijalari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultItem('Qalb urishi', '${report['heartRate']} BPM', Colors.red),
                _ResultItem('Stress Index', '${report['stressIndex']}/10', Colors.orange),
                _ResultItem('Recovery', '${report['recoveryPotential']}/10', Colors.green),
                SizedBox(height: 16),
                Text('Batafsil HRV Metrikalari:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 8),
                _DetailItem('SDNN (variat)', '${report['sdnn']} ms'),
                _DetailItem('RMSSD (parasimpat)', '${report['rmssd']} ms'),
                _DetailItem('pNN50', '${report['pnn50']}%'),
                _DetailItem('LF/HF Ratio', '${(report['lfHfRatio'] as double).toStringAsFixed(2)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveToDatabase(report);
              },
              child: Text('Saqlash', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Yopish'),
            ),
          ],
        );
      },
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
        content: Text('O\'lchash natijasi saqlandi ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HRV O\'lchash'),
        backgroundColor: Color(0xFF2C3E50),
        elevation: 0,
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Kamera preview
                Container(
                  color: Colors.black,
                  child: CameraPreview(_cameraController),
                ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // Info panel
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 12),
                        // Signal quality bar
                        LinearProgressIndicator(
                          value: _qualityScore / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _qualityScore > 70 ? Colors.green : _qualityScore > 40 ? Colors.orange : Colors.red,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('Signal Sifati: $_qualityScore%', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                // Live HRV data
                if (_isMeasuring && _hrvCalculator.isDataReady())
                  Positioned(
                    top: 180,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('Qalb urishi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '$_heartRate BPM',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Stress: $_stressIndex/10',
                            style: TextStyle(fontSize: 14, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom timer va buttons
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_isMeasuring)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vaqt: ${_totalMeasurementTime - _measurementDuration}s',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  value: _measurementDuration / _totalMeasurementTime,
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isMeasuring
                                ? _stopMeasurement
                                : _startMeasurement,
                            icon: Icon(_isMeasuring ? Icons.stop : Icons.play_arrow),
                            label: Text(_isMeasuring ? 'Tugatish' : 'Boshlash'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMeasuring ? Colors.red : Colors.green,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/history'),
                            icon: Icon(Icons.history),
                            label: Text('Tarix'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: _hasError
                  ? _buildErrorWidget()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_statusMessage, textAlign: TextAlign.center),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _permissionDenied ? Icons.camera_alt_outlined : Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          SizedBox(height: 24),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          if (_permissionDenied) ...[
            Text(
              'Dasturni ishlatish uchun kamera ruxsati kerak.\nIltimos, sozlamalardan ruxsat bering.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await openAppSettings();
              },
              icon: Icon(Icons.settings),
              label: Text('Sozlamalarga o\'tish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _initializeCamera,
              icon: Icon(Icons.refresh),
              label: Text('Qayta urinish'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Iltimos, qayta urinib ko\'ring.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeCamera,
              icon: Icon(Icons.refresh),
              label: Text('Qayta urinish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _measurementTimer?.cancel();
    if (_isInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  _ResultItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
