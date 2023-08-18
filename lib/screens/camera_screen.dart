import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:edge_detection/edge_detection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../shared/expandable_fab.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _imagePath;
  String? message = '';
  File? selectedImage;
  bool isLoading = false;
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
  }

  Future<void> getImageFromCamera() async {
    bool isCameraGranted = await Permission.camera.request().isGranted;
    if (!isCameraGranted) {
      isCameraGranted =
          await Permission.camera.request() == PermissionStatus.granted;
    }

    if (!isCameraGranted) {
      // Have not permission to camera
      return;
    }

    // Generate filepath for saving
    String imagePath = join((await getApplicationSupportDirectory()).path,
        "${(DateTime.now().millisecondsSinceEpoch / 1000).round()}.jpeg");

    try {
      //Make sure to await the call to detectEdge.
      bool success = await EdgeDetection.detectEdge(
        imagePath,
        canUseGallery: true,
        androidScanTitle: 'Scanning', // use custom localizations for android
        androidCropTitle: 'Crop',
        androidCropBlackWhiteTitle: 'Black White',
        androidCropReset: 'Reset',
      );
      print("success: $success");
    } catch (e) {
      print(e);
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _imagePath = imagePath;
      selectedImage = File(_imagePath ?? '');
    });
  }

  // Future<void> getImageFromGallery() async {
  //   // Generate filepath for saving
  //   String imagePath = join((await getApplicationSupportDirectory()).path,
  //       "${(DateTime.now().millisecondsSinceEpoch / 1000).round()}.jpeg");

  //   try {
  //     //Make sure to await the call to detectEdgeFromGallery.
  //     bool success = await EdgeDetection.detectEdgeFromGallery(
  //       imagePath,
  //       androidCropTitle: 'Crop', // use custom localizations for android
  //       androidCropBlackWhiteTitle: 'Black White',
  //       androidCropReset: 'Reset',
  //     );
  //     log("success: $success");
  //   } catch (e) {
  //     log(e.toString());
  //   }

  //   // If the widget was removed from the tree while the asynchronous platform
  //   // message was in flight, we want to discard the reply rather than calling
  //   // setState to update our non-existent appearance.
  //   if (!mounted) return;

  //   setState(() {
  //     _imagePath = imagePath;
  //     selectedImage = File(_imagePath ?? '');
  //   });
  // }
  Future getImageFromGallery() async {
    final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    selectedImage = File(pickedImage!.path);

    setState(() {});
  }

  _scanImage() async {
    setState(() {
      isLoading = true;
    });

    final request = http.MultipartRequest(
        "POST", Uri.parse("http://localhost:4000/upload"));
    final headers = {"Content-type": "multipart/form-data"};
    request.files.add(http.MultipartFile('image',
        selectedImage!.readAsBytes().asStream(), selectedImage!.lengthSync(),
        filename: selectedImage!.path.split("/").last));
    request.headers.addAll(headers);
    final response = await request.send();
    http.Response res = await http.Response.fromStream(response);
    final resJson = jsonDecode(res.body);
    message = resJson['message'];
    log(message.toString());

    setState(() {
      isLoading = false;
    });

    //await convertToPdf(message); // Convert the extracted text to PDF
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devanagari OCR'),
      ),
      floatingActionButton: ExpandableFab(
        distance: 70,
        children: [
          ActionButton(
            title: 'Camera',
            onPressed: getImageFromCamera,
            icon: const Icon(
              Icons.camera,
              color: Colors.white,
              size: 15,
            ),
          ),
          ActionButton(
            title: 'Gallery',
            onPressed: getImageFromGallery,
            icon: const Icon(Icons.photo_album),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        child: selectedImage == null
            ? const Center(child: Text("Please pick a image to scan"))
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Image.file(selectedImage!, fit: BoxFit.contain),
                    ElevatedButton(
                        onPressed: _scanImage, child: const Text('Scan')),
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          const Text(
                            'Scanned Text',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Text(
                            '$message',
                            style: const TextStyle(
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
