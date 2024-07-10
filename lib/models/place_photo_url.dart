import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:voyageventure/utils.dart';

Future<List<String>> fetchPhotoUrls(String placeID) async {
  final response = await http.get(Uri.parse(
      'https://places.googleapis.com/v1/places/${placeID}?fields=photos&key=${dotenv.env['MAPS_API_KEY1']}'));
  if (response.statusCode == 200) {
    var jsonResponse = jsonDecode(response.body);
    List<String> photoUrls = [];
    if (jsonResponse['photos'] != null) {
      for (var photo in jsonResponse['photos']) {
        photoUrls.add(photo['name']);
      }
      return photoUrls;
    } else
      return photoUrls;
    //logWithTag(photoUrls.toString(), tag: 'fetchPhotoUrls of $placeID');
  } else {
    throw Exception('Failed to load photos');
  }
}

Future<String> getPhotoUrls(String id, int width, int height) async {
  var value = await fetchPhotoUrls(id);
  if (value.isEmpty) {
    return "";
  }
  String photoID = value.first;
  if (photoID.contains("/")) {
    photoID = photoID.split("/").last;
  }
  final response = await http.get(Uri.parse(
      "https://places.googleapis.com/v1/places/${id}/photos/${photoID}/media?maxHeightPx=${height}&maxWidthPx=${width}&key=${dotenv.env['MAPS_API_KEY1']}&skipHttpRedirect=true"));
  if (response.statusCode == 200) {
    var jsonResponse = jsonDecode(response.body);
    String photoUri = jsonResponse['photoUri'];
    return photoUri;
  } else {
    throw Exception('Failed to load photos');
  }
}
