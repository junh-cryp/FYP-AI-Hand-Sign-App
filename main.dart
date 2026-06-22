import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:permission_handler/permission_handler.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  _cameras = await availableCameras();
  runApp(const HandGestureApp());
}

class HandGestureApp extends StatelessWidget {
  const HandGestureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HandTrackerScreen(),
    );
  }
}

class HandTrackerScreen extends StatefulWidget {
  const HandTrackerScreen({super.key});

  @override
  State<HandTrackerScreen> createState() => _HandTrackerScreenState();
}

class _HandTrackerScreenState extends State<HandTrackerScreen> {
  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  bool _isDetecting = false;
  String _status = "Initializing...";
  List<dynamic> _currentLandmarks = [];

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    try {
      _plugin = await HandLandmarkerPlugin.create();

      // Using front camera
      _controller = CameraController(
        _cameras[1],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _status = "Ready - Show hand from BOTTOM");

      _controller!.startImageStream((CameraImage image) async {
        if (_isDetecting || _plugin == null) return;
        _isDetecting = true;

        try {
          // We keep sensorOrientation but handle the 90-degree swap in the math below
          final results = await _plugin!.detect(
            image,
            _controller!.description.sensorOrientation,
          );

          if (results != null && results.isNotEmpty) {
            setState(() {
              _currentLandmarks = results[0].landmarks;
              _status = analyzeHand(_currentLandmarks);
            });
          } else {
            setState(() {
              _currentLandmarks = [];
              _status = "Scanning... (Enter from Bottom)";
            });
          }
        } catch (e) {
          debugPrint("Detection Error: $e");
        } finally {
          _isDetecting = false;
        }
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  // --- THE VERTICAL CORRECTION ENGINE ---
  String analyzeHand(List<dynamic> points) {
    // --- THE VERTICAL FLIP LOGIC ---
    // Since your hand is coming from the bottom, we flip the comparison.
    // A finger is "UP" if the Tip-X is GREATER than the Joint-X in this swapped coordinate space.
    bool iUp = points[8].x > points[6].x;
    bool mUp = points[12].x > points[10].x;
    bool rUp = points[16].x > points[14].x;
    bool pUp = points[20].x > points[18].x;

    // Thumb check: We look at the distance between Point 4 (Tip) and Point 5 (Index Base)
    double thumbExt = (points[4].y - points[5].y).abs();
    bool tUp = thumbExt > 0.05;

    // --- SIGN MAPPING ---

    // 1. OPEN PALM (All 5 extended)
    if (iUp && mUp && rUp && pUp && tUp) {
      return "SIGN: OPEN PALM";
    }

    // 2. THUMBS UP (Only Thumb extended, others folded)
    if (tUp && !iUp && !mUp && !rUp && !pUp) {
      return "SIGN: THUMBS UP";
    }

    // 3. PEACE SIGN (Index and Middle up, others down)
    if (iUp && mUp && !rUp && !pUp) {
      return "SIGN: PEACE";
    }

    // 4. FIST (All fingers folded)
    if (!iUp && !mUp && !rUp && !pUp && !tUp) {
      return "SIGN: FIST";
    }

    // 5. POINTING (Only Index up)
    if (iUp && !mUp && !rUp && !pUp) {
      return "SIGN: POINTING";
    }

    return "Scanning... (Hand Detected)";
  }

  @override
  void dispose() {
    _controller?.dispose();
    _plugin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("FYP: Hand Recognition")),
      body: Stack(
        children: [
          // 1. Camera - Scaled to fill screen
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // 2. Transformed Skeleton Overlay
          if (_currentLandmarks.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: HandPainter(_currentLandmarks),
              ),
            ),

          // 3. Status Display
          Positioned(
            bottom: 50, left: 30, right: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent, width: 2),
              ),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- LANDMARK PAINTER (SCENARIO 1 FIX) ---
class HandPainter extends CustomPainter {
  final List<dynamic> points;
  HandPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = Colors.white..strokeWidth = 3;
    final paintPoint = Paint()..color = Colors.cyanAccent;

    Offset getOffset(int index) {
      /* THE TRANSFORMATION:
         We swap the AI's sideways view to match our vertical screen.
         AI-Y becomes Screen-X
         AI-X becomes Screen-Y
      */
      double rawX = points[index].y;
      double rawY = points[index].x;

      // Map to screen dimensions while fixing the mirroring
      return Offset(
          (1.0 - rawX) * size.width,
          (1.0 - rawY) * size.height
      );
    }

    void drawLine(int a, int b) {
      canvas.drawLine(getOffset(a), getOffset(b), paintLine);
    }

    if (points.length >= 21) {
      // Connect landmarks
      for (int i = 0; i < 5; i++) {
        int b = i * 4 + 1;
        drawLine(0, b); drawLine(b, b + 1); drawLine(b + 1, b + 2); drawLine(b + 2, b + 3);
      }
      // Draw joint dots
      for (int i = 0; i < 21; i++) {
        canvas.drawCircle(getOffset(i), 5, paintPoint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
