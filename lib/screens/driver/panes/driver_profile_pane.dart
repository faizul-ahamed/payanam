import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';

class DriverProfilePane extends StatefulWidget {
  final Map<String, dynamic> driverData;
  const DriverProfilePane({super.key, required this.driverData});

  @override
  State<DriverProfilePane> createState() => _DriverProfilePaneState();
}

class _DriverProfilePaneState extends State<DriverProfilePane> {
  late Map<String, dynamic> _data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.driverData);
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _data['fullName']);
    final emailController = TextEditingController(text: _data['email']);
    final phoneController = TextEditingController(text: _data['phone']);
    final licenseController = TextEditingController(text: _data['licenseNumber']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email ID"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: licenseController,
                decoration: const InputDecoration(labelText: "License Number"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newEmail = emailController.text.trim().toLowerCase();
              final newPhone = phoneController.text.trim();
              final newLicense = licenseController.text.trim();
              
              if (newName.isNotEmpty && newEmail.isNotEmpty && newPhone.isNotEmpty && newLicense.isNotEmpty) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(_data['driverId'])
                      .update({
                        'fullName': newName,
                        'email': newEmail,
                        'phone': newPhone,
                        'licenseNumber': newLicense,
                      });

                  // Try to update Firebase Auth email as well
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != newEmail) {
                    await user.verifyBeforeUpdateEmail(newEmail);
                  }

                  setState(() {
                    _data['fullName'] = newName;
                    _data['email'] = newEmail;
                    _data['phone'] = newPhone;
                    _data['licenseNumber'] = newLicense;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 32),
          _buildDetailsSection(context),
          const SizedBox(height: 32),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple, width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primaryPurple,
                backgroundImage: _data['avatarUrl'] != null ? NetworkImage(_data['avatarUrl']) : null,
                child: _data['avatarUrl'] == null 
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  
                  if (image != null) {
                    setState(() => _isLoading = true);
                    try {
                      final url = await AuthService().uploadProfilePhoto(
                        _data['driverId'], 
                        File(image.path), 
                        'driver'
                      );
                      setState(() {
                        _data['avatarUrl'] = url;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Photo updated successfully"))
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Upload failed: $e"))
                      );
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _data['fullName'] ?? 'Driver Name',
              style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryPurple),
              onPressed: _editProfile,
            ),
          ],
        ),
        Text(
          'Driver Grade: Professional',
          style: TextStyle(color: AppColors.primaryPurple.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _buildDetailRow(context, Icons.badge_outlined, 'Driver ID', _data['driverId']),
          _divider(),
          _buildDetailRow(context, Icons.email_outlined, 'Email', _data['email']),
          _divider(),
          _buildDetailRow(context, Icons.phone_outlined, 'Phone', _data['phone']),
          _divider(),
          _buildDetailRow(context, Icons.credit_card_outlined, 'License No', _data['licenseNumber']),
          _divider(),
          _buildDetailRow(context, Icons.directions_bus_outlined, 'Mapped Bus', _data['assignedBus']),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.withValues(alpha: 0.1), height: 1);

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text("Log Out", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
