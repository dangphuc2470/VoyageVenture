import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter_api/google_places_flutter_api.dart';
import 'package:voyageventure/components/fonts.dart';
import 'package:voyageventure/components/location_list_tile.dart';
import 'package:voyageventure/components/mock_list.dart';
import 'package:voyageventure/components/network_utils.dart';
import 'package:voyageventure/constants.dart';
import 'package:voyageventure/models/place_autocomplete_response.dart';
import 'package:voyageventure/models/place_search_response.dart';
import 'package:voyageventure/utils.dart';
import 'package:http/http.dart' as http;

import '../models/place_autocomplete.dart';
import '../models/place_search.dart';

// class LocationSearchScreen_ extends StatefulWidget {
//   ScrollController controller;
//   DraggableScrollableController sheetController;
//   Completer<GoogleMapController> mapsController;
//   List<Marker> markerList;
//
//   LocationSearchScreen_(
//       {Key? key,
//       required this.controller,
//       required this.sheetController,
//       required this.mapsController,
//       required this.markerList})
//       : super(key: key);
//
//   @override
//   State<LocationSearchScreen_> createState() => _LocationSearchScreen_State();
// }
//
// class _LocationSearchScreen_State extends State<LocationSearchScreen_> {
//   List<PlaceAutocomplete_> placeAutoList = [];
//   List<PlaceSearch_> placeSearchList = [];
//   bool placeFound = true;
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Placeholder();
//   }

//   void addMarker(PlaceSearch_ place) {
//     final markerId = MarkerId(place.id!);
//     final marker = Marker(
//       markerId: markerId,
//       position: LatLng(
//           place.location?.latitude ?? 0.0, place.location?.longitude ?? 0.0),
//       infoWindow: InfoWindow(
//         title: place.displayName?.text,
//         snippet: place.formattedAddress,
//       ),
//     );
//     setState(() {
//       widget.markerList.add(marker);
//     });
//   }
// }

Future<List<PlaceAutocomplete_>?> placeAutocomplete(String query, LatLng? center, double radius) async {
  print("Autocomplete: $query");
  center ??= const LatLng(0, 0);
  var url = Uri.parse('https://places.googleapis.com/v1/places:autocomplete');
  var headers = {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
  };
  var body = jsonEncode({
    'input': query,
    'locationBias': {
      'circle': {
        'center': {
          "latitude": center.latitude,
          "longitude": center.longitude
        },
        'radius': radius
      }
    }
  });
  var response = await http.post(url, headers: headers, body: body);
  if (response.statusCode == 200) {
    PlaceAutocompleteResponse_ result =
        PlaceAutocompleteResponse_.parseAutocompleteResult(response.body);
    if (result.suggestions != null) {
      logWithTag("Autocomplete: ${result.toString()}",
          tag: "SearchLocationScreen");
      return result.suggestions;
    } else
      logWithTag("No predictions found", tag: "SearchLocationScreen");
    return null;
  } else {
    print('Request failed with status: ${response.statusCode}.');
    logWithTag("Request failed with status: ${response.body}.",
        tag: "SearchLocationScreen");
    return null;
  }
}

Future<List<PlaceSearch_>?> placeSearch(String query) async {
  print("Search: $query");
  var url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
  var headers = {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
    'X-Goog-FieldMask':
        'places.displayName,places.formattedAddress,places.location,places.id',
  };
  var body = jsonEncode({
    'textQuery': query,
  });
  var response = await http.post(url, headers: headers, body: body);
  if (response.statusCode == 200) {
    PlaceSearchResponse_ result =
        PlaceSearchResponse_.parsePlaceSearchResult(response.body);
    if (result.places != null) {
      logWithTag("Search: ${result.toString()}", tag: "SearchLocationScreen");
      return result.places;
    } else {
      logWithTag("No places found", tag: "SearchLocationScreen");
      return null;
    }
  } else {
    print('Request failed with status: ${response.statusCode}.');
    logWithTag("Request failed with status: ${response.body}.",
        tag: "SearchLocationScreen");
    return null;
  }
}

Future<PlaceSearch_?> placeSearchSingle(String query) async {
  print("Search: $query");
  var url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
  var headers = {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
    'X-Goog-FieldMask':
    'places.displayName,places.formattedAddress,places.location,places.id',
  };
  var body = jsonEncode({
    'textQuery': query,
  });
  var response = await http.post(url, headers: headers, body: body);
  if (response.statusCode == 200) {
    PlaceSearchResponse_ result =
    PlaceSearchResponse_.parsePlaceSearchResult(response.body);
    if (result.places != null && result.places!.isNotEmpty) {
      logWithTag("Search: ${result.toString()}", tag: "SearchLocationScreen");
      return result.places!.first;
    } else {
      logWithTag("No places found", tag: "SearchLocationScreen");
      return null;
    }
  } else {
    print('Request failed with status: ${response.statusCode}.');
    logWithTag("Request failed with status: ${response.body}.",
        tag: "SearchLocationScreen");
    return null;
  }
}
