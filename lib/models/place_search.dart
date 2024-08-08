import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:voyageventure/models/fetch_photo_url.dart';
import 'package:http/http.dart' as http;
import 'package:voyageventure/utils.dart';

class PlaceSearch_ {
  final String? id;
  final String? formattedAddress;
  final Location location;
  final DisplayName? displayName;
  String? photoUrls;

  PlaceSearch_({
    this.id,
    this.formattedAddress,
    required this.location,
    this.displayName,
    this.photoUrls,
  });

static Future<String> getPhotoUrls(String id, int width, int height) async {
  var value = await fetchPhotoUrls(id);
  if (value.isEmpty) {
    return "";
  }
  String photoID = value.first;
  if (photoID.contains("/"))
  {
    photoID =   photoID.split("/").last;
  }
  final response = await http.get(Uri.parse("https://places.googleapis.com/v1/places/${id}/photos/${photoID}/media?maxHeightPx=${height}&maxWidthPx=${width}&key=${dotenv.env['MAPS_API_KEY1']}&skipHttpRedirect=true"));
  if (response.statusCode == 200) {
    var jsonResponse = jsonDecode(response.body);
    String photoUri = jsonResponse['photoUri'];
    return photoUri;
  } else {
    throw Exception('Failed to load photos');
  }
}


  @override
  String toString()
  {
    return 'PlaceSearch_ { id: $id, formattedAddress: $formattedAddress, location: ${location.toString()}, displayName: $displayName }';
  }

  factory PlaceSearch_.fromJson(Map<String, dynamic> json) {
    return PlaceSearch_(
      id: json['id'] as String?,
      formattedAddress: json['formattedAddress'] as String?,
      location: Location.fromJson(json['location']),
      displayName: json['displayName'] != null
          ? DisplayName.fromJson(json['displayName'])
          : null,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }

  @override
  String toString() {
    return 'Location { latitude: $latitude, longitude: $longitude }';
  }
}

class DisplayName {
  final String? text;
  final String? languageCode;

  DisplayName({this.text, this.languageCode});

  factory DisplayName.fromJson(Map<String, dynamic> json) {
    return DisplayName(
      text: json['text'] as String?,
      languageCode: json['languageCode'] as String?,
    );
  }

  @override
  String toString() {
    return 'DisplayName { text: $text, languageCode: $languageCode }';
  }
}