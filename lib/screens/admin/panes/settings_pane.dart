import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';

class SettingsPane extends StatefulWidget {
  const SettingsPane({super.key});
  @override
  State<SettingsPane> createState() => _SettingsPaneState();
}

class _SettingsPaneState extends State<SettingsPane> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Profile
  bool _isLoadingProfile = true;
  Map<String, dynamic> _adminData = {};

  // Notification settings
  bool _pushEnabled = true;
  bool _delayAlerts = true;
  bool _breakdownAlerts = true;
  bool _arrivalAlerts = true;
  bool _announcements = true;
  String _priorityLevel = 'normal';
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Loading states
  bool _isSavingNotif = false;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _loadNotificationSettings();
  }

  Future<void> _loadAdminProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _adminData = doc.data() ?? {};
      }
      _adminData['email'] = user.email ?? _adminData['email'] ?? '';
      _adminData['displayName'] = user.displayName ?? _adminData['fullName'] ?? _adminData['displayName'] ?? 'Admin';
      _adminData['phone'] = _adminData['phone'] ?? '';
      _adminData['photoURL'] = user.photoURL ?? _adminData['photoURL'] ?? '';
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
    }
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('notifications').get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _pushEnabled = data['pushEnabled'] ?? true;
          _delayAlerts = data['delayAlerts'] ?? true;
          _breakdownAlerts = data['breakdownAlerts'] ?? true;
          _arrivalAlerts = data['arrivalAlerts'] ?? true;
          _announcements = data['announcements'] ?? true;
          _priorityLevel = data['priorityLevel'] ?? 'normal';
          _soundEnabled = data['soundEnabled'] ?? true;
          _vibrationEnabled = data['vibrationEnabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _saveNotificationSettings() async {
    setState(() => _isSavingNotif = true);
    try {
      await _firestore.collection('settings').doc('notifications').set({
        'pushEnabled': _pushEnabled,
        'delayAlerts': _delayAlerts,
        'breakdownAlerts': _breakdownAlerts,
        'arrivalAlerts': _arrivalAlerts,
        'announcements': _announcements,
        'priorityLevel': _priorityLevel,
        'soundEnabled': _soundEnabled,
        'vibrationEnabled': _vibrationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _isSavingNotif = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildProfileSection(),
          const SizedBox(height: 28),
          _buildNotificationSection(),
          const SizedBox(height: 28),
          _buildAboutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: AppTextStyles.heading1(context).copyWith(fontSize: 22)),
              Text('Manage your account & system preferences',
                  style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SECTION: Admin Profile ───
  Widget _buildProfileSection() {
    return _buildSection(
      title: 'Admin Profile',
      icon: Icons.person_rounded,
      children: [
        _buildProfileCard(),
        const SizedBox(height: 16),
        _buildActionTile(
          icon: Icons.edit_rounded,
          title: 'Edit Profile',
          subtitle: 'Update name, phone number',
          color: AppColors.primaryPurple,
          onTap: () => _showEditProfileDialog(),
        ),
        _buildActionTile(
          icon: Icons.lock_rounded,
          title: 'Change Password',
          subtitle: 'Update your login password',
          color: AppColors.warning,
          onTap: () => _showChangePasswordDialog(),
        ),
        _buildActionTile(
          icon: Icons.email_rounded,
          title: 'Update Email',
          subtitle: _adminData['email'] ?? 'Not set',
          color: AppColors.primaryBlue,
          onTap: () => _showUpdateEmailDialog(),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final name = _adminData['displayName'] ?? 'Admin';
    final email = _adminData['email'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: (_adminData['photoURL'] != null && _adminData['photoURL'].toString().isNotEmpty) 
                    ? NetworkImage(_adminData['photoURL']) 
                    : null,
                child: (_adminData['photoURL'] == null || _adminData['photoURL'].toString().isEmpty)
                    ? Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() => _isLoadingProfile = true);
                      try {
                        final user = _auth.currentUser;
                        if (user != null) {
                          final url = await AuthService().uploadProfilePhoto(user.uid, File(image.path), 'admin');
                          await user.updatePhotoURL(url);
                          setState(() => _adminData['photoURL'] = url);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile photo updated'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      } catch (e) {
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
                            );
                          }
                      } finally {
                        if (mounted) setState(() => _isLoadingProfile = false);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.primaryPurple),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ADMINISTRATOR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION: Notification Settings ───
  Widget _buildNotificationSection() {
    return _buildSection(
      title: 'Notification Settings',
      icon: Icons.notifications_rounded,
      trailing: _isSavingNotif
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple))
          : TextButton(
              onPressed: _saveNotificationSettings,
              child: const Text('Save', style: TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
            ),
      children: [
        _buildSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: 'Push Notifications',
          subtitle: 'Enable/disable all push notifications globally',
          value: _pushEnabled,
          onChanged: (v) => setState(() => _pushEnabled = v),
          color: AppColors.primaryPurple,
        ),
        if (_pushEnabled) ...[
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text('Alert Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          _buildSwitchTile(
            icon: Icons.timer_rounded,
            title: 'Delay Alerts',
            subtitle: 'Notify when buses are delayed',
            value: _delayAlerts,
            onChanged: (v) => setState(() => _delayAlerts = v),
            color: AppColors.warning,
          ),
          _buildSwitchTile(
            icon: Icons.car_crash_rounded,
            title: 'Breakdown Alerts',
            subtitle: 'Emergency and breakdown notifications',
            value: _breakdownAlerts,
            onChanged: (v) => setState(() => _breakdownAlerts = v),
            color: AppColors.error,
          ),
          _buildSwitchTile(
            icon: Icons.place_rounded,
            title: 'Arrival Notifications',
            subtitle: 'Bus arrival at stops & destination',
            value: _arrivalAlerts,
            onChanged: (v) => setState(() => _arrivalAlerts = v),
            color: AppColors.success,
          ),
          _buildSwitchTile(
            icon: Icons.campaign_rounded,
            title: 'General Announcements',
            subtitle: 'Holiday notices and system updates',
            value: _announcements,
            onChanged: (v) => setState(() => _announcements = v),
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 8),
          _buildPrioritySelector(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text('Delivery Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          _buildSwitchTile(
            icon: Icons.volume_up_rounded,
            title: 'Sound',
            subtitle: 'Play notification sound',
            value: _soundEnabled,
            onChanged: (v) => setState(() => _soundEnabled = v),
            color: AppColors.primaryPurple,
          ),
          _buildSwitchTile(
            icon: Icons.vibration_rounded,
            title: 'Vibration',
            subtitle: 'Vibrate on notification',
            value: _vibrationEnabled,
            onChanged: (v) => setState(() => _vibrationEnabled = v),
            color: AppColors.primaryPurple,
          ),
        ],
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              const Text('Default Priority Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _priorityChip('normal', 'Normal', AppColors.success),
              const SizedBox(width: 8),
              _priorityChip('high', 'High', AppColors.warning),
              const SizedBox(width: 8),
              _priorityChip('urgent', 'Urgent', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    final isSelected = _priorityLevel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priorityLevel = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppColors.getBorderColor(context).withValues(alpha: 0.3), width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(
                value == 'normal' ? Icons.arrow_downward_rounded : (value == 'high' ? Icons.arrow_upward_rounded : Icons.warning_rounded),
                color: isSelected ? color : AppColors.textMutedDark,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: isSelected ? color : AppColors.textMutedDark,
                fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION: About ───
  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About Payanam',
      icon: Icons.info_rounded,
      children: [
        _buildInfoTile(Icons.apps_rounded, 'App Version', '1.0.0'),
        _buildInfoTile(Icons.cloud_rounded, 'Backend', 'Firebase (Firestore/Auth)'),
        _buildInfoTile(Icons.school_rounded, 'Institution', 'MKCE College'),
        _buildInfoTile(Icons.code_rounded, 'Platform', 'Flutter / Dart'),
      ],
    );
  }

  // ─── Reusable Section Container ───
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: AppTextStyles.heading1(context).copyWith(fontSize: 17)),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  // ─── Reusable Tiles ───
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.textMutedDark, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: AppColors.textMutedDark, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text(value, style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── DIALOGS ───

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _adminData['displayName'] ?? '');
    final phoneController = TextEditingController(text: _adminData['phone'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(nameController, 'Full Name', Icons.person_rounded),
              const SizedBox(height: 16),
              _dialogTextField(phoneController, 'Phone Number', Icons.phone_rounded),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                try {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await user.updateDisplayName(nameController.text.trim());
                    await _firestore.collection('users').doc(user.uid).set({
                      'fullName': nameController.text.trim(),
                      'displayName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                    }, SetOptions(merge: true));

                    setState(() {
                      _adminData['displayName'] = nameController.text.trim();
                      _adminData['phone'] = phoneController.text.trim();
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
                setDialogState(() => isSaving = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(currentPwdController, 'Current Password', Icons.lock_outline, obscure: true),
              const SizedBox(height: 16),
              _dialogTextField(newPwdController, 'New Password', Icons.lock_rounded, obscure: true),
              const SizedBox(height: 16),
              _dialogTextField(confirmPwdController, 'Confirm New Password', Icons.lock_rounded, obscure: true),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (newPwdController.text.length < 6) {
                  setDialogState(() => errorMsg = 'Password must be at least 6 characters');
                  return;
                }
                if (newPwdController.text != confirmPwdController.text) {
                  setDialogState(() => errorMsg = 'Passwords do not match');
                  return;
                }
                setDialogState(() { isSaving = true; errorMsg = null; });
                try {
                  final user = _auth.currentUser;
                  if (user != null && user.email != null) {
                    final cred = EmailAuthProvider.credential(email: user.email!, password: currentPwdController.text);
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPwdController.text);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppColors.success),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  setDialogState(() {
                    if (e.code == 'wrong-password') {
                      errorMsg = 'Current password is incorrect';
                    } else {
                      errorMsg = e.message ?? 'Failed to change password';
                    }
                  });
                } catch (e) {
                  setDialogState(() => errorMsg = e.toString());
                }
                setDialogState(() => isSaving = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateEmailDialog() {
    final emailController = TextEditingController(text: _adminData['email'] ?? '');
    final pwdController = TextEditingController();
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceCardColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Update Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(emailController, 'New Email', Icons.email_rounded),
              const SizedBox(height: 16),
              _dialogTextField(pwdController, 'Current Password', Icons.lock_outline, obscure: true),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
                  setDialogState(() => errorMsg = 'Please enter a valid email');
                  return;
                }
                setDialogState(() { isSaving = true; errorMsg = null; });
                try {
                  final user = _auth.currentUser;
                  if (user != null && user.email != null) {
                    final cred = EmailAuthProvider.credential(email: user.email!, password: pwdController.text);
                    await user.reauthenticateWithCredential(cred);
                    await user.verifyBeforeUpdateEmail(emailController.text.trim());
                    await _firestore.collection('users').doc(user.uid).update({
                      'email': emailController.text.trim(),
                    });
                    setState(() => _adminData['email'] = emailController.text.trim());
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent. Check your inbox.'), backgroundColor: AppColors.success),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  setDialogState(() => errorMsg = e.message ?? 'Failed to update email');
                } catch (e) {
                  setDialogState(() => errorMsg = e.toString());
                }
                setDialogState(() => isSaving = false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: AppColors.getTextPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMutedDark),
        filled: true,
        fillColor: AppColors.getBackgroundColor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
