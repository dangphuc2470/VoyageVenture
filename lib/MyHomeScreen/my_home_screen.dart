import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:voyageventure/components/misc_widget.dart';
import 'package:voyageventure/constants.dart';
import 'package:voyageventure/main.dart';
import 'package:voyageventure/utils.dart';
import 'package:voyageventure/features/current_location.dart';
import '../MyLocationSearch/my_location_search.dart';
import '../components/bottom_sheet_componient.dart';
import '../components/fonts.dart';
import '../components/location_list_tile.dart';
import '../models/place_autocomplete.dart';
import '../models/place_search.dart';

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

  //Animation
  late AnimationController _animationController;
  late Animation<double> moveAnimation;

  //GeoLocation
  LatLng? currentLocation;
  bool isHaveLastSessionLocation = false;

  Future<LatLng> getCurrentLocationLatLng() async {
    Position position = await getCurrentLocation();
    return LatLng(position.latitude, position.longitude);
  }

  void animateToPosition(LatLng position, {double zoom = 13}) async {
    GoogleMapController controller = await _mapsController.future;
    CameraPosition cameraPosition = CameraPosition(
      target: position,
      zoom: zoom, // Change this value to your desired zoom level
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  //Location
  List<PlaceAutocomplete_> placeAutoList = [];
  List<PlaceSearch_> placeSearchList = [];
  bool placeFound = true;
  List<Marker> myMarker = [];
  BitmapDescriptor defaultMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  BitmapDescriptor mainMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  //Route
  Future<List<LatLng>?> polylinePoints = Future.value(null);
  Polyline? route;

  //Test
  static CameraPosition? _initialCameraPosition;
  static const LatLng _airPort = LatLng(10.8114795, 106.6548157);
  static const LatLng _dormitory = LatLng(10.8798036, 106.8052206);

  @override
  void initState() {
    super.initState();
    if (!isHaveLastSessionLocation) {
      getCurrentLocationLatLng().then((value) {
        currentLocation = value;
        animateToPosition(currentLocation!);
      });
    }

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    moveAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
            "assets/icons/marker_small.svg", const Size(48, 48))
        .then((bitmapDescriptor) {
      setState(() {
        defaultMarker = bitmapDescriptor;
      });
    });

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
            "assets/icons/marker_big.svg", const Size(60, 60))
        .then((bitmapDescriptor) {
      setState(() {
        mainMarker = bitmapDescriptor;
      });
    });
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
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
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: myMarker.toSet(),
            onMapCreated: (GoogleMapController controller) {
              _mapsController.complete(controller);
            },
            polylines: {if (route != null) route!},
            zoomControlsEnabled: false,
            // markers: {
            //   Marker(
            //     markerId: const MarkerId('marker_1'),
            //     position: const LatLng(10.7981542, 106.6614047),
            //     infoWindow: const InfoWindow(
            //       title: 'Marker 1',
            //       snippet: '5 Star Rating',
            //     ),
            //     icon: BitmapDescriptor.defaultMarkerWithHue(
            //         BitmapDescriptor.hueViolet),
            //   ),
            //   Marker(
            //     markerId: const MarkerId('marker_2'),
            //     position: const LatLng(10.9243059, 106.8155907),
            //     infoWindow: const InfoWindow(
            //       title: 'Marker 2',
            //       snippet: '4 Star Rating',
            //     ),
            //     icon: BitmapDescriptor.defaultMarkerWithHue(
            //         BitmapDescriptor.hueViolet),
            //   ),
            // }
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.fastOutSlowIn,
            bottom: (bottomSheetTop == null)
                ? (MediaQuery.of(context).size.height *
                        defaultBottomSheetHeight /
                        1000) +
                    10
                : bottomSheetTop! + 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  elevation: 5,
                  onPressed: () {
                    if (currentLocation != null) {
                      animateToPosition(currentLocation!);
                    }
                    getCurrentLocation().then((value) {
                      if (currentLocation !=
                          LatLng(value.latitude, value.longitude)) {
                        currentLocation =
                            LatLng(value.latitude, value.longitude);
                        animateToPosition(currentLocation!);
                        logWithTag("Location changed!", tag: "MyHomeScreen");
                      }
                    });
                    // Handle button press
                  },
                  child: const Icon(Icons.my_location_rounded),
                ),
                // Add more widgets here that you want to move with the sheet
              ],
            ),
          ),
          NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                setState(() {
                  bottomSheetTop = _dragableController.pixels;
                });
                return true;
              },
              child: DraggableScrollableSheet(
                controller: _dragableController,
                initialChildSize: defaultBottomSheetHeight / 1000,
                minChildSize: 0.15,
                maxChildSize: 1,
                builder:
                    (BuildContext context, ScrollController scrollController) {
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
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.only(
                                    left: defaultPadding,
                                    right: defaultPadding,
                                    top: defaultPadding,
                                    bottom: 8.0),
                                child: CupertinoSearchTextField(
                                  style: leagueSpartanNormal20,
                                  placeholder: "Tìm địa điểm",
                                  onChanged: (text) {
                                    if (text.isEmpty) {
                                      setState(() {
                                        placeFound = true;
                                        placeAutoList.clear();
                                      });
                                    } else {
                                      logWithTag("Place auto complete: $text",
                                          tag: "SearchLocationScreen");
                                      setState(() {
                                        placeAutocomplete(text)
                                            .then((autoList) => setState(() {
                                                  if (autoList != null) {
                                                    placeAutoList = autoList;
                                                    placeFound = true;
                                                  } else {
                                                    placeFound = false;
                                                  }
                                                }));
                                      });
                                    }
                                  },
                                  onSubmitted: (text) {
                                    if (text.isEmpty) {
                                      placeFound = true;
                                      placeSearchList.clear();
                                    } else {
                                      setState(() {
                                        myMarker = [];
                                      });
                                      logWithTag("Place search: $text",
                                          tag: "SearchLocationScreen");
                                      placeSearch(text).then((searchList) =>
                                          setState(() {
                                            if (searchList != null) {
                                              placeSearchList = searchList;
                                              for (int i = 0; i < placeSearchList.length; i++) {
                                                final markerId =
                                                    MarkerId(placeSearchList[i].id!);
                                                final marker = Marker(
                                                  markerId: markerId,
                                                  icon: (i == 0)? mainMarker : defaultMarker,
                                                  position: LatLng(
                                                      placeSearchList[i].location
                                                              ?.latitude ??
                                                          0.0,
                                                      placeSearchList[i].location
                                                              ?.longitude ??
                                                          0.0),
                                                  infoWindow: InfoWindow(
                                                    title:
                                                        placeSearchList[i].displayName?.text,
                                                    snippet:
                                                        placeSearchList[i].formattedAddress,
                                                  ),
                                                );
                                                myMarker.add(marker);
                                              }
                                              placeFound = true;

                                              _dragableController.animateTo(
                                                defaultBottomSheetHeight / 1000,
                                                // Scroll to the top of the DraggableScrollableSheet
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                // Duration to complete the scrolling
                                                curve: Curves
                                                    .fastOutSlowIn, // Animation curve
                                              );
                                            } else {
                                              placeFound = false;
                                            }
                                          }));
                                    }
                                  },
                                  onTap: () {
                                    logWithTag("Search bar clicked: ",
                                        tag: "SearchLocationScreen");
                                    setState(() async {
                                      await Future.delayed(
                                          const Duration(milliseconds: 500));
                                      _dragableController.animateTo(
                                        0.8,
                                        // Scroll to the top of the DraggableScrollableSheet
                                        duration:
                                            const Duration(milliseconds: 300),
                                        // Duration to complete the scrolling
                                        curve: Curves
                                            .fastOutSlowIn, // Animation curve
                                      );
                                      //Todo: Fix current location button
                                      //bottomSheetTop = _dragableController.pixels;
                                    });
                                  },
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.only(
                                        left: defaultPadding, right: 8),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        logWithTag("Add home button clicked: ",
                                            tag: "SearchLocationScreen");
                                      },
                                      icon: SvgPicture.asset(
                                        "assets/icons/home_add.svg",
                                        height: 16,
                                      ),
                                      label: Text("Thêm nhà",
                                          style: leagueSpartanNormal15),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            secondaryColor10LightTheme,
                                        foregroundColor: textColorLightTheme,
                                        elevation: 0,
                                        fixedSize:
                                            const Size(double.infinity, 40),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(20)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      logWithTag("Button clicked: ",
                                          tag: "SearchLocationScreen");
                                    },
                                    icon: SvgPicture.asset(
                                      "assets/icons/location_add.svg",
                                      height: 16,
                                    ),
                                    label: Text("Thêm địa điểm",
                                        style: leagueSpartanNormal15),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          secondaryColor10LightTheme,
                                      foregroundColor: textColorLightTheme,
                                      elevation: 0,
                                      fixedSize:
                                          const Size(double.infinity, 40),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              placeFound
                                  ? ListView.builder(
                                      controller: _listviewScrollController,
                                      shrinkWrap: true,
                                      itemCount: placeAutoList.length,
                                      itemBuilder: (context, index) {
                                        return LocationListTile_(
                                          press: () {
                                            logWithTag(
                                                "Location clicked: ${placeAutoList[index].toString()}",
                                                tag: "SearchLocationScreen");
                                            placeSearch(placeAutoList[index]
                                                    .structuredFormat
                                                    ?.mainText
                                                    ?.text ??
                                                "");
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
                                    )
                                  : const Center(
                                      child: Text('Không tìm thấy địa điểm')),
                              //MockList_()
                            ],
                          ),
                          BottomSheetComponient_(
                              controller: _listviewScrollController),
                        ]),
                      ),
                    ),
                  );
                },
              ))
        ],
      ),
    );
  }
}
