import 'dart:io';

import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(new MyApp());

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
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File _image;
  CameraController controller;

  @override
  initState() {
    super.initState();
    initCam();
  }

  initCam() async {
    var cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    setState(() {});
  }

  Future onCameraCapture() async {
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (!mounted) {
      return;
    }

    var path = await takePicture(controller);

    setState(() {
      _image = File(path);
    });
  }

  Future<String> takePicture(CameraController controller) async {
    if (!controller.value.isInitialized) {
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = '$dirPath/$timestamp.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      return null;
    }
    return filePath;
  }

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);

    setState(() {
      _image = image;
    });
  }

  Future<String> getExifFromFile() async {
    if (_image == null) {
      return null;
    }

    var bytes = await _image.readAsBytes();
    var tags = await readExifFromBytes(bytes);
    var sb = StringBuffer();

    tags.forEach((k, v) {
      sb.write("$k: $v \n");
    });

    return sb.toString();
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
              child: controller != null && controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller))
                  : Container(),
              height: 200.0,
            ),
            SizedBox(
              child: _image == null
                  ? Text('No image selected.')
                  : Image.file(_image),
              height: 200.0,
            ),
            FutureBuilder(
              future: getExifFromFile(),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data != null) {
                    return Text(snapshot.data);
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
