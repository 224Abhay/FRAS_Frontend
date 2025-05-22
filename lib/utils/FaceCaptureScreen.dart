import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:identify_fras/services/api_service.dart';

class FaceCaptureScreen extends StatefulWidget {
  @override
  _FaceCaptureScreenState createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() => isLoading = false);
    } catch (e) {
      print('Camera init error: $e');
    }
  }

  Future<void> _takePictureAndUpload() async {
    if (!_controller!.value.isInitialized) return;

    final XFile file = await _controller!.takePicture();
    final bytes = await File(file.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await postApiRequest("/update-face", {
      "face_image": base64Image,
    });

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face data updated successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update face data')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Face Data'),
        backgroundColor: const Color(0xFF2970FE),
      ),
      body: Column(
        children: [
          // Keep camera preview in a taller 4:3 box
          AspectRatio(
            aspectRatio: 3 / 4, // 3:4 makes it taller than wide (portrait 4:3)
            child: ClipRect(
              child: CameraPreview(_controller!),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _takePictureAndUpload,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture & Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2970FE),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 5,
            ),
          ),
        ],
      ),
    );
  }
}
