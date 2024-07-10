import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math'; // Import math library for acos function
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:voyageventure/features/current_location.dart';
import 'package:voyageventure/utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import 'location_signup_login.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  List<LatLng> friendLocations = [];

  Future<void> addFriendByEmail(String email) async {
    final firestore = FirebaseFirestore.instance;

    // Find the friendId by email
    final friendSnapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (friendSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không có người dùng nào!'),
        ),
      );
    } else {
      final friendId = friendSnapshot.docs.first.id;
      final friendRef = firestore.collection('users').doc(friendId);
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userRef = firestore.collection('users').doc(userId);

      // Perform a transaction to ensure data consistency
      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final friendDoc = await transaction.get(friendRef);

        final currentUserFriends = (userDoc.get('friends') as List)
            .map((item) => item.toString())
            .toList();
        final currentFriendFriends = (friendDoc.get('friends') as List)
            .map((item) => item.toString())
            .toList();

        // Check if friend is already present for user
        if (!currentUserFriends.contains(friendId)) {
          // Update the user document with the new friend added
          transaction.update(userRef, {
            'friends': FieldValue.arrayUnion([friendId]),
          });
        }

        // Check if user is already present for friend
        if (!currentFriendFriends.contains(userId)) {
          // Update the friend document with the new friend added
          transaction.update(friendRef, {
            'friends': FieldValue.arrayUnion([userId]),
          });
        }
      });

      // Declare and assign a value to location2 before using it
      final friendData = await friendRef.get();
      final friendLocation = friendData.get('location');

      setState(() {
        friendLocations
            .add(LatLng(friendLocation.latitude, friendLocation.longitude));
      });
    }
  }

  Future<void> updatePhoneNumber(String phoneNumber) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final User? user = auth.currentUser;

  // Create a PhoneAuthCredential
  final PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: 'your-verification-id',
    smsCode: 'your-sms-code',
  );

  // Update the phone number
  if (user != null) {
    await user.updatePhoneNumber(credential);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật số điện thoại!'),
        ));
  } else {
    print('No user is currently signed in.');
  }
}

  Future<void> changePassword(String newPassword) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final User? user = auth.currentUser;

  // Update the password
  if (user != null) {
    await user.updatePassword(newPassword);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đổi password!'),
        ));
  } else {
    print('Không có.');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hồ sơ người dùng'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Nhập Email',
              ),
            ),
            ElevatedButton(
              onPressed: () => addFriendByEmail(_emailController.text),
              child: Text('Thêm Bạn'),
            ),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Số Điện Thoại',
              ),
            ),
            ElevatedButton(
              onPressed: () => updatePhoneNumber(_phoneController.text),
              child: Text('Cập Nhật'),
            ),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () => changePassword(_passwordController.text),
              child: Text('Thay Đổi'),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.0), // Thêm padding ở dưới
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    // Navigate to login page or main page
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LoginSignupPage()),
                    );
                  },
                  child: Text('Đăng xuất'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
