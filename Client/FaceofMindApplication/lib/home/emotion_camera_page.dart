import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

class EmotionCameraPage extends StatefulWidget {
  const EmotionCameraPage({Key? key}) : super(key: key);

  @override
  State<EmotionCameraPage> createState() => _EmotionCameraPageState();
}

class _EmotionCameraPageState extends State<EmotionCameraPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  String _detectedEmotion = '';
  List<CameraDescription>? _cameras;
  bool _loading = true;
  bool _isProcessingAI = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _cameraController = CameraController(
      _cameras![1], // Use front camera
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    _cameraController!.startImageStream(_processCameraImage);
    setState(() => _loading = false);
  }

  Future<void> _loadModel() async {
    await Tflite.loadModel(
      model: 'assets/emotion_model.tflite',
      labels: 'assets/emotion_labels.txt',
    );
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessingAI) return;
    _isDetecting = true;
    try {
      var recognitions = await Tflite.runModelOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        numResults: 1,
        threshold: 0.5,
      );
      if (recognitions != null && recognitions.isNotEmpty) {
        setState(() {
          _detectedEmotion = recognitions[0]['label'];
          _isProcessingAI = true;
        });
        _handleAIResponse(_detectedEmotion);
      }
    } catch (e) {
      // ignore errors
    }
    _isDetecting = false;
  }

  Future<void> _handleAIResponse(String emotion) async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isProcessingAI = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Emotion Detection')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  CameraPreview(_cameraController!),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _isProcessingAI
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Processing...',
                                  style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _detectedEmotion.isEmpty ? 'Detecting...' : _detectedEmotion,
                              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
} 