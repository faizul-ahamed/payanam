import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';

class StudentProfilePane extends StatefulWidget {
  final Map<String, dynamic> studentData;
  const StudentProfilePane({super.key, required this.studentData});

  @override
  State<StudentProfilePane> createState() => _StudentProfilePaneState();
}

class _StudentProfilePaneState extends State<StudentProfilePane> {
  late Map<String, dynamic> _data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.studentData);
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() => _data[key] = value);
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(_data['collegeId'])
          .update({key: value});
    } catch (e) {
      debugPrint("Error updating preference: $e");
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _data['fullName']);
    final emailController = TextEditingController(text: _data['email']);
    final phoneController = TextEditingController(text: _data['phone']);
    final collegeIdController = TextEditingController(text: _data['collegeId']);
    
    // Dropdown value setup
    final List<String> departments = ['CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML', 'MBA', 'MCA'];
    final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    
    String currentDept = _data['department']?.toString().toUpperCase() ?? 'IT';
    if (!departments.contains(currentDept)) currentDept = departments.first;
    
    String currentYear = _data['year']?.toString() ?? '1st Year';
    if (!years.contains(currentYear)) currentYear = years.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Full Name"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email ID"),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Phone Number"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: collegeIdController,
                    decoration: const InputDecoration(labelText: "College ID"),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: currentDept,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setDialogState(() => currentDept = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: currentYear,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setDialogState(() => currentYear = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newEmail = emailController.text.trim().toLowerCase();
                final newPhone = phoneController.text.trim();
                final newCollegeId = collegeIdController.text.trim().toUpperCase();
                final newDept = currentDept;
                final newYear = currentYear;
                
                if (newName.isNotEmpty && newEmail.isNotEmpty && newPhone.isNotEmpty && newCollegeId.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    final oldCollegeId = _data['collegeId'];
                    
                    if (newCollegeId != oldCollegeId) {
                      // Check if exists
                      final exists = await FirebaseFirestore.instance.collection('students').doc(newCollegeId).get();
                      if (exists.exists) {
                        throw 'College ID already registered to another user';
                      }
                      
                      // Migrate data
                      final updatedData = Map<String, dynamic>.from(_data);
                      updatedData['fullName'] = newName;
                      updatedData['email'] = newEmail;
                      updatedData['phone'] = newPhone;
                      updatedData['collegeId'] = newCollegeId;
                      updatedData['department'] = newDept;
                      updatedData['year'] = newYear;

                      await FirebaseFirestore.instance.collection('students').doc(newCollegeId).set(updatedData);
                      await FirebaseFirestore.instance.collection('students').doc(oldCollegeId).delete();
                      
                      // Update user mapping
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'collegeId': newCollegeId});
                      }
                    } else {
                      await FirebaseFirestore.instance
                          .collection('students')
                          .doc(oldCollegeId)
                          .update({
                            'fullName': newName,
                            'email': newEmail,
                            'phone': newPhone,
                            'department': newDept,
                            'year': newYear,
                          });
                    }

                    // Update Firebase Auth email
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && user.email != newEmail) {
                      await user.verifyBeforeUpdateEmail(newEmail);
                    }

                    setState(() {
                      _data['fullName'] = newName;
                      _data['email'] = newEmail;
                      _data['phone'] = newPhone;
                      _data['collegeId'] = newCollegeId;
                      _data['department'] = newDept;
                      _data['year'] = newYear;
                    });
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
          _buildSettingsSection(context),
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
                        _data['collegeId'], 
                        File(image.path), 
                        'student'
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
              _data['fullName'] ?? 'Student Name',
              style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryPurple),
              onPressed: _editProfile,
            ),
          ],
        ),
        Text(
          _data['email'] ?? 'student@mkce.ac.in',
          style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14),
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
          _buildDetailRow(context, Icons.badge_outlined, "College ID", _data['collegeId'] ?? 'N/A'),
          _divider(),
          _buildDetailRow(context, Icons.school_outlined, "Department", _data['department'] ?? 'N/A'),
          _divider(),
          _buildDetailRow(context, Icons.calendar_today_outlined, "Year", _data['year'] ?? 'N/A'),
          _divider(),
          _buildDetailRow(context, Icons.phone_outlined, "Phone", _data['phone'] ?? 'N/A'),
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

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _buildSettingToggle(context, Icons.notifications_active_outlined, "Push Notifications", _data['pushEnabled'] ?? true, (v) => _updatePreference('pushEnabled', v)),
          _divider(),
          _buildSettingToggle(context, Icons.record_voice_over_outlined, "Voice Alerts", _data['voiceEnabled'] ?? true, (v) => _updatePreference('voiceEnabled', v)),
          _divider(),
          _buildSettingToggle(context, Icons.vibration, "Vibration Alerts", _data['vibrationEnabled'] ?? true, (v) => _updatePreference('vibrationEnabled', v)),
        ],
      ),
    );
  }

  Widget _buildSettingToggle(BuildContext context, IconData icon, String title, bool value, Function(bool) onChanged) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryPurple,
          ),
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
