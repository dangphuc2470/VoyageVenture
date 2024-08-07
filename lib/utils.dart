import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer' as developer;
import 'dart:ui'
    as ui; // imported as ui to prevent conflict between ui.Image and the Image widget
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding_platform_interface/src/models/location.dart' as geo_location;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'package:flutter_google_maps_webservices/geocoding.dart';

import 'features/current_location.dart';

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

Future<LatLng> getCurrentLocationLatLng() async {
  Position position = await getCurrentLocation();
  return LatLng(position.latitude, position.longitude);
}

int countValidFields(Placemark placemark) {
  int count = 0;
  //if (placemark.name?.isNotEmpty ?? false) count++;
  if (placemark.street?.isNotEmpty ?? false) count++;
 // if (placemark.isoCountryCode?.isNotEmpty ?? false) count++;
  if (placemark.country?.isNotEmpty ?? false) count++;
 // if (placemark.postalCode?.isNotEmpty ?? false) count++;
  if (placemark.administrativeArea?.isNotEmpty ?? false) count++;
  if (placemark.subAdministrativeArea?.isNotEmpty ?? false) count++;
  if (placemark.locality?.isNotEmpty ?? false) count++;
  if (placemark.subLocality?.isNotEmpty ?? false) count++;
  if (placemark.thoroughfare?.isNotEmpty ?? false) count++;
  //if (placemark.subThoroughfare?.isNotEmpty ?? false) count++;
  return count;
}

Future<String> convertLatLngToAddress(LatLng latlng, {bool isCutoff = false}) async {
  double lat = latlng.latitude;
  double lng = latlng.longitude;
  try {
    List<Placemark> placeMarks = await placemarkFromCoordinates(lat, lng);
    placeMarks.sort((a, b) => countValidFields(b).compareTo(countValidFields(a)));
    
    var addressParts = [
      placeMarks[0].street,
      placeMarks[0].subLocality,
      placeMarks[0].locality,
      placeMarks[0].subAdministrativeArea,
      placeMarks[0].administrativeArea,
      placeMarks[0].country
    ].where((s) => s?.isNotEmpty ?? false).join(', ');


    if (isCutoff) {
      String displayText = addressParts.length > 30 ? addressParts.substring(0, 30) + '...' : addressParts;
      logWithTag('Address: $displayText', tag: 'convertLatLngToAddress');
      return displayText;
    } else {
      logWithTag('Address: $addressParts', tag: 'convertLatLngToAddress');
      return addressParts;
    }
  } catch (e) {
    print('Failed to convert LatLng to address: $e');
    return '';
  }
}
Future<String> convertLatLngToAddress2(LatLng latlng, {bool isCutoff = false}) async {
  double lat = latlng.latitude;
  double lng = latlng.longitude;
  try {
    List<Placemark> placeMarks = await placemarkFromCoordinates(lat, lng);
    placeMarks.sort((a, b) => countValidFields(b).compareTo(countValidFields(a)));

    var addressParts = [
      placeMarks[0].street,
      placeMarks[0].subLocality,
      placeMarks[0].locality,
      placeMarks[0].subAdministrativeArea,
      placeMarks[0].administrativeArea,
      placeMarks[0].country
    ].where((s) => s?.isNotEmpty ?? false).join(', ');


    if (isCutoff) {
      String displayText = addressParts.length > 50 ? addressParts.substring(0, 30) + '...' : addressParts;
      logWithTag('Address: $displayText', tag: 'convertLatLngToAddress');
      return displayText;
    } else {
      logWithTag('Address: $addressParts', tag: 'convertLatLngToAddress');
      return addressParts;
    }
  } catch (e) {
    print('Failed to convert LatLng to address: $e');
    return '';
  }
}
  Future<String> convertAddressToLatLng(String address) async {
    try {
      List<geo_location.Location> locations = await locationFromAddress(address);
      return 'Latitude: ${locations[0].latitude}, Longitude: ${locations[0].longitude}';
    } catch (e) {
      print('Failed to convert address to LatLng: $e');
      return '';
    }
  }

  String LatLngToString(LatLng latLng, {bool isCutoff = true}) {
  if (isCutoff) {
    return '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
  }
    return '${latLng.latitude}, ${latLng.longitude}';
  }