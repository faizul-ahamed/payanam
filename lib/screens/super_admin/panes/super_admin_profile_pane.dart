import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../theme/app_theme.dart';
import '../../../../services/auth_service.dart';

class SuperAdminProfilePane extends StatefulWidget {
  const SuperAdminProfilePane({super.key});

  @override
  State<SuperAdminProfilePane> createState() => _SuperAdminProfilePaneState();
}

class _SuperAdminProfilePaneState extends State<SuperAdminProfilePane> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPasswordVisible = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('admins').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emailController.text = data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
        _photoUrl = data['avatarUrl'] ?? data['photoUrl'];
      } else {
        // Fallback to user email if admin doc doesn't exist yet
        _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
      }
    } catch (e) {
      debugPrint('Failed to load super admin profile: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      // 1. Update Firestore metadata (Name, Phone)
      await _firestore.collection('admins').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Update Email if changed
      if (_emailController.text.trim() != FirebaseAuth.instance.currentUser?.email) {
        await _authService.updateLoginEmail(_emailController.text.trim());
      }

      // 3. Update Password if not empty
      if (_passwordController.text.isNotEmpty) {
        await _authService.updateLoginPassword(_passwordController.text);
        _passwordController.clear();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile and credentials updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('requires-recent-login')) {
          errorMsg = 'This action requires you to logout and login again for security.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $errorMsg'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final downloadUrl = await _authService.uploadProfilePhoto(uid, File(pickedFile.path), 'admin');
        await _firestore.collection('admins').doc(uid).set({
          'avatarUrl': downloadUrl
        }, SetOptions(merge: true));
        setState(() => _photoUrl = downloadUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error));
        }
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildContent(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Super Admin Profile', style: AppTextStyles.heading1(context).copyWith(fontSize: 22)),
          Text('Manage your personal details and secure identity', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                          child: _photoUrl == null
                              ? const Icon(Icons.person_outline, size: 40, color: AppColors.primaryPurple)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryPurple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Change Photo', style: TextStyle(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField('Full Name', _nameController, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('Phone Number', _phoneController, Icons.phone_outlined),
              const SizedBox(height: 16),
              _buildTextField('Login Email', _emailController, Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                'New Password', 
                _passwordController, 
                Icons.lock_outline, 
                isPassword: true,
                hint: 'Leave blank to keep current',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateProfile,
                  icon: _isSaving ? const SizedBox() : const Icon(Icons.save_rounded, size: 20),
                  label: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Note: Changing email/password may require logging in again.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primaryPurple, size: 20),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ) : null,
            filled: true,
            fillColor: AppColors.getBackgroundColor(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
