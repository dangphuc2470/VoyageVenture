import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:voyageventure/MySearchBar/my_search_bar.dart';
import 'package:http/http.dart' as http;
import 'package:voyageventure/components/misc_widget.dart';
import 'package:voyageventure/utils.dart';
import 'package:voyageventure/components/fonts.dart';
import 'package:voyageventure/features/current_location.dart';
import '../MyLocationSearch/my_location_search.dart';
import '../components/bottom_sheet_componient.dart';
import '../components/fonts.dart';
import '../models/route_calculate.dart';

class MyHomeScreen extends StatefulWidget {
  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  ScrollController _scrollController = ScrollController();
  DraggableScrollableController? _DragableController =
      DraggableScrollableController();
  double? bottomSheetTop;
  late AnimationController _animationController;
  late Animation<double> moveAnimation;
  bool isHaveLastLocation = false;
  Future<List<LatLng>?> polylinePoints = Future.value(null);
  static CameraPosition? _initialCameraPosition;
  static const LatLng _airPort = LatLng(10.8114795, 106.6548157);
  static const LatLng _dormitory = LatLng(10.8798036, 106.8052206);
  Polyline? route;

  // final List<Marker> myMarker = [];
  // final List<Marker> markerList = [
  //   const Marker(markerId: MarkerId("First"),
  //   position: LatLng(10.7981542, 106.6614147),
  //   infoWindow: InfoWindow(title: "First Marker"),
  //   )
  //   ,
  //   const Marker(markerId: MarkerId("Second"),
  //   position: LatLng(10.9243059,106.8155907),
  //   infoWindow: InfoWindow(title: "Second Marker"),
  //   )
  // ];

  void animateToCurrentPosition() async {
    Position position = await getCurrentLocation();
    GoogleMapController controller = await _controller.future;
    controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 13.0, // Change this value to your desired zoom level
          ),
    ));
  }

  @override
  void initState() {
    super.initState();
    if (!isHaveLastLocation) {
      animateToCurrentPosition();
    }

    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    moveAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );
    //myMarker.addAll(markerList);
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
      body: Stack(
        children: <Widget>[
          // Container(
          //   decoration: BoxDecoration(
          //     color: Colors.black,
          //   ),
          // ),

          GoogleMap(
            initialCameraPosition: (isHaveLastLocation == true)?
                const CameraPosition(
                  target: LatLng(20, 106),
                  zoom: 13,
                ) // Todo: last location
            : const CameraPosition(
              target: LatLng(10.7981542, 106.6614047),
              zoom: 13,
            ), //Default location
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            //markers: Set.from(myMarker),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
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
                ? (MediaQuery.of(context).size.height * 20 / 100) + 10
                : bottomSheetTop! + 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  elevation: 5,
                  onPressed: () {
                    animateToCurrentPosition();
                    // Handle button press
                  },
                  child: Icon(Icons.my_location_rounded),
                ),
                // Add more widgets here that you want to move with the sheet

              ],
            ),
          ),

          NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                setState(() {
                  logWithTag(
                      "Change from " +
                          bottomSheetTop.toString() +
                          "to" +
                          _DragableController!.pixels.toString(),
                      tag: "MyHomeScreen");
                  bottomSheetTop = _DragableController!.pixels;
                });

                // logWithTab(scrollInfo.toString(), tag: "MyHomeScreen");
                // if (scrollInfo is ScrollEndNotification) {
                //   double pixelValue = scrollInfo.metrics.pixels;
                //   logWithTab('pixel value: ${scrollInfo.metrics.pixels}', tag: "MyHomeScreen1");// In ra giá trị pixel
                //   logWithTab(_scrollController.position.maxScrollExtent.toString(), tag: "MyHomeScreen2");// In ra giá trị pixel
                // }
                //   setState(() {
                //     _fabPosition = _fabPosition + 10;
                //     //_fabPosition = scrollInfo.metrics.pixels;
                //     logWithTab(_fabPosition.toString(),
                //         tag: "MyHomeScreen");
                //   });

                return true;
              },
              child: DraggableScrollableSheet(
                controller: _DragableController,
                // initialChildSize: 0.2,

                initialChildSize: 0.2,
                minChildSize: 0.1,
                maxChildSize: 1.0,
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
                          Pill(),
                          LocationSearchScreen_(controller: _scrollController),
                          BottomSheetComponient_(controller: _scrollController),
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

// class MockSearchLocationScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//         child: Column(
//           children: [
//             Form(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: TextFormField(
//                   onChanged: (value) {
//                     //logWithTab("Place: $value", tag: "SearchLocationScreen");
//                     //placeAutocomplete(value);
//                     //placeSearch(value);
//                   },
//                   textInputAction: TextInputAction.search,
//                   decoration: InputDecoration(
//                     hintText: "Search your location",
//                   ),
//                 ),
//               ),
//             ),
//             const Divider(
//               height: 4,
//               thickness: 4,
//               color: Colors.grey,
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: ElevatedButton.icon(
//                 onPressed: () {
//                   //logWithTab("Button clicked: ", tag: "SearchLocationScreen");
//                   //placeSearch("Nha tho");
//                   //placeSearch("Nha tho");
//                 },
//                 icon: const Icon(Icons.my_location_rounded),
//                 label: const Text("Use my Current Location"),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.orange,
//                   elevation: 0,
//                   fixedSize: const Size(double.infinity, 40),
//                   shape: const RoundedRectangleBorder(
//                     borderRadius: BorderRadius.all(Radius.circular(10)),
//                   ),
//                 ),
//               ),
//             ),
//             const Divider(
//               height: 4,
//               thickness: 4,
//               color: Colors.grey,
//             ),
//             ListView.builder(
//               itemCount: 1,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text('Item $index'),
//                 );
//               },
//               shrinkWrap: true, // this property is important
//             ),
//
//             // Expanded(
//             //   child: ListView.builder(
//             //     itemCount: 3,
//             //     itemBuilder: (context, index) {
//             //       return ListTile(
//             //         title: Text("Location $index"),
//             //         subtitle: Text("Location $index"),
//             //         onTap: () {
//             //           //logWithTab("Location $index", tag: "SearchLocationScreen");
//             //         },
//             //       );
//             //     },
//             //   )
//             //
//             // ),
//             // LocationListTile(
//             //   press: () {},
//             //   location: "Banasree, Dhaka, Bangladesh",
//             // ),
//           ],
//         )
//     );
//   }
// }
