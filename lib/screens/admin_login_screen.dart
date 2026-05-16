import 'package:flutter/material.dart';
import 'auth_template.dart';
import '../theme/app_theme.dart';
import 'admin_registration_screen.dart';
import '../services/auth_service.dart';
import 'admin_dashboard.dart';
import 'super_admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin Login Successful')),
          );
          
          final role = await _authService.getSavedRole();
          if (role == 'super_admin') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login Failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthTemplate(
      title: 'Admin\nPortal',
      subtitle: 'Access the management dashboard.',
      headerIcon: Icons.shield_outlined,
      accentColor: AppColors.primaryPurple,
      onBack: () => Navigator.pop(context),
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            // Admin Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Admin Email',
              hint: 'admin@payanam.com',
              icon: Icons.admin_panel_settings_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your admin email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onTogglePassword: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            // Login Button
            SizedBox(
              width: double.infinity,
              height: 58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Login', style: AppTextStyles.buttonText),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // New Admin Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'New Admin? ',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.textMutedDark,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminRegistrationScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Register Here',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: AppColors.textMutedDark, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMutedDark,
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: AppColors.getSurfaceCardColor(context),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
