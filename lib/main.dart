import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleCameraApp());
}

class SimpleCameraApp extends StatelessWidget {
  const SimpleCameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kamera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  String _message = 'Kamera yuklanmoqda...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Kamera ruxsati so'rash
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _message = 'Kamera ruxsati rad etildi';
      });
      return;
    }

    try {
      // Kameralarni olish
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _message = 'Kamera topilmadi';
        });
        return;
      }

      // Orqa kamerani tanlash
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Kamera kontrollerini yaratish
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Xato: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isInitialized && _controller != null
            ? CameraPreview(_controller!)
            : Text(
                _message,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
