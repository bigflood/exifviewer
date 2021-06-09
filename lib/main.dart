import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EXIF Viewer Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'EXIF Viewer Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  File? _image;
  final picker = ImagePicker();

  CameraController? controller;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        _initCamera();
      }
    }
  }

  void _initCamera() async {
    controller?.dispose();

    var cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller!.initialize();
    setState(() {});
  }

  Future onCameraCapture() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    if (!mounted) {
      return;
    }

    var path = await takePicture(controller!);
    if (path.isNotEmpty) {
      setState(() {
        _image = File(path);
      });
    }
  }

  Future<String> takePicture(CameraController controller) async {
    if (!controller.value.isInitialized) {
      return "";
    }

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return "";
    }

    try {
      final f = await controller.takePicture();
      return f.path;
    } on CameraException catch (e) {
      return "";
    }
  }

  Future getImage() async {
    var image = await picker.getImage(source: ImageSource.gallery);
    setState(() {
      if (image != null) {
        _image = File(image.path);
      }
    });
  }

  Future<String> getExifFromFile() async {
    if (_image == null) {
      return "";
    }

    var bytes = await _image!.readAsBytes();
    var tags = await readExifFromBytes(bytes);
    var sb = StringBuffer();

    tags.forEach((k, v) {
      sb.write("$k: $v \n");
    });

    return sb.toString();
  }

  Future<Widget> getImageFromCamera(BuildContext context) async {
    Widget res;
    if (_image == null) {
      res = Text('No image selected.');
    } else {
      var imageData = _image!.readAsBytesSync();

      var imageDataCompressed =
          await FlutterImageCompress.compressWithList(imageData);
      res = Image.memory(Uint8List.fromList(imageDataCompressed));
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EXIF Viewer Example'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.camera),
            onPressed: onCameraCapture,
          )
        ],
      ),
      body: ListView(children: <Widget>[
        Column(
          children: <Widget>[
            SizedBox(
              child: controller?.value.isInitialized ?? false
                  ? CameraPreview(controller!)
                  : Container(),
              height: 200.0,
            ),
            FutureBuilder(
                future: getImageFromCamera(context),
                builder:
                    (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data != null) {
                      return SizedBox(
                        child: snapshot.data,
                        height: 200.0,
                      );
                    } else {
                      return CircularProgressIndicator();
                    }
                  }
                  return Container();
                }),
            FutureBuilder(
              future: getExifFromFile(),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data != null) {
                    return Text(snapshot.data ?? "");
                  } else {
                    return CircularProgressIndicator();
                  }
                }
                return Container();
              },
            ),
          ],
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.photo_library),
      ),
    );
  }
}
