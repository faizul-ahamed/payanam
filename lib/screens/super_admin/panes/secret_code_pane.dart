import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class SecretCodePane extends StatefulWidget {
  const SecretCodePane({super.key});

  @override
  State<SecretCodePane> createState() => _SecretCodePaneState();
}

class _SecretCodePaneState extends State<SecretCodePane> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _fetchCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCode() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('config').doc('admin_secret').get();
      if (doc.exists) {
        _codeController.text = doc.data()?['code'] ?? '';
      }
    } catch (e) {
      debugPrint('Failed to fetch secret code: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code cannot be empty'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('config').doc('admin_secret').set({
        'code': _codeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secret code updated successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update code: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Text('Secret Code Management', style: AppTextStyles.heading1(context).copyWith(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Secure the admin registration portal by requiring this secret passcode during sign-up. Only share this code with authorized operators.',
            style: TextStyle(color: AppColors.textMutedDark, fontSize: 13, height: 1.4),
          ),
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
              Text('Registration Passcode', style: AppTextStyles.heading1(context).copyWith(fontSize: 18)),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                obscureText: _isObscured,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                decoration: InputDecoration(
                  labelText: 'Secret Code',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primaryPurple),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    color: AppColors.textMutedDark,
                    onPressed: () => setState(() => _isObscured = !_isObscured),
                  ),
                  filled: true,
                  fillColor: AppColors.getBackgroundColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateCode,
                  icon: _isLoading ? const SizedBox() : const Icon(Icons.save_rounded, size: 20),
                  label: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
