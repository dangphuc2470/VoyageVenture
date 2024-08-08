import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:voyageventure/components/custom_search_field.dart';
import 'package:voyageventure/components/route_planning_list_tile.dart';
import 'package:voyageventure/components/navigation_list_tile.dart';
import 'package:voyageventure/components/misc_widget.dart';
import 'package:voyageventure/components/waypoint_list.dart';
import 'package:voyageventure/constants.dart';
import 'package:voyageventure/models/fetch_photo_url.dart';
import 'package:voyageventure/models/route_calculate_response.dart';
import 'package:voyageventure/utils.dart';
import 'package:voyageventure/features/current_location.dart';
import '../MyLocationSearch/my_location_search.dart';
import '../components/bottom_sheet_component.dart';
import '../components/custom_search_delegate.dart';
import '../components/end_location_list.dart';
import '../components/fonts.dart';
import '../components/loading_indicator.dart';
import '../components/location_list_tile.dart';
import '../components/route_planning_list.dart';
import '../location_sharing.dart';
import '../models/map_style.dart';
import '../models/place_autocomplete.dart';
import '../models/place_search.dart';
import '../models/route_calculate.dart';

class MyHomeScreen extends StatefulWidget {
  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen>
    with SingleTickerProviderStateMixin {
  //Controller
  final Completer<GoogleMapController> _mapsController = Completer();
  ScrollController _listviewScrollController = ScrollController();
  DraggableScrollableController _dragableController =
  DraggableScrollableController();
  double? bottomSheetTop;
  String textFieldTopText = "Tìm kiếm";
  String textFieldBottomText = "";

  //Animation
  late AnimationController _animationController;
  late Animation<double> moveAnimation;

  //double currentZoomLevel = 15;

  //GeoLocation
  MapData mapData = MapData();
  bool isHaveLastSessionLocation = false;
  LatLng centerLocation = LatLng(10.7981542, 106.6614047);

  void animateToPosition(LatLng position, {double zoom = 13}) async {
    logWithTag("Animate to position: $position", tag: "MyHomeScreen");
    GoogleMapController controller = await _mapsController.future;
    CameraPosition cameraPosition = CameraPosition(
      target: position,
      zoom: zoom, // Change this value to your desired zoom level
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  void animateToPositionNoZoom(LatLng position) async {
    logWithTag("Animate to position: $position", tag: "MyHomeScreen");
    GoogleMapController controller = await _mapsController.future;
    CameraPosition cameraPosition = CameraPosition(
      target: position,
      zoom: await controller.getZoomLevel(),
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  //Location
  List<PlaceAutocomplete_> placeAutoList = [];
  List<PlaceSearch_> placeSearchList = [];
  late PlaceSearch_ markedPlace;
  bool placeFound = true;
  List<Marker> myMarker = [];
  BitmapDescriptor defaultMarker =
  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  BitmapDescriptor mainMarker =
  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  BitmapDescriptor endLocationMarker =
  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);

  List<BitmapDescriptor> waypointMarkers = [
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    //A
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
    //H
    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    //No letter
  ];

  List<String> waypointMarkersSource = [
    "assets/icons/waypoints/a.svg",
    "assets/icons/waypoints/b.svg",
    "assets/icons/waypoints/c.svg",
    "assets/icons/waypoints/d.svg",
    "assets/icons/waypoints/e.svg",
    "assets/icons/waypoints/f.svg",
    "assets/icons/waypoints/g.svg",
    "assets/icons/waypoints/h.svg",
    "assets/icons/marker_waypoint.svg",
  ];
  Timer? _debounce;
  bool isShowPlaceHorizontalList = false; // show the location search component
  bool isShowPlaceHorizontalListFromSearch =
  true; // true: show from search, false: show from autocomplete

  //Route
  List<Route_> routes = [];

  // Future<List<LatLng>?> polylinePoints = Future.value(null);
  List<Polyline> polylines = [];
  List<LatLng> polylinePointsList = [];
  List<Color> polylineColors = [
    Colors.green[700]!,
    Colors.blue[700]!,
    Colors.yellow[700]!,
    Colors.purple[700]!,
    Colors.orange[700]!,
    Colors.brown[700]!,
    Colors.cyan[700]!,
    Colors.lime[700]!,
    Colors.teal[700]!,
    Colors.indigo[700]!,
  ];
  String travelMode = "DRIVE";
  String routingPreference = "TRAFFIC_AWARE";
  bool isTrafficAware = true;
  bool isComputeAlternativeRoutes = false;
  bool isAvoidTolls = false;
  bool isAvoidHighways = false;
  bool isAvoidFerries = false;
  bool isFullScreen = false;
  List<bool> isChange = [false, false, false, false, false, false];
  bool isCalcRouteFromCurrentLocation = true;
  List<LatLng> waypointsLatLgn = [];
  List<String> waypointNames = [];

  //Test

  static CameraPosition? _initialCameraPosition;
  static const LatLng _airPort = LatLng(10.8114795, 106.6548157);
  static const LatLng _dormitory = LatLng(10.8798036, 106.8052206);

  //State
  static const Map<String, int> stateMap = {
    "Default": 0,
    "Search": 1,
    "Search Results": 2,
    "Route Planning": 3,
    "Navigation": 4,
    "Search Results None": 5,
    "Loading Can Route": 6,
    "Add Waypoint": 7,
    "Loading": 10,
  };
  int state = stateMap["Default"]!;

  String stateFromInt(int stateValue) {
    return stateMap.entries
        .firstWhere((entry) => entry.value == stateValue)
        .key;
  }

  //Map style
  MapType _currentMapType = MapType.normal;
  final List<dynamic> _mapThemes = [
    {
      'name': 'Satellite',
      'style': MapStyle().standard,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=satellite&style=element:labels%7Cvisibility:off&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.neighborhood%7Cvisibility:off&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Hybrid',
      'style': MapStyle().standard,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=satellite&style=element:labels%7Cvisibility:on&style=feature:administrative.land_parcel%7Cvisibility:on&style=feature:administrative.neighborhood%7Cvisibility:off&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Standard',
      'style': MapStyle().standard,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:labels%7Cvisibility:off&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.neighborhood%7Cvisibility:off&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Sliver',
      'style': MapStyle().sliver,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:geometry%7Ccolor:0xf5f5f5&style=element:labels%7Cvisibility:off&style=element:labels.icon%7Cvisibility:off&style=element:labels.text.fill%7Ccolor:0x616161&style=element:labels.text.stroke%7Ccolor:0xf5f5f5&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.land_parcel%7Celement:labels.text.fill%7Ccolor:0xbdbdbd&style=feature:administrative.neighborhood%7Cvisibility:off&style=feature:poi%7Celement:geometry%7Ccolor:0xeeeeee&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0x757575&style=feature:poi.park%7Celement:geometry%7Ccolor:0xe5e5e5&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x9e9e9e&style=feature:road%7Celement:geometry%7Ccolor:0xffffff&style=feature:road.arterial%7Celement:labels.text.fill%7Ccolor:0x757575&style=feature:road.highway%7Celement:geometry%7Ccolor:0xdadada&style=feature:road.highway%7Celement:labels.text.fill%7Ccolor:0x616161&style=feature:road.local%7Celement:labels.text.fill%7Ccolor:0x9e9e9e&style=feature:transit.line%7Celement:geometry%7Ccolor:0xe5e5e5&style=feature:transit.station%7Celement:geometry%7Ccolor:0xeeeeee&style=feature:water%7Celement:geometry%7Ccolor:0xc9c9c9&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x9e9e9e&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Retro',
      'style': MapStyle().retro,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:geometry%7Ccolor:0xebe3cd&style=element:labels%7Cvisibility:off&style=element:labels.text.fill%7Ccolor:0x523735&style=element:labels.text.stroke%7Ccolor:0xf5f1e6&style=feature:administrative%7Celement:geometry.stroke%7Ccolor:0xc9b2a6&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.land_parcel%7Celement:geometry.stroke%7Ccolor:0xdcd2be&style=feature:administrative.land_parcel%7Celement:labels.text.fill%7Ccolor:0xae9e90&style=feature:administrative.neighborhood%7Cvisibility:off&style=feature:landscape.natural%7Celement:geometry%7Ccolor:0xdfd2ae&style=feature:poi%7Celement:geometry%7Ccolor:0xdfd2ae&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0x93817c&style=feature:poi.park%7Celement:geometry.fill%7Ccolor:0xa5b076&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x447530&style=feature:road%7Celement:geometry%7Ccolor:0xf5f1e6&style=feature:road.arterial%7Celement:geometry%7Ccolor:0xfdfcf8&style=feature:road.highway%7Celement:geometry%7Ccolor:0xf8c967&style=feature:road.highway%7Celement:geometry.stroke%7Ccolor:0xe9bc62&style=feature:road.highway.controlled_access%7Celement:geometry%7Ccolor:0xe98d58&style=feature:road.highway.controlled_access%7Celement:geometry.stroke%7Ccolor:0xdb8555&style=feature:road.local%7Celement:labels.text.fill%7Ccolor:0x806b63&style=feature:transit.line%7Celement:geometry%7Ccolor:0xdfd2ae&style=feature:transit.line%7Celement:labels.text.fill%7Ccolor:0x8f7d77&style=feature:transit.line%7Celement:labels.text.stroke%7Ccolor:0xebe3cd&style=feature:transit.station%7Celement:geometry%7Ccolor:0xdfd2ae&style=feature:water%7Celement:geometry.fill%7Ccolor:0xb9d3c2&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x92998d&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Dark',
      'style': MapStyle().dark,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:geometry%7Ccolor:0x212121&style=element:labels%7Cvisibility:off&style=element:labels.icon%7Cvisibility:off&style=element:labels.text.fill%7Ccolor:0x757575&style=element:labels.text.stroke%7Ccolor:0x212121&style=feature:administrative%7Celement:geometry%7Ccolor:0x757575&style=feature:administrative.country%7Celement:labels.text.fill%7Ccolor:0x9e9e9e&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.locality%7Celement:labels.text.fill%7Ccolor:0xbdbdbd&style=feature:administrative.neighborhood%7Cvisibility:off&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0x757575&style=feature:poi.park%7Celement:geometry%7Ccolor:0x181818&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x616161&style=feature:poi.park%7Celement:labels.text.stroke%7Ccolor:0x1b1b1b&style=feature:road%7Celement:geometry.fill%7Ccolor:0x2c2c2c&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x8a8a8a&style=feature:road.arterial%7Celement:geometry%7Ccolor:0x373737&style=feature:road.highway%7Celement:geometry%7Ccolor:0x3c3c3c&style=feature:road.highway.controlled_access%7Celement:geometry%7Ccolor:0x4e4e4e&style=feature:road.local%7Celement:labels.text.fill%7Ccolor:0x616161&style=feature:transit%7Celement:labels.text.fill%7Ccolor:0x757575&style=feature:water%7Celement:geometry%7Ccolor:0x000000&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x3d3d3d&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Night',
      'style': MapStyle().night,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:geometry%7Ccolor:0x242f3e&style=element:labels%7Cvisibility:off&style=element:labels.text.fill%7Ccolor:0x746855&style=element:labels.text.stroke%7Ccolor:0x242f3e&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.locality%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:administrative.neighborhood%7Cvisibility:off&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:poi.park%7Celement:geometry%7Ccolor:0x263c3f&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x6b9a76&style=feature:road%7Celement:geometry%7Ccolor:0x38414e&style=feature:road%7Celement:geometry.stroke%7Ccolor:0x212a37&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x9ca5b3&style=feature:road.highway%7Celement:geometry%7Ccolor:0x746855&style=feature:road.highway%7Celement:geometry.stroke%7Ccolor:0x1f2835&style=feature:road.highway%7Celement:labels.text.fill%7Ccolor:0xf3d19c&style=feature:transit%7Celement:geometry%7Ccolor:0x2f3948&style=feature:transit.station%7Celement:labels.text.fill%7Ccolor:0xd59563&style=feature:water%7Celement:geometry%7Ccolor:0x17263c&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x515c6d&style=feature:water%7Celement:labels.text.stroke%7Ccolor:0x17263c&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    },
    {
      'name': 'Aubergine',
      'style': MapStyle().aubergine,
      'image':
      'https://maps.googleapis.com/maps/api/staticmap?center=-33.9775,151.036&zoom=13&format=png&maptype=roadmap&style=element:geometry%7Ccolor:0x1d2c4d&style=element:labels%7Cvisibility:off&style=element:labels.text.fill%7Ccolor:0x8ec3b9&style=element:labels.text.stroke%7Ccolor:0x1a3646&style=feature:administrative.country%7Celement:geometry.stroke%7Ccolor:0x4b6878&style=feature:administrative.land_parcel%7Cvisibility:off&style=feature:administrative.land_parcel%7Celement:labels.text.fill%7Ccolor:0x64779e&style=feature:administrative.neighborhood%7Cvisibility:off&style=feature:administrative.province%7Celement:geometry.stroke%7Ccolor:0x4b6878&style=feature:landscape.man_made%7Celement:geometry.stroke%7Ccolor:0x334e87&style=feature:landscape.natural%7Celement:geometry%7Ccolor:0x023e58&style=feature:poi%7Celement:geometry%7Ccolor:0x283d6a&style=feature:poi%7Celement:labels.text.fill%7Ccolor:0x6f9ba5&style=feature:poi%7Celement:labels.text.stroke%7Ccolor:0x1d2c4d&style=feature:poi.park%7Celement:geometry.fill%7Ccolor:0x023e58&style=feature:poi.park%7Celement:labels.text.fill%7Ccolor:0x3C7680&style=feature:road%7Celement:geometry%7Ccolor:0x304a7d&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x98a5be&style=feature:road%7Celement:labels.text.stroke%7Ccolor:0x1d2c4d&style=feature:road.highway%7Celement:geometry%7Ccolor:0x2c6675&style=feature:road.highway%7Celement:geometry.stroke%7Ccolor:0x255763&style=feature:road.highway%7Celement:labels.text.fill%7Ccolor:0xb0d5ce&style=feature:road.highway%7Celement:labels.text.stroke%7Ccolor:0x023e58&style=feature:transit%7Celement:labels.text.fill%7Ccolor:0x98a5be&style=feature:transit%7Celement:labels.text.stroke%7Ccolor:0x1d2c4d&style=feature:transit.line%7Celement:geometry.fill%7Ccolor:0x283d6a&style=feature:transit.station%7Celement:geometry%7Ccolor:0x3a4762&style=feature:water%7Celement:geometry%7Ccolor:0x0e1626&style=feature:water%7Celement:labels.text.fill%7Ccolor:0x4e6d70&size=164x132&key=${dotenv.env['MAPS_API_KEY1']}&scale=2'
    }
  ];

  //Search Field
  late TextEditingController _searchFieldControllerTop;
  late TextEditingController _searchFieldControllerBottom;
  late FocusNode _searchFieldFocusNodeTop;
  late FocusNode _searchFieldFocusNodeBottom;

/*
 * This region contains functions.
 */
  // void showPlaceHorizontalList(
  //     {required bool show, String nextState = "Default"}) {
  //     isShowPlaceHorizontalList = show;
  //     show == false
  //         ? changeState(nextState)
  //         : changeState("Search Results");
  // }
  void updateOptionsBasedOnChanges() {
    for (int i = 0; i < isChange.length; i++) {
      if (isChange[i]) {
        switch (i) {
          case 0:
            isTrafficAware = !isTrafficAware;
            break;
          case 1:
            isComputeAlternativeRoutes = !isComputeAlternativeRoutes;
            break;
          case 2:
            isAvoidTolls = !isAvoidTolls;
            break;
          case 3:
            isAvoidHighways = !isAvoidHighways;
            break;
          case 4:
            isAvoidFerries = !isAvoidFerries;
            break;
          case 5:
            isFullScreen = !isFullScreen;
            break;
        }
        // Reset the change flag for this option
        isChange[i] = false;
      }
    }
  }

  void showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tùy chọn đường đi'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    CheckboxListTile(
                      title: const Text('Ảnh hưởng giao thông'),
                      value: isTrafficAware,
                      onChanged: (bool? value) {
                        setState(() {
                          isTrafficAware = value!;
                          isChange[0] = true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tính đường đi thay thế'),
                      value: isComputeAlternativeRoutes,
                      onChanged: (bool? value) {
                        setState(() {
                          isComputeAlternativeRoutes = value!;
                          isChange[1] = true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tránh trạm thu phí'),
                      value: isAvoidTolls,
                      onChanged: (bool? value) {
                        setState(() {
                          isAvoidTolls = value!;
                          isChange[2] = true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tránh đường cao tốc'),
                      value: isAvoidHighways,
                      onChanged: (bool? value) {
                        setState(() {
                          isAvoidHighways = value!;
                          isChange[3] = true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Tránh phà'),
                      value: isAvoidFerries,
                      onChanged: (bool? value) {
                        setState(() {
                          isAvoidFerries = value!;
                          isChange[4] = true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Hiện các điểm rẽ'),
                      value: isFullScreen,
                      onChanged: (bool? value) {
                        setState(() {
                          isFullScreen = value!;
                          isChange[5] = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Hủy bỏ'),
                  onPressed: () {
                    setState(() {
                      updateOptionsBasedOnChanges();
                    });
                    logWithTag(
                        "Options: $isTrafficAware, $isComputeAlternativeRoutes, $isAvoidTolls, $isAvoidHighways, $isAvoidFerries",
                        tag: "SearchLocationScreen");
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Áp dụng'),
                  onPressed: () {
                    if (isFullScreen) {
                      Navigator.of(context).pop();
                      changeState("Navigation");
                      return;
                    }

                    logWithTag(
                        "Options: $isTrafficAware, $isComputeAlternativeRoutes, $isAvoidTolls, $isAvoidHighways, $isAvoidFerries",
                        tag: "SearchLocationScreen");
                    calcRoute(
                        from: mapData.departureLocation!,
                        to: mapData.destinationLocationLatLgn!);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void changeState(String stateString) {
    if (!stateMap.containsKey(stateString)) {
      throw Exception('Invalid state: $stateString');
    }

    if (stateString != "Navigation") {
      isFullScreen = false;
      deleteEndLocationsFromMarkers();
    } else
      addEndLocationsToMarkers();
    if (stateString == "Default") {
      isShowPlaceHorizontalList = false;
      polylines.clear();
      travelMode = "DRIVE";
      mapData.departureLocation = mapData.currentLocation;
      mapData.departureLocationName = "Vị trí hiện tại";
    }

    if (stateString == "Search Results") {
      isShowPlaceHorizontalList = true;
      polylines.clear();
      travelMode = "TWO_WHEELER";
      //Todo remove after test waypoint
      //waypointsLatLgn = [];
    } else {
      isShowPlaceHorizontalList = false;
    }

    if (stateString == "Route Planning") {
      drawRoute();
    } else if (stateString == "Add Waypoint") {}

    setState(() {
      state = stateMap[stateString]!;
    });
  }

  void searchPlaceAndUpdate(String text) {
    if (text.isEmpty) {
      placeFound = true;
      placeSearchList.clear();
      setState(() {});
    } else {
      myMarker = [];
      logWithTag("Place search: $text", tag: "SearchLocationScreen");
      placeSearch(text).then((searchList) => setState(() {
        if (searchList != null) {
          placeSearchList = searchList;
          for (int i = 0; i < placeSearchList.length; i++) {
            if (placeSearchList[i].id != null) {
              PlaceSearch_.getPhotoUrls(placeSearchList[i].id!, 500, 500)
                  .then((photoUrls) {
                setState(() {
                  placeSearchList[i].photoUrls = photoUrls;
                  logWithTag("Photo URL: ${photoUrls}",
                      tag: "Change photourl");
                });
              });
            }
            ;
            final markerId = MarkerId(placeSearchList[i].id!);
            Marker marker = Marker(
              markerId: markerId,
              icon: (i == 0) ? mainMarker : defaultMarker,
              position: LatLng(placeSearchList[i].location.latitude,
                  placeSearchList[i].location.longitude),
              // infoWindow: InfoWindow(
              //   title: placeSearchList[i].displayName?.text,
              //   snippet: placeSearchList[i].formattedAddress,
              // ),
            );
            myMarker.add(marker);
          }
          placeFound = true;
          placeOnclickFromList(
              isShowPlaceHorizontalListFromSearch: true, index: 0);

          animateBottomSheet(
              _dragableController, defaultBottomSheetHeight / 1000)
              .then((_) {
            setState(() {
              bottomSheetTop = _dragableController.pixels;
              changeState("Search Results");
            });
          });
        } else {
          placeFound = false;
        }
      }));
    }
  }

  void autocompletePlaceAndUpdate(String text) {
    if (text.isEmpty) {
      setState(() {
        placeFound = true;
        placeAutoList.clear();
      });
    } else {
      logWithTag("Place auto complete: $text", tag: "SearchLocationScreen");
      setState(() {
        placeAutocomplete(text, mapData.currentLocation, 500)
            .then((autoList) => setState(() {
          if (autoList != null) {
            placeAutoList = autoList;
            placeFound = true;
            changeState("Search Results");
          } else {
            placeFound = false;
          }
        }));
      });
    }
  }

  void locationButtonOnclick() {
    if (mapData.currentLocation != null) {
      animateToPosition(mapData.currentLocation!);
    }
    getCurrentLocation().then((value) {
      if (mapData.currentLocation != LatLng(value.latitude, value.longitude)) {
        mapData.currentLocation = LatLng(value.latitude, value.longitude);
        animateToPosition(mapData.currentLocation!);
        logWithTag("Location changed!", tag: "MyHomeScreen");
      }
    });
  }

  String getMainText(bool isShowFromSearch, int index) {
    if (isShowFromSearch) {
      return placeSearchList[index].displayName?.text ?? "";
    } else {
      return placeAutoList[index].structuredFormat?.mainText?.text ?? "";
    }
  }

  String getSecondaryText(bool isShowFromSearch, int index) {
    if (isShowFromSearch) {
      return placeSearchList[index].formattedAddress ?? "";
    } else {
      return placeAutoList[index].structuredFormat?.secondaryText?.text ?? "";
    }
  }

  Future<void> placeClickLatLngFromMap(LatLng position) async {
    animateToPositionNoZoom(
      LatLng(position.latitude, position.longitude),
    );
    isShowPlaceHorizontalList = false;
    changeState("Loading Can Route");
    mapData.changeDestinationLocationLatLgn(position);
    setState(() {
      myMarker = [];
      waypointsLatLgn = [];
      waypointNames = [];
      final markerId = MarkerId("0");
      Marker marker = Marker(
        markerId: markerId,
        icon: mainMarker,
        position: LatLng(position.latitude, position.longitude),
      );
      myMarker.add(marker);
    });
    try {
      String placeString = await convertLatLngToAddress(position);
      var value = await placeSearchSingle(placeString);
      if (value != null) {
        PlaceSearch_.getPhotoUrls(value.id!, 400, 400).then((photoUrls) {
          value.photoUrls = photoUrls;
          setState(() {
            mapData.changeDestinationImage(photoUrls);
          });
        });
        markedPlace = value;
        mapData.changeDestinationAddressAndPlaceNameAndImage(value);
        if (state == stateMap["Loading Can Route"]!)
          changeState("Search Results");
      } else if (state == stateMap["Loading Can Route"]!)
        changeState("Search Results None");
    } catch (e) {
      logWithTag("Error, place click from map: $e",
          tag: "SearchLocationScreen");
    }
  }

  Future<LatLng?> placeOnclickFromList(
      {required bool isShowPlaceHorizontalListFromSearch,
        required int index}) async {
    this.isShowPlaceHorizontalListFromSearch =
        isShowPlaceHorizontalListFromSearch;
    changeState("Search Results");
    if (isShowPlaceHorizontalListFromSearch) {
      try {
        mapData.changeDestinationLocationLatLgn(LatLng(
            placeSearchList[index].location.latitude,
            placeSearchList[index].location.longitude));
        mapData.changeDestinationAddressAndPlaceNameAndImage(
            placeSearchList[index]);
        animateToPosition(
            LatLng(placeSearchList[index].location.latitude,
                placeSearchList[index].location.longitude),
            zoom: 15);

        markedPlace = placeSearchList[index];
        return LatLng(placeSearchList[index].location.latitude,
            placeSearchList[index].location.longitude);
      } catch (e) {
        logWithTag(
            "Error, show from auto but the isShowFromSearch = true, changing it to false $e",
            tag: "SearchLocationScreen");
        isShowPlaceHorizontalListFromSearch = false;
      }
    }
    // If the isShowFromSearch is true, but the index is out of range, then it will change to false and execute this
    // Make sure that the isShowFromSearch is always have the right value

    var value = await placeSearchSingle(
        placeAutoList[index].structuredFormat?.mainText?.text ?? "");
    if (value != null) {
      mapData.changeDestinationLocationLatLgn(
          LatLng(value.location.latitude, value.location.longitude));
      mapData.changeDestinationAddressAndPlaceNameAndImage(value);
      animateToPosition(
        LatLng(value.location.latitude, value.location.longitude),
      );
      setState(() {
        myMarker = [];
        final markerId = MarkerId(value.id!);
        Marker marker = Marker(
          markerId: markerId,
          icon: mainMarker,
          position: LatLng(value.location.latitude, value.location.longitude),
          // infoWindow: InfoWindow(
          //   title: value.displayName?.text,
          //   snippet: value.formattedAddress,
          // ),
        );
        myMarker.add(marker);
      });
      markedPlace = value;
      return LatLng(value.location.latitude, value.location.longitude);
    }
    return null;
  }

  void drawRoute() {
    if (routes.isNotEmpty) {
      setState(() {
        polylines = [];
        for (int i = 0; i < routes[0].legs.length; i++) {
          List<LatLng> legPoints = Polyline_.decodePolyline(
              routes[0].legs[i].polyline.encodedPolyline);

          int width;
          switch (i % 3) {
            case 0:
              width = 8;
              break;
            case 1:
              width = 6;
              break;
            case 2:
              width = 4;
              break;
            default:
              width = 8;
          }

          polylines.add(
            Polyline(
              polylineId: PolylineId(i.toString()),
              color: polylineColors[i % polylineColors.length],
              // Use a different color for each leg
              width: width,
              // Use different widths for each polyline
              points: legPoints, // Add all points of the leg to the polyline
            ),
          );
        }
      });
    }
    //showAllMarkerInfo();
  }

  // Future<void> showAllMarkerInfo() async {
  //   GoogleMapController controller = await _mapsController.future;
  //   for (final marker in myMarker) {
  //     controller.showMarkerInfoWindow(marker.markerId);
  //   }
  // }

  void clearRoute() {
    setState(() {
      polylines.clear();
    });
  }

  Future<void> calcRouteFromDepToDes() async {
    //Todo remove after test waypoint
    //waypointsLatLgn = [];
    if (mapData.departureLocation != null &&
        mapData.destinationLocationLatLgn != null) {
      List<Marker> tempList = List<Marker>.from(myMarker);

      setState(() {
        for (Marker marker in tempList) {
          if (marker.icon == mainMarker) {
            myMarker.removeAt(tempList.indexOf(marker));
          }
        }

        Marker marker = Marker(
          markerId: MarkerId("0"),
          icon: mainMarker,
          position: mapData.destinationLocationLatLgn!,
        );
        myMarker.add(marker);
      });
      calcRoute(
          from: mapData.departureLocation!,
          to: mapData.destinationLocationLatLgn!);
      _searchFieldControllerTop.text = mapData.departureLocationName;
      _searchFieldControllerBottom.text = mapData.destinationLocationPlaceName;
    }
  }

  Future<void> calcRoute({required LatLng from, required LatLng to}) async {
    changeState("Loading");
    if (isTrafficAware) routingPreference = "TRAFFIC_AWARE";
    routes = (await computeRoutesReturnRoute_(
        from: from,
        to: to,
        travelMode: travelMode,
        routingPreference: routingPreference,
        computeAlternativeRoutes: isComputeAlternativeRoutes,
        avoidTolls: isAvoidTolls,
        avoidHighways: isAvoidHighways,
        avoidFerries: isAvoidFerries,
        waypoints: waypointsLatLgn))!;
    updateEndLocationAddress();
    drawRoute();
    changeState("Route Planning");
    mapData.changeDepartureLocation(from);
    mapData.changeDestinationLocationLatLgn(to);
    // Todo: mapdata
  }

  Future<void> updateEndLocationAddress() async {
    if (routes.isEmpty) return;
    if (routes[0].legs[0].steps == null) return;
    for (Step_ step in routes[0].legs[0].steps!) {
      if (step.endLocationAddress == null) {
        String placeString =
        await convertLatLngToAddress(step.endLocation.latLng);
        step.endLocationAddress = placeString;
      }
    }
  }

  void addEndLocationsToMarkers() {
    logWithTag("addEndLocationsToMarkers", tag: "MyHomeScreen");
    setState(() {
      if (routes.isEmpty) return;
      for (Step_ step in routes[0].legs[0].steps!) {
        final markerId = MarkerId("End: ${step.endLocation.latLng}");
        Marker marker = Marker(
          markerId: markerId,
          icon: endLocationMarker,
          position: step.endLocation.latLng,
          infoWindow: InfoWindow(
            title: step.endLocationAddress,
          ),
        );
        myMarker.add(marker);
      }
    });
  }

  void deleteEndLocationsFromMarkers() {
    for (int i = 0; i < myMarker.length; i++) {
      Marker marker = myMarker[i];
      if (marker.icon == endLocationMarker) {
        myMarker.removeAt(i);
      }
    }
  }

  Future<void> placeMarkAndRoute(
      {required bool isShowPlaceHorizontalListFromSearch,
        required int index}) async {
    changeState("Loading");
    this.isShowPlaceHorizontalListFromSearch =
        isShowPlaceHorizontalListFromSearch;
    myMarker.removeWhere((marker) => marker.icon != mainMarker);
    if (isShowPlaceHorizontalListFromSearch) {
      mapData.destinationLocationLatLgn = LatLng(
          placeSearchList[index].location.latitude,
          placeSearchList[index].location.longitude);
      try {
        markedPlace = placeSearchList[index];
        calcRoute(
            from: mapData.currentLocation!,
            to: LatLng(placeSearchList[index].location.latitude,
                placeSearchList[index].location.longitude));
        return;
      } catch (e) {
        logWithTag(
            "Error, show from auto but the isShowFromSearch = true, changing it to false $e",
            tag: "SearchLocationScreen");
        isShowPlaceHorizontalListFromSearch = false;
      }
    }
    // If the isShowFromSearch is true, but the index is out of range, then it will change to false and execute this
    // Make sure that the isShowFromSearch is always have the right value
    var value = await placeSearchSingle(
        placeAutoList[index].structuredFormat?.mainText?.text ?? "");
    if (value != null) {
      setState(() {
        myMarker = [];
        final markerId = MarkerId(value.id!);
        Marker marker = Marker(
          markerId: markerId,
          icon: mainMarker,
          position: LatLng(value.location.latitude, value.location.longitude),
          // infoWindow: InfoWindow(
          //   title: value.displayName?.text,
          //   snippet: value.formattedAddress,
          // ),
        );
        myMarker.add(marker);
      });
      markedPlace = value;
      calcRoute(
          from: mapData.currentLocation!,
          to: LatLng(value.location.latitude, value.location.longitude));
      return;
    }
    logWithTag("Error, route not found", tag: "SearchLocationScreen");
    changeState("Search Results");
    return;
  }

  void changeMainMarker(int index) {
    for (int i = 0; i < myMarker.length; i++) {
      Marker marker = myMarker[i];
      if (marker.icon == mainMarker) {
        Marker newMarker = Marker(
          markerId: marker.markerId,
          icon: defaultMarker,
          position: marker.position,
          //infoWindow: marker.infoWindow,
        );
        myMarker[i] = newMarker;
      }
    }

    Marker markerAtIndex = myMarker[index];
    Marker newMarkerAtIndex = Marker(
      markerId: markerAtIndex.markerId,
      icon: mainMarker,
      position: markerAtIndex.position,
      //infoWindow: markerAtIndex.infoWindow,
    );
    setState(() {
      myMarker[index] = newMarkerAtIndex;
    });
  }

/*
 * End of functions
 */

  @override
  void initState() {
    super.initState();

    _searchFieldControllerBottom = TextEditingController();
    _searchFieldControllerTop = TextEditingController();
    _searchFieldFocusNodeTop = FocusNode();
    _searchFieldFocusNodeBottom = FocusNode();

    getCurrentLocationLatLng().then((value) {
      mapData.changeCurrentLocation(value);
      mapData.changeDepartureLocation(value);
      if (!isHaveLastSessionLocation) {
        animateToPosition(mapData.currentLocation!);
      }
    });

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    moveAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
        "assets/icons/marker_small.svg", const Size(40, 40))
        .then((bitmapDescriptor) {
      setState(() {
        defaultMarker = bitmapDescriptor;
      });
    });

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
        "assets/icons/marker_big.svg", const Size(50, 50))
        .then((bitmapDescriptor) {
      setState(() {
        mainMarker = bitmapDescriptor;
      });
    });

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
        "assets/icons/end_location.svg", const Size(40, 40))
        .then((bitmapDescriptor) {
      setState(() {
        endLocationMarker = bitmapDescriptor;
      });
    });

    for (int i = 0; i < waypointMarkers.length; i++) {
      BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
          waypointMarkersSource[i], const Size(45, 45))
          .then((bitmapDescriptor) {
        setState(() {
          waypointMarkers[i] = bitmapDescriptor;
        });
      });
    }

    //Todo: Remove after test
    // searchPlaceAndUpdate("Đại học CNTT");
    // placeMarkAndRoute(isShowPlaceHorizontalListFromSearch: true, index: 0)
    //     .then((value) => {
    //           //changeState("Navigation")
    //         });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchFieldControllerTop.dispose();
    _searchFieldControllerBottom.dispose();
    _searchFieldFocusNodeTop.dispose();
    _searchFieldFocusNodeBottom.dispose();
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger rebuild of the map
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Transparent status bar
      statusBarIconBrightness: Brightness.dark,
      // Dark icons
      systemNavigationBarColor: Colors.transparent,
      // Transparent navigation bar
      systemNavigationBarIconBrightness: Brightness.dark, // Dark icons
    ));
    //return LocationSharing();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Maps
          GoogleMap(
            initialCameraPosition: (isHaveLastSessionLocation ==
                true) // get last location from shared preference, if not exist, use default location, then it will automatically move to current location
                ? const CameraPosition(
              target: LatLng(20, 106),
              zoom: 13,
            ) // Todo: last location
                : const CameraPosition(
              target: LatLng(10.7981542, 106.6614047),
              zoom: 13,
            ),
            //Default location
            mapType: _currentMapType,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: myMarker.toSet(),
            onTap: (LatLng position) {
              if (state != stateMap["Route Planning"])
                placeClickLatLngFromMap(position);
            },
            onLongPress: (LatLng position) {
              placeClickLatLngFromMap(position);
            },
            onMapCreated: (GoogleMapController controller) {
              _mapsController.complete(controller);
            },
            onCameraMove: (CameraPosition position) {
              centerLocation = position.target;
            },
            polylines: polylines.toSet(),
            zoomControlsEnabled: false,
          ),

          // Horizontal list and location button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.fastOutSlowIn,
            bottom:
            // use this to compensate the height of the location show panel when it showed,
            // do not need to use this of use visibility widget, but that widget does not have animation
            ((bottomSheetTop == null)
                ? (MediaQuery.of(context).size.height *
                defaultBottomSheetHeight /
                1000) +
                10
                : bottomSheetTop! + 10),
            // 90 is the height of the location show panel

            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 10.0),
                  child: FloatingActionButton(
                    elevation: 5,
                    backgroundColor: Colors.white,
                    heroTag: "mapStyle",
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                            padding: EdgeInsets.all(20),
                            color: Colors.white,
                            height: MediaQuery.of(context).size.height * 0.3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Chọn chủ đề",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18),
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 100,
                                  child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _mapThemes.length,
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onTap: () async {
                                            GoogleMapController controller = await _mapsController.future;
                                            if (index == 0) {
                                              _currentMapType = MapType.satellite;
                                            } else if (index == 1) {
                                              _currentMapType = MapType.hybrid;
                                            }
                                            else
                                              _currentMapType = MapType.normal;

                                            controller.setMapStyle(
                                                _mapThemes[index]['style']);
                                            setState(() {
                                            });
                                            Navigator.pop(context);
                                          },
                                          child: Container(
                                              width: 100,
                                              margin: EdgeInsets.only(right: 10),
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                  image: DecorationImage(
                                                    fit: BoxFit.cover,
                                                    image: NetworkImage(
                                                        _mapThemes[index]['image']),
                                                  )),
                                              child: Center(
                                                child: Stack(
                                                  children: [


                                                    Text(
                                                      _mapThemes[index]['name'],
                                                      style: TextStyle(
                                                          foreground: Paint()
                                                            ..style = PaintingStyle.stroke
                                                            ..strokeWidth = 2
                                                            ..color = Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 18),
                                                    ),
                                                    Text(
                                                      _mapThemes[index]['name'],
                                                      style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 18),
                                                    ),

                                                  ],
                                                ),
                                              )
                                          ),
                                        );
                                      }),
                                ),
                              ],
                            )),
                      );
                    },
                    child: Icon(Icons.layers_rounded, size: 25),
                  ),
                ),

                SizedBox(height: 10),
                // Location button
                Container(
                  margin: const EdgeInsets.only(right: 10.0),
                  child: FloatingActionButton(
                    heroTag: "Location",
                    backgroundColor: Colors.white,
                    elevation: 5,
                    onPressed: () {
                      //setState(() {});
                      //addEndLocationsToMarkers();
                      locationButtonOnclick();
                    },
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.black,
                    ),
                  ),
                ),

                // Location list
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  child:
                  //List from place autocomplete
                  Visibility(
                      visible: isShowPlaceHorizontalList,
                      child: SizedBox(
                        height: 90.0,
                        width: (MediaQuery.of(context).size.width),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: isShowPlaceHorizontalListFromSearch
                              ? placeSearchList.length
                              : placeAutoList.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(
                                  left: 5.0, right: 5),
                              child: GestureDetector(
                                onTap: () {
                                  placeOnclickFromList(
                                      isShowPlaceHorizontalListFromSearch:
                                      isShowPlaceHorizontalListFromSearch,
                                      index: index);

                                  if (myMarker.length > 1) {
                                    changeMainMarker(index);
                                  }
                                },
                                onLongPress: () async {
                                  await placeMarkAndRoute(
                                      isShowPlaceHorizontalListFromSearch:
                                      isShowPlaceHorizontalListFromSearch,
                                      index: index);
                                  drawRoute();
                                },
                                child: Container(
                                  //margin: EdgeInsets.only(
                                  // left: 10.0, top: 10.0, bottom: 10.0),
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(10.0),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: <Widget>[
                                      if (isShowPlaceHorizontalListFromSearch)
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(5.0),
                                          child: (placeSearchList[index]
                                              .photoUrls !=
                                              null)
                                              ? Image.network(
                                            placeSearchList[index]
                                                .photoUrls!,
                                            width: 60,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          )
                                              : SvgPicture.asset(
                                            "assets/icons/marker_big.svg",
                                            width: 60,
                                            height: 80,
                                            fit: BoxFit.scaleDown,
                                          ),
                                        ),
                                      const SizedBox(width: 10.0),
                                      SizedBox(
                                        width: 140,
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              getMainText(
                                                  isShowPlaceHorizontalListFromSearch,
                                                  index),
                                              style: const TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                                overflow:
                                                TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              getSecondaryText(
                                                  isShowPlaceHorizontalListFromSearch,
                                                  index),
                                              style: const TextStyle(
                                                  fontSize: 14.0,
                                                  color: Colors.grey,
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )),
                ),
              ],
            ),
          ),
          // Center image to add waypoint
          Visibility(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 27.0, right: 14.0),
                  child: SizedBox(
                      width: 35,
                      height: 35,
                      child: SvgPicture.asset("assets/icons/waypoint.svg")),
                ),
              ),
              visible: state == stateMap["Add Waypoint"]),

          // On top search bar
          Positioned(
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                color: state == stateMap["Route Planning"]!
                    ? Colors.white
                    : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20.0),
                  bottomRight: Radius.circular(20.0),
                ),
              ),
              child: Visibility(
                //Top search bar - Departure
                  visible: state != stateMap["Add Waypoint"],
                  //state == stateMap["Search"]!,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 50.0,
                      ),
                      Column(
                        children: [
                          Row(children: [
                            IconButton(
                                onPressed: () {
                                  String currentState = stateFromInt(state);

                                  switch (currentState) {
                                    case "Search Results":
                                    case "Search Results None":
                                      changeState("Default");
                                      break;
                                    case "Route Planning":
                                    case "Loading Can Route":
                                      changeState("Search Results");
                                      break;
                                    case "Navigation":
                                      changeState("Route Planning");
                                      break;
                                    case "Loading":
                                      changeState("Search Results");
                                      break;
                                    default:
                                      changeState("Default");
                                      break;
                                  }
                                },
                                icon: const Icon(Icons.arrow_back)),
                            Container(
                              //Text input
                              margin: const EdgeInsets.only(left: 10.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 5,
                                    blurRadius: 7,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              width: MediaQuery.of(context).size.width - 120,
                              height: 45.0,
                              child: TextField(
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: SvgPicture.asset(
                                      "assets/icons/search.svg"),

                                  suffixIcon: _searchFieldFocusNodeTop.hasFocus
                                      ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchFieldControllerTop.clear();
                                      setState(() {
                                        placeAutoList.clear();
                                        placeFound = true;
                                      });
                                    },
                                  )
                                      : IconButton(
                                      onPressed: () {},
                                      icon: SvgPicture.asset(
                                          "assets/icons/nearby_search.svg")), // End icon
                                ),
                                controller: _searchFieldControllerTop,
                                focusNode: _searchFieldFocusNodeTop,
                                onSubmitted: (text) {
                                  if (state == stateMap["Route Planning"]!) {
                                    changeState("Loading");
                                    placeSearch(text).then((value) {
                                      if (value != null) {
                                        mapData.changeDepartureLocation(LatLng(
                                            value[0].location.latitude,
                                            value[0].location.longitude));
                                        calcRouteFromDepToDes();
                                        _searchFieldControllerTop.text =
                                            value[0].displayName?.text ?? "";
                                      }
                                    });
                                  } else
                                    searchPlaceAndUpdate(text);
                                  _searchFieldFocusNodeTop.unfocus();
                                },
                                onChanged: (text) {
                                  if (state == stateMap["Route Planning"]!)
                                    return;

                                  if (text.isEmpty) {
                                    placeFound = true;
                                    placeAutoList.clear();
                                    setState(() {});
                                  }
                                  autocompletePlaceAndUpdate(text);
                                },
                              ),
                            ),
                            (state == stateMap["Default"]!)
                                ? Container(
                              // Profile picture
                              margin: const EdgeInsets.only(left: 10.0),
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: IconButton(
                                  padding: const EdgeInsets.all(2),
                                  onPressed: () {},
                                  icon: Image.asset(
                                    "assets/profile.png",
                                  )),
                            )
                                : Container(
                              // Profile picture
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  showOptionsDialog(context);
                                },
                              ),
                            ),
                          ]),
                          Visibility(
                            //Bottom search bar - Destination
                            visible: state == stateMap["Route Planning"]!,
                            child: Container(
                              width: MediaQuery.of(context).size.width,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width:
                                        MediaQuery.of(context).size.width -
                                            120,
                                        height: 45,
                                        margin: const EdgeInsets.only(
                                            top: 10.0, right: 10.0, left: 65),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(8.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                              Colors.grey.withOpacity(0.5),
                                              spreadRadius: 5,
                                              blurRadius: 7,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller:
                                          _searchFieldControllerBottom,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            prefixIcon: SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: SvgPicture.asset(
                                                  "assets/icons/verified_destination.svg"),
                                            ),
                                          ),
                                          onSubmitted: (text) {
                                            changeState("Loading");
                                            placeSearch(text).then((value) {
                                              if (value != null) {
                                                mapData
                                                    .changeDestinationLocationLatLgn(
                                                    LatLng(
                                                        value[0]
                                                            .location
                                                            .latitude,
                                                        value[0]
                                                            .location
                                                            .longitude));
                                                calcRouteFromDepToDes();
                                                _searchFieldControllerBottom
                                                    .text = value[0]
                                                    .displayName
                                                    ?.text ??
                                                    "";
                                              }
                                            });
                                            _searchFieldFocusNodeBottom
                                                .unfocus();
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: IconButton(
                                              onPressed: () {},
                                              icon: SvgPicture.asset(
                                                  "assets/icons/swap.svg"))),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                            onPressed: () {
                                              travelMode = "WALK";
                                              calcRouteFromDepToDes();
                                            },
                                            icon: SvgPicture.asset(
                                                "assets/icons/walk.svg")),
                                        const SizedBox(width: 10),
                                        IconButton(
                                            onPressed: () {
                                              travelMode = "DRIVE";
                                              calcRouteFromDepToDes();
                                            },
                                            icon: SvgPicture.asset(
                                                "assets/icons/car.svg")),
                                        const SizedBox(width: 10),
                                        IconButton(
                                            onPressed: () {
                                              travelMode = "TWO_WHEELER";
                                              calcRouteFromDepToDes();
                                            },
                                            icon: SvgPicture.asset(
                                                "assets/icons/motor.svg")),
                                        const SizedBox(width: 10),
                                        IconButton(
                                            onPressed: () {
                                              travelMode = "TRANSIT";
                                              calcRouteFromDepToDes();
                                            },
                                            icon: SvgPicture.asset(
                                                "assets/icons/public_transport.svg")),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: (placeAutoList.isNotEmpty &&
                            _searchFieldFocusNodeTop.hasFocus)
                            ? Container(
                          //Autocomplete list
                          margin: const EdgeInsets.only(top: 30.0),
                          alignment: Alignment.center,
                          width: MediaQuery.of(context).size.width - 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: placeAutoList.length,
                            itemBuilder: (context, index) {
                              return LocationListTile_(
                                press: () async {
                                  _searchFieldFocusNodeTop.unfocus();
                                  logWithTag(
                                      "Location clicked: ${placeAutoList[index].toString()}",
                                      tag: "SearchLocationScreen");
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                  await Future.delayed(const Duration(
                                      milliseconds:
                                      500)); // wait for the keyboard to show up to make the bottom sheet move up smoothly
                                  animateBottomSheet(_dragableController,
                                      defaultBottomSheetHeight / 1000)
                                      .then((_) {
                                    setState(() {
                                      bottomSheetTop =
                                          _dragableController.pixels;
                                    });
                                  });
                                  placeOnclickFromList(
                                      isShowPlaceHorizontalListFromSearch:
                                      false,
                                      index: index);
                                },
                                placeName: placeAutoList[index]
                                    .structuredFormat
                                    ?.mainText
                                    ?.text ??
                                    "",
                                location: placeAutoList[index]
                                    .structuredFormat
                                    ?.secondaryText
                                    ?.text ??
                                    "",
                              );
                            },
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  )),
            ),
          ),

          // Bottom sheet
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              setState(() {
                bottomSheetTop = _dragableController.pixels;
              });
              return true;
            },
            child: state == stateMap["Default"]!
                ?
            // Bottom sheet default
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize: defaultBottomSheetHeight / 1000,
              minChildSize: 0.15,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      primary: false,
                      controller: scrollController,
                      child: Column(children: <Widget>[
                        const Pill(),
                        // Column(
                        //   children: [
                        //     Row(
                        //       mainAxisAlignment:
                        //           MainAxisAlignment.center,
                        //       crossAxisAlignment:
                        //           CrossAxisAlignment.center,
                        //       children: [
                        //         Expanded(
                        //           child: Padding(
                        //             padding: const EdgeInsets.only(
                        //                 left: defaultPadding,
                        //                 right: 0,
                        //                 top: defaultPadding,
                        //                 bottom: 8.0),
                        //             child: CupertinoSearchTextField(
                        //               style: leagueSpartanNormal20,
                        //               placeholder: "Tìm địa điểm",
                        //               onChanged: (text) {
                        //                 if (_debounce?.isActive ??
                        //                     false) {
                        //                   _debounce?.cancel();
                        //                 }
                        //                 _debounce = Timer(
                        //                     const Duration(
                        //                         milliseconds: 200), () {
                        //                   autocompletePlaceAndUpdate(
                        //                       text);
                        //                 });
                        //               },
                        //               onSubmitted: (text) {
                        //                 searchPlaceAndUpdate(text);
                        //               },
                        //               onTap: () async {
                        //                 logWithTag(
                        //                     "Search bar clicked: ",
                        //                     tag:
                        //                         "SearchLocationScreen");
                        //                 isShowPlaceHorizontalList =
                        //                     false;
                        //                 await Future.delayed(const Duration(
                        //                     milliseconds:
                        //                         500)); // wait for the keyboard to show up to make the bottom sheet move up smoothly
                        //                 animateBottomSheet(
                        //                         _dragableController,
                        //                         0.8)
                        //                     .then((_) {
                        //                   setState(() {
                        //                     bottomSheetTop =
                        //                         _dragableController
                        //                             .pixels;
                        //                   });
                        //                 });
                        //               },
                        //             ),
                        //           ),
                        //         ),
                        //         IconButton(
                        //             onPressed: () {},
                        //             icon: SvgPicture.asset(
                        //                 "assets/icons/nearby_search.svg")),
                        //       ],
                        //     ),
                        //     Row(
                        //       children: <Widget>[
                        //         Container(
                        //           padding: const EdgeInsets.only(
                        //               left: defaultPadding, right: 8),
                        //           child: ElevatedButton.icon(
                        //             onPressed: () {
                        //               logWithTag(
                        //                   "Add home button clicked: ",
                        //                   tag: "SearchLocationScreen");
                        //             },
                        //             icon: SvgPicture.asset(
                        //               "assets/icons/home_add.svg",
                        //               height: 16,
                        //             ),
                        //             label: Text("Thêm nhà",
                        //                 style: leagueSpartanNormal15),
                        //             style: ElevatedButton.styleFrom(
                        //               backgroundColor:
                        //                   secondaryColor10LightTheme,
                        //               foregroundColor:
                        //                   textColorLightTheme,
                        //               elevation: 0,
                        //               fixedSize: const Size(
                        //                   double.infinity, 40),
                        //               shape:
                        //                   const RoundedRectangleBorder(
                        //                 borderRadius: BorderRadius.all(
                        //                     Radius.circular(20)),
                        //               ),
                        //             ),
                        //           ),
                        //         ),
                        //         ElevatedButton.icon(
                        //           onPressed: () {
                        //             logWithTag("Button clicked: ",
                        //                 tag: "SearchLocationScreen");
                        //           },
                        //           icon: SvgPicture.asset(
                        //             "assets/icons/location_add.svg",
                        //             height: 16,
                        //           ),
                        //           label: Text("Thêm địa điểm",
                        //               style: leagueSpartanNormal15),
                        //           style: ElevatedButton.styleFrom(
                        //             backgroundColor:
                        //                 secondaryColor10LightTheme,
                        //             foregroundColor:
                        //                 textColorLightTheme,
                        //             elevation: 0,
                        //             fixedSize:
                        //                 const Size(double.infinity, 40),
                        //             shape: const RoundedRectangleBorder(
                        //               borderRadius: BorderRadius.all(
                        //                   Radius.circular(20)),
                        //             ),
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //
                        //     Visibility(
                        //       visible: placeFound,
                        //       child: ListView.builder(
                        //         controller: _listviewScrollController,
                        //         shrinkWrap: true,
                        //         itemCount: placeAutoList.length,
                        //         itemBuilder: (context, index) {
                        //           return LocationListTile_(
                        //             press: () async {
                        //               logWithTag(
                        //                   "Location clicked: ${placeAutoList[index].toString()}",
                        //                   tag: "SearchLocationScreen");
                        //
                        //               SystemChannels.textInput
                        //                   .invokeMethod(
                        //                       'TextInput.hide');
                        //               await Future.delayed(const Duration(
                        //                   milliseconds:
                        //                       500)); // wait for the keyboard to show up to make the bottom sheet move up smoothly
                        //               animateBottomSheet(
                        //                       _dragableController,
                        //                       defaultBottomSheetHeight /
                        //                           1000)
                        //                   .then((_) {
                        //                 setState(() {
                        //                   bottomSheetTop =
                        //                       _dragableController
                        //                           .pixels;
                        //                 });
                        //               });
                        //               placeOnclick(
                        //                   isShowPlaceHorizontalListFromSearch: false,
                        //                   index: index);
                        //             },
                        //             placeName: placeAutoList[index]
                        //                     .structuredFormat
                        //                     ?.mainText
                        //                     ?.text ??
                        //                 "",
                        //             location: placeAutoList[index]
                        //                     .structuredFormat
                        //                     ?.secondaryText
                        //                     ?.text ??
                        //                 "",
                        //           );
                        //         },
                        //       ),
                        //     ),
                        //     Visibility(
                        //       visible: !placeFound,
                        //       child: const Center(
                        //           child:
                        //               Text('Không tìm thấy địa điểm')),
                        //     ),
                        //     //MockList_()
                        //   ],
                        // ),
                        BottomSheetComponient_(
                          controller: _listviewScrollController,
                          shareLocationPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      LocationSharing()),
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                );
              },
            )
                : (state == stateMap["Search Results"]!)
                ?
            // Bottom sheet search results
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize: defaultBottomSheetHeight / 1000,
              minChildSize: 0.05,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      primary: false,
                      controller: scrollController,
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 20.0, right: 20.0),
                        child: Column(children: <Widget>[
                          const Pill(),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                BorderRadius.circular(5.0),
                                child:
                                (mapData.destinationLocationPhotoUrl !=
                                    "")
                                    ? Image.network(
                                  mapData
                                      .destinationLocationPhotoUrl!,
                                  width: 80,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                                    : SvgPicture.asset(
                                  "assets/icons/marker_big.svg",
                                  width: 80,
                                  height: 100,
                                  fit: BoxFit.scaleDown,
                                ),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mapData
                                          .destinationLocationPlaceName
                                          .toString(),
                                      style: const TextStyle(
                                        fontFamily: "SF Pro Display",
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.visible,
                                    ),
                                    Text(
                                      mapData
                                          .destinationLocationAddress
                                          .toString(),
                                      style: const TextStyle(
                                        fontFamily: "SF Pro Display",
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.visible,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              IconButton(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(
                                        text:
                                        "https://maps.app.goo.gl/" +
                                            mapData
                                                .destinationID));
                                  },
                                  icon: Icon(Icons.share_rounded)),
                              FilledButton(
                                onPressed: () {
                                  calcRouteFromDepToDes();
                                },
                                child: const Text("Chỉ đường"),
                              ),
                              IconButton(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(
                                        text:
                                        "https://maps.app.goo.gl/" +
                                            mapData
                                                .destinationID));
                                  },
                                  icon: Icon(Icons.bookmark)),
                            ],
                          )
                        ]),
                      ),
                    ),
                  ),
                );
              },
            )
                : (state == stateMap["Search Results None"]!)
                ?
            // Bottom sheet search results none
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize: defaultBottomSheetHeight / 1000,
              minChildSize: 0.05,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                  child: Container(
                      color: Colors.white,
                      child: SingleChildScrollView(
                        primary: false,
                        controller: scrollController,
                        child: Container(
                          padding: const EdgeInsets.only(
                              left: 20.0, right: 20.0),
                          child: Column(children: <Widget>[
                            const Pill(),
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                  BorderRadius.circular(5.0),
                                  child: SvgPicture.asset(
                                    "assets/icons/marker_big.svg",
                                    width: 80,
                                    height: 100,
                                    fit: BoxFit.scaleDown,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Địa điểm không xác định",
                                        style: const TextStyle(
                                          fontFamily:
                                          "SF Pro Display",
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                        overflow:
                                        TextOverflow.visible,
                                      ),
                                      Text(
                                        mapData.destinationLocationLatLgn!
                                            .latitude
                                            .toString()
                                            .substring(0, 8) +
                                            ", " +
                                            mapData
                                                .destinationLocationLatLgn!
                                                .longitude
                                                .toString()
                                                .substring(0, 8),
                                        style: const TextStyle(
                                          fontFamily:
                                          "SF Pro Display",
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                        overflow:
                                        TextOverflow.visible,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            FilledButton(
                              onPressed: () {
                                calcRoute(
                                    from: mapData
                                        .departureLocation!,
                                    to: mapData
                                        .destinationLocationLatLgn!);
                              },
                              child: const Text("Chỉ đường"),
                            ),
                          ]),
                        ),
                      )),
                );
              },
            )
                : (state == stateMap["Route Planning"]!)
                ?
            // Bottom sheet route planning
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize:
              defaultBottomSheetHeight / 1000,
              minChildSize: 0.15,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      primary: false,
                      controller: scrollController,
                      child: Column(children: <Widget>[
                        const Pill(),
                        Container(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              changeState("Add Waypoint");
                            },
                            icon: SizedBox(
                                width: 20,
                                height: 20,
                                child: SvgPicture.asset(
                                    "assets/icons/add_waypoint.svg")),
                            label: Text('Thêm điểm dừng'),
                          ),
                        ),
                        RoutePlanningListTile(
                          route: routes[0],
                          travelMode: travelMode,
                          isAvoidTolls: isAvoidTolls,
                          isAvoidHighways: isAvoidHighways,
                          isAvoidFerries: isAvoidFerries,
                          waypointsLatLgn: waypointsLatLgn,
                          destinationLatLgn: mapData
                              .destinationLocationLatLgn!,
                        )
                        // RoutePlanningList(
                        //     routes: routes,
                        //     travelMode: travelMode,
                        //     isAvoidTolls: isAvoidTolls,
                        //     isAvoidHighways: isAvoidHighways,
                        //     isAvoidFerries: isAvoidFerries,
                        //     waypointsLatLgn: waypointsLatLgn,
                        //     destinationLatLgn:
                        //         mapData.destinationLocation!,
                        //     itemClick: (index) {
                        //       //changeState("Navigation");
                        //     })
                      ]),
                    ),
                  ),
                );
              },
            )
                : (state == stateMap["Navigation"]!)
                ?
            // Bottom sheet navigation
            DraggableScrollableSheet(
                controller: _dragableController,
                initialChildSize:
                defaultBottomSheetHeight / 1000,
                minChildSize: 0.15,
                maxChildSize: 1,
                builder: (BuildContext context,
                    ScrollController scrollController) {
                  return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24.0),
                        topRight: Radius.circular(24.0),
                      ),
                      child: Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                              primary: false,
                              controller: scrollController,
                              child:
                              Column(children: <Widget>[
                                const Pill(),
                                EndLocationList(
                                  onLongPress:
                                      (LatLng latlng) {
                                    animateToPosition(
                                        latlng,
                                        zoom: 17);
                                  },
                                  legs: routes[0].legs,
                                  controller:
                                  _listviewScrollController,
                                )
                              ]))));
                })
                : (state == stateMap["Loading Can Route"]!)
                ?
            // Bottom sheet loading can route
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize:
              defaultBottomSheetHeight / 1000,
              minChildSize: 0.15,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController scrollController) {
                return ClipRRect(
                  borderRadius:
                  const BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      primary: false,
                      controller: scrollController,
                      child:
                      Column(children: <Widget>[
                        const Pill(),
                        const SizedBox(
                          height: 30,
                        ),
                        Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.green,
                            ),
                            const SizedBox(
                              height: 34,
                            ),
                            FilledButton(
                              onPressed: () {
                                calcRoute(
                                    from: mapData
                                        .departureLocation ??
                                        mapData
                                            .currentLocation!,
                                    to: mapData
                                        .destinationLocationLatLgn!);
                              },
                              child: const Text(
                                  "Chỉ đường"),
                            ),
                          ],
                        )
                      ]),
                    ),
                  ),
                );
              },
            )
                : (state == stateMap["Add Waypoint"]!)
                ?
            // Bottom sheet add waypoint
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize:
              defaultBottomSheetHeight / 1000,
              minChildSize: 0.15,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController
                  scrollController) {
                return ClipRRect(
                  borderRadius:
                  const BorderRadius.only(
                    topLeft:
                    Radius.circular(24.0),
                    topRight:
                    Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                        primary: false,
                        controller:
                        scrollController,
                        child: Column(
                            children: <Widget>[
                              const Pill(),
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height:
                                        40,
                                        child: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                waypointsLatLgn.removeLast();
                                                waypointNames.removeLast();
                                                myMarker.removeLast();
                                              });
                                            },
                                            icon: SvgPicture.asset("assets/icons/remove.svg")),
                                      ),
                                      ElevatedButton(
                                          onPressed:
                                              () {
                                            calcRouteFromDepToDes();
                                          },
                                          child: Text(
                                              "Áp dụng")),
                                      SizedBox(
                                          width:
                                          80,
                                          height:
                                          40,
                                          child: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  waypointsLatLgn.add(centerLocation);
                                                  convertLatLngToAddress(centerLocation, isCutoff: true).then((value) {
                                                    setState(() {
                                                      waypointNames.add(value);
                                                      logWithTag("Waypoint Name: $value", tag: "Add Waypoint");
                                                    });
                                                  });
                                                  myMarker.add(Marker(
                                                    markerId: MarkerId(centerLocation.toString()),
                                                    icon: (myMarker.length < waypointMarkers.length) ? waypointMarkers[(myMarker.length - 1)] : waypointMarkers[waypointMarkers.length - 1],
                                                    position: centerLocation,
                                                  ));
                                                });
                                              },
                                              icon: SvgPicture.asset("assets/icons/add.svg")))
                                    ],
                                  ),
                                  TextButton(
                                      onPressed:
                                          () {
                                        setState(
                                                () {
                                              waypointsLatLgn
                                                  .clear();
                                              myMarker.removeWhere((marker) =>
                                              marker.icon !=
                                                  mainMarker);
                                            });
                                      },
                                      child: Text(
                                          "Xóa tất cả")),
                                  WaypointList(
                                    waypoints:
                                    waypointsLatLgn,
                                    waypointsName:
                                    waypointNames,
                                    controller:
                                    _listviewScrollController,
                                    markerList:
                                    myMarker,
                                  ),
                                ],
                              ),
                            ])),
                  ),
                );
              },
            )
                : (state == stateMap["Loading"]!)
                ?
            // Bottom sheet loading
            DraggableScrollableSheet(
              controller: _dragableController,
              initialChildSize:
              defaultBottomSheetHeight /
                  1000,
              minChildSize: 0.15,
              maxChildSize: 1,
              builder: (BuildContext context,
                  ScrollController
                  scrollController) {
                return ClipRRect(
                  borderRadius:
                  const BorderRadius.only(
                    topLeft:
                    Radius.circular(24.0),
                    topRight:
                    Radius.circular(24.0),
                  ),
                  child: Container(
                    color: Colors.white,
                    child:
                    SingleChildScrollView(
                      primary: false,
                      controller:
                      scrollController,
                      child: Column(
                          children: <Widget>[
                            const Pill(),
                            SizedBox(
                              height: 40,
                            ),
                            LoadingIndicator(
                              color: Colors
                                  .green,
                              onPressed: () {
                                changeState(
                                    "Search Results");
                              },
                            ),
                          ]),
                    ),
                  ),
                );
              },
            )
                :

            // Bottom sheet none
            const SizedBox.shrink(),
          )
        ],
      ),
    );
  }
}

class MapData {
  LatLng? currentLocation;
  LatLng? departureLocation;
  String departureLocationName;
  LatLng? destinationLocationLatLgn;
  String destinationLocationAddress;
  String destinationLocationPlaceName;
  String destinationLocationPhotoUrl;
  String destinationID = "";

  MapData({
    this.currentLocation,
    this.departureLocation,
    this.destinationLocationLatLgn,
    this.departureLocationName = "Vị trí hiện tại",
    this.destinationLocationAddress = "",
    this.destinationLocationPlaceName = "",
    this.destinationLocationPhotoUrl = "",
  });

  void changeDestinationLocationLatLgn(LatLng latLng) {
    destinationLocationLatLgn = latLng;
    logWithTag("Destination location changed to: $latLng", tag: "MapData");
    logWithTag(
        "All data: $currentLocation, $departureLocation, $destinationLocationLatLgn",
        tag: "MapData");
    // Future<String?> placeString = convertLatLngToAddress(latLng);
    // placeString.then((value) {
    //   destinationLocationName = value ?? "Không có chi tiết";
    //   logWithTag("Destination location changed to: $value + $latLng",
    //       tag: "MapData");
    // });
  }

  void changeDepartureLocation(LatLng from) {
    departureLocation = from;
    logWithTag("Departure location changed to: $from", tag: "MapData");
    logWithTag(
        "All data: $currentLocation, $departureLocation, $destinationLocationLatLgn",
        tag: "MapData");

    // Future<String?> placeString = convertLatLngToAddress(from);
    // placeString.then((value) {
    //   departureLocationName = value ?? "Không có chi tiết";
    //   logWithTag("Departure location changed to: $value + $from",
    //       tag: "MapData");
    // });
  }

  void changeCurrentLocation(LatLng value) {
    currentLocation = value;
    logWithTag("Current location changed to: $value", tag: "MapData");
    logWithTag(
        "All data: $currentLocation, $departureLocation, $destinationLocationLatLgn",
        tag: "MapData");
  }

  void changeDestinationLocationAddress(String value) {
    destinationLocationAddress = value;
    logWithTag("Destination location name changed to: $value", tag: "MapData");
  }

  void changeDestinationLocationPlaceName(String value) {
    destinationLocationPlaceName = value;
    logWithTag("Destination location name changed to: $value", tag: "MapData");
  }

  void changeDestinationAddressAndPlaceNameAndImage(PlaceSearch_ place) {
    destinationID = place.id!;
    destinationLocationAddress = place.formattedAddress!;
    destinationLocationPlaceName = place.displayName?.text ?? "";
    if (place.photoUrls != null) destinationLocationPhotoUrl = place.photoUrls!;
    logWithTag(place.toString(), tag: "MapData info");
    logWithTag(
        "Destination location name changed to: $destinationLocationPlaceName",
        tag: "MapData");
    logWithTag(
        "Destination location address changed to: $destinationLocationAddress",
        tag: "MapData");
  }

  void changeDestinationImage(String value) {
    destinationLocationPhotoUrl = value;
    logWithTag("Destination location image changed to: $value", tag: "MapData");
  }
}
