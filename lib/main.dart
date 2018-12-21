import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  /// holds the current device orientation
  int _deviceOrientation;
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

  /// Rotate a [Widget] by the current device orientation
  Widget buildOrientationAware(Widget widget) {
    return NativeDeviceOrientationReader(builder: (context) {
      NativeDeviceOrientation orientation =
          NativeDeviceOrientationReader.orientation(context);

      // how many times to change orientation by 90 degrees clock-wise
      int turns;
      switch (orientation) {
        case NativeDeviceOrientation.landscapeRight:
          turns = 1;
          break;
        case NativeDeviceOrientation.portraitDown:
          turns = 2;
          break;
        case NativeDeviceOrientation.landscapeLeft:
          turns = 3;
          break;
        default:
          turns = 0;
          break;
      }
      if (Platform.isIOS) {
        // temporary fix for https://github.com/rmtmckenzie/flutter_native_device_orientation/issues/5
        // landscape rotations need to be rotated by 180°
        if (turns == 1) {
          turns = -1;
        }
        if (turns == 3) {
          turns = 1;
        }
      }

      _deviceOrientation = turns * 90;

      assert(turns <= 4,
          'turns has to be a small integer and not a degrees number');
      return RotatedBox(
        quarterTurns: turns,
        child: widget,
      );
    });
  }

  /// Get the number of degrees by which EXIF orientation needs to be correct to have portrait mode
  Future<int> getEXIFOrientationCorrection(List<int> image) async {
    int rotationCorrection = 0;
    Map<String, IfdTag> exif = await readExifFromBytes(image);

    if (exif == null || exif.isEmpty) {
      print("No EXIF information found");
    } else {
      print("Found EXIF information");
      // http://sylvana.net/jpegcrop/exif_orientation.html
      IfdTag orientation = exif["Image Orientation"];
      int orientationValue = orientation.values[0];
      // in degress
      print("orientation: ${orientation.printable}/${orientation.values[0]}");
      switch (orientationValue) {
        case 6:
          rotationCorrection = 90;
          break;
        case 3:
          rotationCorrection = 180;
          break;
        case 8:
          rotationCorrection = 270;
          break;
        default:
      }
    }
    return rotationCorrection;
  }

  Future<Widget> getImageFromCamera(BuildContext context) async {
    Widget res;
    if (_image == null) {
      res = Text('No image selected.');
    } else {
      var imageData = _image.readAsBytesSync();

      int rotationCorrection = 0;
      // for Android the EXIF information seems correct and can be used to rotate the image
      // for iOS the device orientation is used and EXIF orientation is incorrect
      if (Platform.isAndroid) {
        // use EXIF data to correct image orientation
        rotationCorrection = await getEXIFOrientationCorrection(imageData);
        // don't use device orienation
        _deviceOrientation = 0;
      }
      print(
          "applying orientation correction of ${_deviceOrientation + rotationCorrection}");
      var imageDataCompressed = await FlutterImageCompress.compressWithList(
          imageData,
          quality: 90,
          rotate: _deviceOrientation + rotationCorrection);
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
              child: controller != null && controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      // rotate camera preview by device orientation to have portrait mode-like view
                      child: buildOrientationAware(CameraPreview(controller)))
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
