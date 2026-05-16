import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Role persistence constants
  static const String _roleKey = 'user_role';

  Future<void> _saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  Future<void> _clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // Student Registration
  Future<UserCredential?> registerStudent({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String year,
    required String routeId,
    required String stopId,
    required String collegeId,
    required String password,
  }) async {
    try {
      // 1. Normalize IDs and Email
      final normalizedCollegeId = collegeId.trim().toUpperCase();
      final normalizedEmail = email.trim().toLowerCase();

      // 2. Check if College ID already exists
      final studentDoc = await _firestore.collection('students').doc(normalizedCollegeId).get();
      if (studentDoc.exists) {
        throw 'College ID already registered';
      }

      // 3. Create User in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password.trim(),
      );

      // 4. Store Student Data in Firestore
      await _firestore.collection('students').doc(normalizedCollegeId).set({
        'uid': userCredential.user!.uid,
        'fullName': fullName.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'department': department.trim(),
        'year': year.trim(),
        'routeId': routeId.trim(),
        'stopId': stopId.trim(),
        'collegeId': normalizedCollegeId,
        'role': 'student',
        'status': 'active', // Explicitly marked active
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Also maintain a mapping of email to collegeId for login if needed
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': normalizedEmail,
        'collegeId': normalizedCollegeId,
        'role': 'student',
      });

      await _saveRole('student');

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Driver Registration
  Future<String> registerDriver({
    required String fullName,
    required String email,
    required String phone,
    required String licenseNumber,
    required String assignedBus,
    required String routeId,
    required String stopId,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // 1. Create User in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password.trim(),
      );

      // 2. Generate Driver ID: DRV + Year + Random/Counter
      String driverId = 'DRV${DateTime.now().year}${DateTime.now().millisecond.toString().padLeft(3, '0')}';

      // 3. Store Driver Data in Firestore
      await _firestore.collection('drivers').doc(driverId).set({
        'uid': userCredential.user!.uid,
        'fullName': fullName.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'licenseNumber': licenseNumber.trim(),
        'assignedBus': assignedBus.trim(),
        'routeId': routeId.trim(),
        'stopId': stopId.trim(),
        'driverId': driverId,
        'role': 'driver',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Also maintain a mapping
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': normalizedEmail,
        'driverId': driverId,
        'role': 'driver',
      });

      await _saveRole('driver');

      return driverId;
    } catch (e) {
      rethrow;
    }
  }

  // Student Login using College ID
  Future<UserCredential?> loginStudent(String collegeId, String password) async {
    try {
      final normalizedId = collegeId.trim().toUpperCase();
      final studentDoc = await _firestore.collection('students').doc(normalizedId).get();
      
      if (!studentDoc.exists) {
        throw 'Student with ID $normalizedId not found';
      }

      String email = studentDoc.get('email');
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      await _saveRole('student');
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Driver Login using Driver ID or Phone Number
  Future<UserCredential?> loginDriver(String identifier, String password) async {
    try {
      final input = identifier.trim();
      
      // 1. If not already signed in, try anonymous sign-in to bypass "authenticated-only" Firestore rules
      bool wasAnonymous = false;
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
          wasAnonymous = true;
        } catch (e) {
          debugPrint('Anonymous sign-in failed: $e');
          // Proceed anyway, maybe rules are public
        }
      }

      DocumentSnapshot? driverDoc;

      try {
        // 2. Use field-based queries for both ID and Phone
        final queryById = await _firestore
            .collection('drivers')
            .where('driverId', isEqualTo: input.toUpperCase())
            .limit(1)
            .get();

        if (queryById.docs.isNotEmpty) {
          driverDoc = queryById.docs.first;
        } else {
          // Try searching by phone field
          final queryByPhone = await _firestore
              .collection('drivers')
              .where('phone', isEqualTo: input)
              .limit(1)
              .get();

          if (queryByPhone.docs.isNotEmpty) {
            driverDoc = queryByPhone.docs.first;
          }
        }
      } catch (e) {
        if (wasAnonymous) await _auth.signOut();
        rethrow;
      }

      // 3. Sign out from anonymous session before real login
      if (wasAnonymous) await _auth.signOut();

      if (driverDoc == null || !driverDoc.exists) {
        throw 'Driver with ID or Phone Number "$input" not found';
      }

      final data = driverDoc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? data['accountStatus'] ?? 'pending').toString().toLowerCase();

      if (status == 'pending') {
        throw 'Your account is pending admin approval.';
      } else if (status == 'inactive' || status == 'disabled' || status == 'rejected') {
        throw 'Your account has been deactivated or rejected by the administrator.';
      } else if (status != 'approved' && status != 'active') {
        throw 'Your account is not authorized to login.';
      }

      String email = data['email'];
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim()
      );
      await _saveRole('driver');
      return cred;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw 'Access Denied: The app cannot search for this driver. If you are the developer, please ensure Firestore Rules allow read access for authenticated users, or use Email/Password directly.';
      }
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _clearRole();
    await _auth.signOut();
  }

  // Get current user role
  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.get('role');
    }
    return null;
  }

  // Admin Login
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    // Check admins collection
    final doc = await _firestore.collection('admins').doc(uid).get();
    if (doc.exists) {
      final status = (doc.data()?['status'] ?? 'pending').toString().toLowerCase();
      final role = doc.data()?['role'] ?? 'admin';
      
      if (role == 'admin') {
        if (status == 'pending') throw 'Your account is pending Super Admin approval.';
        if (status == 'rejected') throw 'Your account request was rejected.';
      }
      
      await _saveRole(role);
      return cred;
    } else {
      // Legacy fallback or super admin
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final r = userDoc.data()?['role'] ?? 'admin';
        await _saveRole(r);
        return cred;
      }
    }
    
    await _saveRole('admin');
    return cred;
  }

  // Admin Registration with Secret Code
  Future<UserCredential?> registerAdmin({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String secretCode,
  }) async {
    // 1. Verify Secret Code
    final configDoc = await _firestore.collection('config').doc('admin_secret').get();
    if (configDoc.exists) {
      final validCode = configDoc.data()?['code'];
      if (validCode != null && secretCode != validCode) {
        throw 'Invalid Secret Code';
      }
    } else {
      // If no config exists, we accept any code (or reject based on requirements)
      // Throwing here to ensure secure setup.
      if (secretCode != 'PAYANAM@ADMIN123') {
        throw 'Invalid Secret Code';
      }
    }

    // 2. Create User
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = userCredential.user!.uid;
    
    // 3. Store in admins collection
    await _firestore.collection('admins').doc(uid).set({
      'name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'role': 'admin',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // 4. Store in users collection for role map
    await _firestore.collection('users').doc(uid).set({
      'email': email.trim().toLowerCase(),
      'role': 'admin',
    });
    
    return userCredential;
  }

  // Admin: Approve Driver
  Future<void> approveDriver(String driverId) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'status': 'approved',
    });
  }

  // Student: Get details by UID
  Future<Map<String, dynamic>?> getStudentDetails(String uid) async {
    final query = await _firestore.collection('students').where('uid', isEqualTo: uid).get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamStudentDetails(String uid) {
    return _firestore.collection('students')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null);
  }

  // Driver: Get details by UID
  Future<Map<String, dynamic>?> getDriverDetails(String uid) async {
    final query = await _firestore.collection('drivers').where('uid', isEqualTo: uid).get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  Stream<Map<String, dynamic>?> streamDriverDetails(String uid) {
    return _firestore.collection('drivers')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null);
  }

  // Driver: Start Trip
  Future<void> startTrip(String driverId, String busId, String routeId, String session) async {
    await _firestore.collection('trips').doc(driverId).set({
      'driverId': driverId,
      'busId': busId,
      'routeId': routeId,
      'session': session,
      'currentSession': session,
      'status': 'running',
      'startTime': FieldValue.serverTimestamp(),
      'lastLocation': null,
      'currentStopIndex': 0,
      'heading': 0.0,
    });
    
    await _firestore.collection('drivers').doc(driverId).update({
      'tripStatus': 'running',
      'currentSession': session,
    });
  }

  // Driver: Update Location
  Future<void> updateLocation(String driverId, double lat, double lng, {double heading = 0.0, int currentStopIndex = 0}) async {
    await _firestore.collection('trips').doc(driverId).update({
      'lastLocation': GeoPoint(lat, lng),
      'heading': heading,
      'currentStopIndex': currentStopIndex,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  // Driver: End Trip
  Future<void> endTrip(String driverId) async {
    final tripDoc = await _firestore.collection('trips').doc(driverId).get();
    if (tripDoc.exists) {
      await _firestore.collection('trip_history').add({
        ...(tripDoc.data() as Map<String, dynamic>),
        'endTime': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
      await _firestore.collection('trips').doc(driverId).delete();
    }
    
    await _firestore.collection('drivers').doc(driverId).update({
      'tripStatus': 'inactive',
      'currentSession': FieldValue.delete(),
    });
  }

  // Driver: Report Issue
  Future<void> reportIssue(String driverId, String status, String reason) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'tripStatus': status,
      'lastIssue': reason,
    });
    
    final tripDoc = await _firestore.collection('trips').doc(driverId).get();
    if (tripDoc.exists) {
      await _firestore.collection('trips').doc(driverId).update({
        'status': status,
        'issueReason': reason,
      });
    }
  }

  // Common: Send Notification
  Future<void> sendNotification({
    required String routeId,
    required String title,
    required String body,
    required String type, // info, alert, emergency, holiday
  }) async {
    await _firestore.collection('notifications').add({
      'routeId': routeId,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Admin: Delete Notification
  Future<void> deleteNotification(String id) async {
    await _firestore.collection('notifications').doc(id).delete();
  }

  // Common: Get Routes Stream (for dropdowns)
  Stream<List<Map<String, dynamic>>> getRoutesStream() {
    return _firestore.collection('routes').orderBy('routeId').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }

  // Common: Upload Profile Photo
  Future<String> uploadProfilePhoto(String userId, File imageFile, String role) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(role)
          .child('$userId.jpg');

      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore
      String collection;
      String fieldName = 'avatarUrl';
      
      if (role == 'driver') {
        collection = 'drivers';
      } else if (role == 'student') {
        collection = 'students';
      } else {
        collection = 'users'; // Admin
        fieldName = 'photoURL';
      }

      await _firestore.collection(collection).doc(userId).update({
        fieldName: downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Super Admin: Update Email
  Future<void> updateLoginEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
      await _firestore.collection('users').doc(user.uid).update({'email': newEmail});
      await _firestore.collection('admins').doc(user.uid).update({'email': newEmail});
    }
  }

  // Super Admin: Update Password
  Future<void> updateLoginPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }
}
