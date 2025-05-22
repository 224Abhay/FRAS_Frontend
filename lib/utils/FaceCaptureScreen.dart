import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:identify_fras/services/api_service.dart';
import 'package:image/image.dart' as img;

class FaceCaptureScreen extends StatefulWidget {
  @override
  _FaceCaptureScreenState createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  bool isCameraLoading = true;
  bool isUploading = false;

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
      setState(() => isCameraLoading = false);
    } catch (e) {
      print('Camera init error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize camera')),
      );
    }
  }

  Future<void> _takePictureAndUpload() async {
    if (!_controller!.value.isInitialized) return;

    setState(() => isUploading = true);

    try {
      final XFile file = await _controller!.takePicture();
      final File imageFile = File(file.path);

      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      img.Image fixedImage = img.bakeOrientation(originalImage);

      final tempDir = Directory.systemTemp;
      final File portraitImage = File('${tempDir.path}/portrait.jpg');
      await portraitImage.writeAsBytes(img.encodeJpg(fixedImage));

      final response =
          await postMultipartRequest("/student/update_facedata", portraitImage);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face data updated successfully')),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed: ${response.body}');
      }
    } catch (e) {
      print('Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Face Data'),
        backgroundColor: const Color(0xFF2970FE),
      ),
      body: Stack(
        children: [
          if (isCameraLoading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: isUploading ? null : _takePictureAndUpload,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    isUploading ? 'Uploading...' : 'Capture & Upload',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2970FE),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 6,
                  ),
                ),
              ],
            ),

          // Uploading Overlay
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Uploading face data...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
