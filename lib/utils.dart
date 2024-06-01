import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer' as developer;
import 'dart:ui'
    as ui; // imported as ui to prevent conflict between ui.Image and the Image widget
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

void showToast(String message) {
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.grey,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}

void logWithTag(String message, {String tag = 'MyTag'}) {
  developer.log(message, name: tag);
}

class BitmapDescriptorHelper {
  static Future<BitmapDescriptor> getBitmapDescriptorFromSvgAsset(
    String assetName, [
    Size size = const Size(48, 48),
  ]) async {
    final pictureInfo = await vg.loadPicture(SvgAssetLoader(assetName), null);
    double devicePixelRatio = ui.window.devicePixelRatio;
    int width = (size.width * devicePixelRatio).toInt();
    int height = (size.height * devicePixelRatio).toInt();

    final scaleFactor = math.min(
      width / pictureInfo.size.width,
      height / pictureInfo.size.height,
    );

    final recorder = ui.PictureRecorder();

    ui.Canvas(recorder)
      ..scale(scaleFactor)
      ..drawPicture(pictureInfo.picture);

    final rasterPicture = recorder.endRecording();

    final image = rasterPicture.toImageSync(width, height);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;

    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> getBitmapDescriptorFromJPGAsset(
    String assetName, [
    Size size = const Size(48, 48),
  ]) async {
    final ByteData data = await rootBundle.load(assetName);
    final Codec codec = await instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size.width.toInt(),
      targetHeight: size.height.toInt(),
    );
    final FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ImageByteFormat
          .png, // Sử dụng định dạng PNG để tương thích với BitmapDescriptor
    );
    if (byteData == null) {
      throw Exception('Failed to decode image data.');
    }
    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }
}

Future<void> animateBottomSheet(
    DraggableScrollableController controller, double position) {
  return controller.animateTo(
    position,
    // Scroll to the top of the DraggableScrollableSheet
    duration: const Duration(milliseconds: 300),
    // Duration to complete the scrolling
    curve: Curves.fastOutSlowIn, // Animation curve
  );
}
