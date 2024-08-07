import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:voyageventure/models/route_calculate_response.dart';
import '../utils.dart';

Future<List<LatLng>?> computeRoutes({
  required LatLng from,
  required LatLng to,
  String? departureTime,
  bool computeAlternativeRoutes = false,
  bool avoidTolls = false,
  bool avoidHighways = false,
  bool avoidFerries = false,
  String travelMode = "DRIVE",
  String routingPreference = "TRAFFIC_AWARE",
  String languageCode = "VI",
  String units = "Metric",
}) async {
  logWithTag('computeRoutes', tag: 'computeRoutes');

  departureTime ??= DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String();
  final response = await http.post(
    Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
    headers: <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
      //'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
      'X-Goog-FieldMask': '*',
    },
    body: jsonEncode(<String, dynamic>{
      'origin': {
        'location': {
          'latLng': {
            'latitude': from.latitude,
            'longitude': from.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': to.latitude,
            'longitude': to.longitude,
          },
        },
      },
      'travelMode': travelMode,
      'routingPreference': routingPreference,
      'departureTime': departureTime,
      'computeAlternativeRoutes': computeAlternativeRoutes,
      'routeModifiers': {
        'avoidTolls': avoidTolls,
        'avoidHighways': avoidHighways,
        'avoidFerries': avoidFerries,
      },
      'languageCode': languageCode,
      'units': units,
    }),
  );

  logWithTag("response.body.toString()", tag: 'computeRoutes');
  //logWithTag(response.body.toString(), tag: 'computeRoutes');

  if (response.statusCode == 200) {
    //Map<String, dynamic> values = jsonDecode(response.body);
    //String encodedPolyline = values['routes'][0]['polyline']['encodedPolyline'];
    final parsed = json.decode(response.body).cast<String, dynamic>();
    RouteResponse_ routeResponse = RouteResponse_.fromJson(parsed);
    Route_ route = routeResponse.routes[0];
    List<LatLng> polylinePoints =
        Polyline_.decodePolyline(route.legs[0].polyline.encodedPolyline);
    //logWithTag(route.toString(), tag: 'computeRoutes');
    logWithTag("route.toString()", tag: 'computeRoutes');
    return polylinePoints;
  }
  print("Error: ${response.body}");
  return null;
}

Future<List<Route_>?> computeRoutesReturnRoute_({
  required LatLng from,
  required LatLng to,
  String? departureTime,
  bool computeAlternativeRoutes = false,
  bool avoidTolls = false,
  bool avoidHighways = false,
  bool avoidFerries = false,
  String travelMode = "DRIVE",
  String routingPreference = "TRAFFIC_AWARE",
  String languageCode = "VI",
  String units = "Metric",
  required List<LatLng> waypoints,
}) async {
  logWithTag('computeRoutes', tag: 'computeRoutes');

  departureTime ??= DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String();

  List<Map<String, dynamic>> intermediates = waypoints.map((waypoint) => {
    'location': {
      'latLng': {
        'latitude': waypoint.latitude,
        'longitude': waypoint.longitude,
      },
    },
  }).toList();

  Map<String, dynamic> requestBody = {
  'origin': {
    'location': {
      'latLng': {
        'latitude': from.latitude,
        'longitude': from.longitude,
      },
    },
  },
  'destination': {
    'location': {
      'latLng': {
        'latitude': to.latitude,
        'longitude': to.longitude,
      },
    },
  },
  'intermediates': intermediates,
  'travelMode': travelMode,
  'departureTime': departureTime,
  'computeAlternativeRoutes': computeAlternativeRoutes,
  'routeModifiers': {
    'avoidTolls': avoidTolls,
    'avoidHighways': avoidHighways,
    'avoidFerries': avoidFerries,
  },
  'languageCode': languageCode,
  'units': units,
};

if (travelMode != "WALK" && travelMode != "TRANSIT") {
  requestBody['routingPreference'] = routingPreference;
}

logWithTag(jsonEncode(requestBody), tag: 'Request body');

final response = await http.post(
  Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
  headers: <String, String>{
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
    'X-Goog-FieldMask': '*',
  },
  body: jsonEncode(requestBody),
);

  logWithTag(response.body.toString(), tag: 'computeRoutes');

  if (response.statusCode == 200) {
    //Map<String, dynamic> values = jsonDecode(response.body);
    //String encodedPolyline = values['routes'][0]['polyline']['encodedPolyline'];
    final parsed = json.decode(response.body).cast<String, dynamic>();
    RouteResponse_ routeResponse = RouteResponse_.fromJson(parsed);

    logWithTag(routeResponse.toString(), tag: 'computeRoutesToRoute_');
    return routeResponse.routes;
  }
  print("Error: ${response.body}");
  return null;
}

Future<void> decodeSteps(String responseBody, List<Step_>? steps) async {
  logWithTag("decodeSteps", tag: 'decodeSteps');
  steps = json.decode(responseBody)['routes'][0]['legs'][0]['steps'].map<Step_>((step) => Step_.fromJson(step)).toList();
  logWithTag(steps.toString(), tag: 'decodeSteps');
}

// Future<RouteResponse_?> computeRoutesReturnRouteResponse_({
//   required LatLng from,
//   required LatLng to,
//   String? departureTime,
//   bool computeAlternativeRoutes = false,
//   bool avoidTolls = false,
//   bool avoidHighways = false,
//   bool avoidFerries = false,
//   String travelMode = "DRIVE",
//   String routingPreference = "TRAFFIC_AWARE",
//   String languageCode = "VI",
//   String units = "Metric",
// }) async {
//   logWithTag('computeRoutes', tag: 'computeRoutes');
//
//   departureTime ??= DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String();
//   final response = await http.post(
//     Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
//     headers: <String, String>{
//       'Content-Type': 'application/json',
//       'X-Goog-Api-Key': dotenv.env['MAPS_API_KEY1']!,
//       //'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
//       'X-Goog-FieldMask': '*',
//     },
//     body: jsonEncode(<String, dynamic>{
//       'origin': {
//         'location': {
//           'latLng': {
//             'latitude': from.latitude,
//             'longitude': from.longitude,
//           },
//         },
//       },
//       'destination': {
//         'location': {
//           'latLng': {
//             'latitude': to.latitude,
//             'longitude': to.longitude,
//           },
//         },
//       },
//       'travelMode': travelMode,
//       'routingPreference': routingPreference,
//       'departureTime': departureTime,
//       'computeAlternativeRoutes': computeAlternativeRoutes,
//       'routeModifiers': {
//         'avoidTolls': avoidTolls,
//         'avoidHighways': avoidHighways,
//         'avoidFerries': avoidFerries,
//       },
//       'languageCode': languageCode,
//       'units': units,
//     }),
//   );
//
//   logWithTag(response.body.toString(), tag: 'computeRoutes');
//
//   if (response.statusCode == 200) {
//     //Map<String, dynamic> values = jsonDecode(response.body);
//     //String encodedPolyline = values['routes'][0]['polyline']['encodedPolyline'];
//     final parsed = json.decode(response.body).cast<String, dynamic>();
//     RouteResponse_ routeResponse = RouteResponse_.fromJson(parsed);
//     logWithTag(routeResponse.toString(), tag: 'computeRoutesToRouteResponse_');
//     return routeResponse.routes;
//   }
//   print("Error: ${response.body}");
//   return null;
// }



