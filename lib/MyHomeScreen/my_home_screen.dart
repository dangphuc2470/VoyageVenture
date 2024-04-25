import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:voyageventure/MySearchBar/my_search_bar.dart';
import 'package:http/http.dart' as http;
import 'package:voyageventure/utils.dart';

import '../MyLocationSearch/my_location_search.dart';
import '../models/route_calculate.dart';

class MyHomeScreen extends StatefulWidget {
  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  Future<List<LatLng>?> polylinePoints = Future.value(null);
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(10.7981542, 106.6614047),
    zoom: 12,
  );

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

  @override
  void initState() {
    super.initState();
    //myMarker.addAll(markerList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
            ),
            //Todo: Uncomment Google Map
            //   GoogleMap(
            //   initialCameraPosition: _initialCameraPosition,
            //   mapType: MapType.normal,
            //   myLocationEnabled: true,
            //   //markers: Set.from(myMarker),
            //   onMapCreated: (GoogleMapController controller) {
            //     _controller.complete(controller);
            //   },
            //     polylines: {
            //       if (route != null) route!
            //     },
            //   zoomControlsEnabled: false,
            //   markers: {
            //     Marker(
            //       markerId: const MarkerId('marker_1'),
            //       position: const LatLng(10.7981542, 106.6614047),
            //       infoWindow: const InfoWindow(
            //         title: 'Marker 1',
            //         snippet: '5 Star Rating',
            //       ),
            //       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            //     ),
            //     Marker(
            //       markerId: const MarkerId('marker_2'),
            //       position: const LatLng(10.9243059, 106.8155907),
            //       infoWindow: const InfoWindow(
            //         title: 'Marker 2',
            //         snippet: '4 Star Rating',
            //       ),
            //       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            //     ),
            //   }
            // ),
            DraggableScrollableSheet(
              initialChildSize: 0.2,
              // initial size of the sheet, 30% of screen height
              minChildSize: 0.1,
              // minimum size of the sheet, 10% of screen height
              maxChildSize: 1.0,
              // maximum size of the sheet, 100% of screen height
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
                      controller: scrollController,
                      child: Column(children: <Widget>[
                        Container(
                          margin: EdgeInsets.only(top: 8.0),
                          height: 4.0,
                          width: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius:
                                BorderRadius.all(Radius.circular(15.0)),
                          ),
                        ),
                        LocationSearchScreen_(),
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F0F0),
                            borderRadius:
                                BorderRadius.all(Radius.circular(15.0)),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Column( //BST, BDNT
                              children: [
                                DecoratedBox(decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.all(Radius.circular(15.0)),
                                ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('BST', style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 24.0,
                                    ),),
                                  ),
                                ),
                                ],
                            ),
                          )
                        ),
                        // Text('This is a draggable sheet',
                        //     textAlign: TextAlign.center,
                        //     style: TextStyle(
                        //       color: Colors.black,
                        //       fontSize: 24.0,
                        //     )),
                      ]),
                    ),
                  ),
                );
              },
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            polylinePoints = computeRoutes(from: _airPort, to: _dormitory);
            polylinePoints.then((value) {
              setState(() {
                if (value != null) {
                  route = Polyline(
                    polylineId: const PolylineId('route'),
                    color: Colors.green,
                    points: value,
                    width: 5,
                  );
                }
              });
            });
            //(CameraUpdate.newCameraPosition(_initialCameraPosition ));
          },
          child: const Icon(Icons.my_location_rounded),
        ));
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
