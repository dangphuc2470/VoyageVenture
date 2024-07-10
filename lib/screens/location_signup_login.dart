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


class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignup = false; // Flag to control login/signup form

  void toggleLoginSignup() {
    setState(() {
      _isSignup = !_isSignup;
    });
  }

  Future<GeoPoint> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return GeoPoint(position.latitude, position.longitude);
  }

  Future<void> createUserProfile(
      String userId, String name, String email, GeoPoint location) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(userId);

    await userRef.set({
      'name': name,
      'email': email,
      'location': location,
      'lastup': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'friends': [],
    });
  }

  Future<void> updateUserProfile(String userId, GeoPoint newLocation) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(userId);

    final doc = await userRef.get();
    final GeoPoint currentLocation = doc.get('location');

    await userRef.update({
      'lastLocation': currentLocation,
      'location': newLocation,
      'lastup': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    });
  }

  Future<void> _handleLoginSignup(BuildContext context) async {
    // Validate email and password (replace with your validation logic)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String email = _emailController.text.replaceAll(' ', '');
    String password = _passwordController.text;

    try {
      final FirebaseAuth auth = FirebaseAuth.instance;

      if (_isSignup) {
        // Create user
        UserCredential authResult = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final User user = authResult.user!;
        GeoPoint location = await getCurrentLocation();
        await createUserProfile(
            user.uid, user.displayName ?? '', user.email ?? '', location);

        await auth.signInWithEmailAndPassword(email: email, password: password);

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else {
        // Login existing user
        UserCredential authResult = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final User user = authResult.user!;
        GeoPoint location = await getCurrentLocation();
        await updateUserProfile(user.uid, location);

        // Handle successful login
        Navigator.pop(context); // Close login/signup page
        final snackBar = SnackBar(
          content: Text('Đăng nhập thành công!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Đóng',
            onPressed: () {},
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' && !_isSignup) {
        print('No user found for the provided email.');
        // Show an error message to the user (e.g., "Tài khoản không tồn tại")
      } else if (e.code == 'wrong-password' && !_isSignup) {
        print('Wrong password provided for that user.');
        // Show an error message to the user (e.g., "Sai mật khẩu")
      } else if (e.code == 'weak-password' && _isSignup) {
        print('The password provided is too weak.');
        // Show an error message to the user (e.g., "Mật khẩu quá yếu")
      } else {
        print('An unexpected error occurred: ${e.message}');
        // Handle other errors appropriately
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignup ? 'Đăng ký' : 'Đăng nhập'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  if (!value.contains('@')) {
                    return 'Email không hợp lệ';
                  }

                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mật khẩu';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: _emailController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Email đặt lại mật khẩu đã được gửi!'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Vui lòng nhập Email rồi nhấn nút Quên mật khẩu!'),
                        ),
                      );
                    }
                  },
                  child: Text('Quên mật khẩu?'),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: ElevatedButton(
                    onPressed: () => _handleLoginSignup(context),
                    child: Text(_isSignup ? 'Đăng ký' : 'Đăng nhập'),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: toggleLoginSignup,
                  child: Text(_isSignup
                      ? 'Bạn đã có tài khoản?'
                      : 'Bạn chưa có tài khoản?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
