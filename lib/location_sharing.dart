import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math'; // Import math library for acos function
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:voyageventure/features/current_location.dart';
import 'package:voyageventure/utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'location_signuplogin.dart';
import 'location_userprofile.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  if (one <= 0.0003 && two <= 0.0002) {
    return true;
  }
  return false;
}

class _LocationSharingState extends State<LocationSharing> {
  CameraPosition _initialLocation =
  const CameraPosition(target: LatLng(0.0, 0.0));
  final Set<Marker> myMarker = {};
  GoogleMapController? _controller;
  bool _showWhiteBox = false; // State variable to control box visibility
  LatLng? _selectedLocation;
  final Completer<GoogleMapController> _mapsController = Completer();
  Polyline? route;
  bool isHaveLastSessionLocation = false;
  late StreamSubscription<Position> _positionStream;

  List<LatLng> friendLocations = [];

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

  Future<void> updateUserProfile(String userId, GeoPoint newLocation) async {
    // Get a reference to the document with the user ID
    final userRef = firestore.collection('users').doc(userId);

    // Get the current document
    final doc = await userRef.get();

    // Get the current location
    final GeoPoint currentLocation = doc.get('location');

    // Update user data
    await userRef.update({
      'lastLocation': currentLocation,
      'location': newLocation,
      'lastup': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    });
  }

// Function to retrieve a user's friends (consider implementing pagination for large friend lists)
  Future<void> getFriends(String userId1, String userId2) async {
    // Get a reference to the user documents
    final userRef1 = firestore.collection('users').doc(userId1);
    final userRef2 = firestore.collection('users').doc(userId2);

    // Get the current documents
    final doc1 = await userRef1.get();
    final doc2 = await userRef2.get();

    // Get the current locations
    final GeoPoint currentLocation1 = doc1.get('location');
    final GeoPoint currentLocation2 = doc2.get('location');

    // Update user data
    await userRef1.update({});

    await userRef2.update({});
  }

  @override
  void initState() {
    super.initState();
    setInitialLocation();
    updateFriendLocations();

    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    firestore.collection('user').get().then((QuerySnapshot querySnapshot) {
      logWithTag("Get data from firestore", tag: "LocationSharing");
      DocumentSnapshot documentSnapshot = querySnapshot.docs.first;
      String Email = documentSnapshot.get('Email');
      logWithTag("Data: ${Email}", tag: "LocationSharing");
    });

    //addFriendMarkers(); // Add markers for friend locations
    //trackLocation();
  }

  Future<void> setInitialLocation() async {
    Position position = await getCurrentLocation();
    _initialLocation = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 13,
    );
    myMarker.add(Marker(
      markerId: const MarkerId('myMarker'),
      position: LatLng(position.latitude, position.longitude),
    ));
    setState(() {}); // Update UI
  }

  void addFriendMarkers() {
    setState(() {
      myMarker.clear();
      for (final location in friendLocations) {
        myMarker.add(Marker(
          markerId: MarkerId('friend_${friendLocations.indexOf(location)}'),
          position: location,
        ));
      }
    });
  }

  Future<void> updateFriendLocations() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final friends = (userDoc.get('friends') as List<dynamic>)
        .map((item) => item.toString())
        .toList();

    List<LatLng> newFriendLocations = [];

    for (final friendId in friends) {
      final friendRef = firestore.collection('users').doc(friendId);
      final friendDoc = await friendRef.get();
      final friendLocation = friendDoc.get('location') as GeoPoint;

      newFriendLocations.add(
          LatLng(friendLocation.latitude, friendLocation.longitude));
    }

    // Compare new list with current list
    if (!listEquals(friendLocations, newFriendLocations)) {
      friendLocations.clear();
      setState(() {
        friendLocations = newFriendLocations;
        addFriendMarkers();
      });
    }
  }

    void trackLocation() {
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

    @override
    void dispose() {
      super.dispose();
      _positionStream.cancel();
    }

    final GoogleSignIn googleSignIn = GoogleSignIn();
    final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

    bool isLoggedIn = false;

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
                      }
                    });
                  }
                }
              },
              polylines: {if (route != null) route!},
              zoomControlsEnabled: false,
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .snapshots(),
              builder:
                  (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Text("Có lỗi: ${snapshot.error}");
                }

                if (isLoggedIn) {
                  updateFriendLocations();
                }

                return Positioned(
                  top: 20.0,
                  right: 20.0,
                  child: FloatingActionButton(
                    onPressed: () async {
                      if (isLoggedIn) {
                        updateFriendLocations();
                        // final userId = FirebaseAuth.instance.currentUser!.uid;
                        // final userRef = firestore.collection('users').doc(
                        //     userId);
                        // final userDoc = await userRef.get();
                        // final friends = (userDoc.get('friends') as List<
                        //     dynamic>)
                        //     .map((item) => item.toString())
                        //     .toList();
                        // for (final friendId in friends) {
                        //   final friendRef =
                        //   firestore.collection('users').doc(friendId);
                        //   final friendDoc = await friendRef.get();
                        //   final friendLocation =
                        //   friendDoc.get('location') as GeoPoint;
                        //
                        //   setState(() {
                        //     friendLocations.add(LatLng(
                        //         friendLocation.latitude,
                        //         friendLocation.longitude));
                        //     addFriendMarkers();
                        //   });
                        //}
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
                    child: const Icon(Icons.login),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 20,
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            child: Text('MAI HÂN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.0,
                                )), // Bold and 18px font size
                          ),
                          Spacer(),
                        ],
                      ),
                      SizedBox(height: 20.0),
                      const Expanded(
                        child: Text(
                            '255 Biscayne Blvd Way, Miami, FL 33131, United States'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () async {
                Position position = await getCurrentLocation();
                final GoogleMapController controller = await _mapsController
                    .future;
                final double currentZoomLevel = await controller.getZoomLevel();
                controller.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: currentZoomLevel,
                  ),
                ));
              },
              child: const Icon(Icons.center_focus_strong),
            ),
          ]));
    }
  }
