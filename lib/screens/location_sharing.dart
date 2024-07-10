import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math'; // Import math library for acos function
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:voyageventure/features/current_location.dart';
import 'package:voyageventure/utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_screen.dart';
import 'location_signup_login.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'location_user_profile.dart';

class LocationSharing extends StatefulWidget {
  const LocationSharing({super.key});

  @override
  State<LocationSharing> createState() => _LocationSharingState();
}

bool distanceBetween(LatLng position1, LatLng position2) {
  double one = position1.latitude - position2.latitude;
  one = one.abs();
  double two = position1.longitude - position2.longitude;
  two = two.abs();
  if (one <= 0.0004 && two <= 0.0004) {
    return true;
  }
  return false;
}

class _LocationSharingState extends State<LocationSharing> {
  CameraPosition _initialLocation =
  const CameraPosition(target: LatLng(10.878618,106.8078733), zoom: 15);
  List<Marker> myMarker = [];
  GoogleMapController? _controller;
  bool _showWhiteBox = false; // State variable to control box visibility
  bool isFetchImage = false;
  LatLng? _selectedLocation;
  final Completer<GoogleMapController> _mapsController = Completer();
  Polyline? route;
  bool isHaveLastSessionLocation = false;
  late StreamSubscription<Position> _positionStream;

  List<LatLng> friendLocations = [];
  List<String> friendID = [];
  List<String> friendImage = [];
  List<Uint8List> friendImageBytes = [];
  BitmapDescriptor defaultMarker = BitmapDescriptor.defaultMarker;

  FirebaseFirestore get firestore =>
      FirebaseFirestore
          .instance; // Function to add a user to the Firestore database

  Future<void> addUser(String userId, String name, GeoPoint location) async {
    // Create a new document with the user ID
    final userRef = firestore.collection('users').doc(userId);

    // Add user data, including an empty "friends" array initially
    await userRef.set({
      'name': name,
      'location': location,
      'lastup': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      // Update timestamp
      'friends': [],
      // Empty friends array
    });
  }

  Future<Uint8List> fetchImageBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      // Handle error: throw exception, show error message etc.
      throw Exception('Failed to download image');
    }
  }

  Future<Marker> createMarkerWithNetworkImage(LatLng position,
      String imageUrl,) async {
    final imageBytes = await fetchImageBytes(imageUrl);
    final bitmapDescriptor = BitmapDescriptor.fromBytes(imageBytes);
    return Marker(
      markerId: MarkerId(imageUrl),
      position: position,
      icon: bitmapDescriptor,
    );
  }


  Future<void> setInitialLocation() async {
    Position position = await getCurrentLocation();
    _initialLocation = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 13,
    );

    setState(() {}); // Update UI
  }

  void addFriendMarkers() {
    myMarker.clear();
    for (final location in friendLocations) {
      Marker marker;
      if (isFetchImage)
        marker = Marker(
          markerId: MarkerId('friend_${friendLocations.indexOf(location)}'),
          icon:(friendLocations.indexOf(location) > friendImageBytes.length - 1)?
              defaultMarker
          :BitmapDescriptor.fromBytes(
              friendImageBytes[friendLocations.indexOf(location)]),
          position: location,
        );
      else
        marker = Marker(
          markerId: MarkerId('friend_${friendLocations.indexOf(location)}'),
          icon: defaultMarker,
          position: location,
        );
      setState(() {
        myMarker.add(marker);
      });
    }
  }

  Future<void> updateFriendLocations() async {
    if (FirebaseAuth.instance.currentUser != null) {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userRef = firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final friends = (userDoc.get('friends') as List<dynamic>)
          .map((item) => item.toString())
          .toList();

      List<LatLng> newFriendLocations = [];
      List<String> newFriendID = [];
      List<String> newFriendImage = [];

      for (final friendId in friends) {
        final friendRef = firestore.collection('users').doc(friendId);
        final friendDoc = await friendRef.get();
        final friendLocation = friendDoc.get('location') as GeoPoint;
        String friendImage = friendDoc.get('ImageUrl').toString();
        newFriendID.add(friendId);

        newFriendLocations
            .add(LatLng(friendLocation.latitude, friendLocation.longitude));
        newFriendImage.add(friendImage);
      }

      // Compare new list with current list

      friendLocations.clear();
      setState(() {
        friendLocations = newFriendLocations;
        friendID = newFriendID;
        if (!isFetchImage) {
          friendImage = newFriendImage;
          for (int i = 0; i < friendLocations.length; i++) {
            fetchImageBytes(friendImage[i]).then((imageBytes) {
              friendImageBytes.add(imageBytes);
              if (friendImageBytes.length == friendLocations.length) {
                isFetchImage = true;
                addFriendMarkers();
                // Update image after fetch all image
              }
            });
          }
        }
        addFriendMarkers();
      });
    }
  }

  void trackLocation() {
    if (FirebaseAuth.instance.currentUser != null) {
      final geolocator = GeolocatorPlatform.instance;
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userRef = firestore.collection('users').doc(userId);

      _positionStream = geolocator.getPositionStream().listen(
            (Position position) async {
          final GoogleMapController controller = await _mapsController.future;
          final double currentZoomLevel =
          await controller.getZoomLevel(); // Get current zoom level
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: currentZoomLevel,
            ),
          ));

          await userRef.update({
            'location': GeoPoint(position.latitude, position.longitude),
          });

          setState(() {
            myMarker.clear();
            myMarker.add(Marker(
              markerId: const MarkerId('myMarker'),
              position: LatLng(position.latitude, position.longitude),
            ));
          });
        },
      );
    }
  }

  Future<Map<String, dynamic>> fetchUserDataAndAddress(String userId) async {
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data() as Map<String, dynamic>;
    final address = await convertLatLngToAddress2(
      LatLng(data['location'].latitude, data['location'].longitude),
      isCutoff: true,
    );
    return {
      ...data,
      'address': address,
    };
  }


  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  bool isLoggedIn = false;
  String? _selectedFriendId;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    setInitialLocation();
    updateFriendLocations();

    BitmapDescriptorHelper.getBitmapDescriptorFromSvgAsset(
        "assets/icons/default_friends_marker.svg", const Size(100, 100))
        .then((bitmapDescriptor) {
      setState(() {
        defaultMarker = bitmapDescriptor;
      });
    });

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
  }


  @override
  void dispose() {
    super.dispose();
    _positionStream.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: <Widget>[
        GoogleMap(
          initialCameraPosition: _initialLocation,
          mapType: MapType.normal,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          markers: myMarker.toSet(),
          onMapCreated: (GoogleMapController controller) {
            _mapsController.complete(controller);
          },
          onTap: (LatLng position) {
            for (final friendLocation in friendLocations) {
              if (distanceBetween(position, friendLocation)) {
                setState(() {
                  _showWhiteBox = !_showWhiteBox;
                  if (_showWhiteBox) {
                    _selectedLocation = position;
                    _selectedFriendId =
                    friendID[friendLocations.indexOf(friendLocation)];
                    fetchUserDataAndAddress(_selectedFriendId!).then((data) {
                      setState(() {
                        userData = data;
                      });
                    });
                  } else {
                    _selectedFriendId = null;
                  }
                });
              }
            }
          },
          polylines: {if (route != null) route!},
          zoomControlsEnabled: false,
        ),
        Positioned(
          top: 40, // Adjust as needed
          child: FloatingActionButton(
            heroTag: "fab2",
            backgroundColor: Colors.transparent,
            elevation: 0,
            // Remove shadow
            child: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            // Set icon color as needed
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyHomeScreen()),
              );
            },
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseAuth.instance.currentUser != null
              ? FirebaseFirestore.instance.collection('users').snapshots()
              : null,
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Text('Something went wrong');
            }

            if (isLoggedIn) {
              updateFriendLocations();
            }

            return Positioned(
              top: 40,
              right: 10,
              child: FloatingActionButton(
                heroTag: "fab3",
                backgroundColor: Colors.white,
                onPressed: () async {
                  if (isLoggedIn) {
                    updateFriendLocations();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UserProfilePage()),
                    );
                  } else {
                    isLoggedIn = true;
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LoginSignupPage()));
                    updateFriendLocations();
                  }
                },
                child: const Icon(Icons.home),
              ),
            );
          },
        ),
        Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Visibility(
              visible: _showWhiteBox,
              child: Container(
                height: 120,
                width: MediaQuery
                    .of(context)
                    .size
                    .width,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: _showWhiteBox && userData != null
                    ? Column(
                  children: [
                    Container(
                      child: Text('${userData!['email']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.0,
                          )), // Bold and 18px font size
                    ),
                    SizedBox(height: 20.0),
                    Expanded(
                      child: Text(userData!['address']),
                    ),
                  ],
                )
                    : Container(),
              ),
            )),
        Positioned(
          right: 10,
          bottom: 40,
          child: GestureDetector(
            onTap: () async {
                Position position = await getCurrentLocation();
                final GoogleMapController controller =
                    await _mapsController.future;
                final double currentZoomLevel = await controller.getZoomLevel();
                controller.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: currentZoomLevel,
                  ),
                ));
              },
            onLongPress: () async {
              Position position = await getCurrentLocation();
              final GoogleMapController controller =
              await _mapsController.future;
              controller.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(position.latitude, position.longitude),
                  zoom: 15,
                ),
              ));
            },
            child: FloatingActionButton(
              heroTag: "fab1",
              backgroundColor: Colors.white,
              onPressed: () {
              },

              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ),
      ]),
    );
  }
} //
