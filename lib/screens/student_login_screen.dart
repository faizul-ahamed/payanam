import 'package:flutter/material.dart';
import 'auth_template.dart';
import '../theme/app_theme.dart';
import 'student_registration_screen.dart';
import 'student/student_dashboard.dart';
import '../services/auth_service.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await _authService.loginStudent(
          _idController.text.trim(),
          _passwordController.text,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Successful!')),
          );
          // Navigate to Student Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const StudentDashboard()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthTemplate(
      title: 'Student\nLogin',
      subtitle: 'Enter your College ID to track your bus.',
      headerIcon: Icons.school_outlined,
      accentColor: AppColors.primaryPurple,
      onBack: () => Navigator.pop(context),
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            // ID Field
            _buildTextField(
              controller: _idController,
              label: 'College ID',
              hint: 'e.g. 927623BIT033',
              icon: Icons.badge_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your College ID';
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
            
            const SizedBox(height: 12),
            
            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  'Forgot Password?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
            
            // Register Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentRegistrationScreen()),
                    );
                  },
                  child: Text(
                    'Register',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
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

