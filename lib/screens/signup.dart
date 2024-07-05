import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  List<PlatformFile>? selectedFiles;
  bool isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String serverUrl = 'http://192.168.1.65:5000/signin';

  Future<void> registerUser(
    String name,
    String email,
    String userId,
    String password,
    String phone,
    String address,
    List<PlatformFile> audioFiles,
  ) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'userId': userId,
        'name': name,
        'phone': phone,
        'address': address,
      });

      // Upload audio files to server for speaker model training
      if (audioFiles.isNotEmpty) {
        var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
        request.fields['speaker'] = userId;

        for (var file in audioFiles) {
          Uint8List fileBytes;
          if (file.bytes != null) {
            fileBytes = file.bytes!;
          } else if (file.path != null) {
            fileBytes = await File(file.path!).readAsBytes();
          } else {
            throw Exception('File has no bytes or path: ${file.name}');
          }

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              fileBytes,
              filename: file.name,
              contentType: MediaType('audio', 'wav'),
            ),
          );
        }

        var response = await request.send();
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Registration successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration successful')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to register: ${response.statusCode}')),
          );
          print(await response.stream.bytesToString());
        }
      } else {
        // No audio files selected, handle accordingly
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No audio files selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error registering user: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> pickAudioFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        selectedFiles = result.files;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} files selected')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file selected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: userIdController,
              decoration: InputDecoration(
                labelText: 'User ID',
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
              ),
              validator: (value) {
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'Address',
              ),
              maxLines: null, // Allow multiple lines for address input
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await pickAudioFiles();
              },
              child: Text('Pick Audio Files'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    userIdController.text.isEmpty ||
                    passwordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    addressController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }
                if (selectedFiles != null && selectedFiles!.isNotEmpty) {
                  String name = nameController.text;
                  String email = emailController.text;
                  String userId = userIdController.text;
                  String password = passwordController.text;
                  String phone = phoneController.text;
                  String address = addressController.text;

                  // Call registerUser function
                  registerUser(name, email, userId, password, phone, address, selectedFiles!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No audio files selected')),
                  );
                }
              },
              child: isLoading ? CircularProgressIndicator() : Text('Register'),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
