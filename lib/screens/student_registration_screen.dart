import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_template.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deptController = TextEditingController();
  final _yearController = TextEditingController();
  final _collegeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Map<String, dynamic> _busData = {};
  List<String> _routes = [];
  List<String> _stops = [];
  String? _selectedRoute;
  String? _selectedStop;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadBusData();
  }

  Future<void> _loadBusData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/bus_routes.json');
      final data = await json.decode(response);
      setState(() {
        _busData = data;
        _routes = _busData.keys.toList();
      });
    } catch (e) {
      debugPrint('Error loading bus data: $e');
    }
  }

  void _onRouteChanged(String? value) {
    setState(() {
      _selectedRoute = value;
      _selectedStop = null;
      _stops = value != null ? List<String>.from(_busData[value]) : [];
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _yearController.dispose();
    _collegeIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      if (_selectedRoute == null || _selectedStop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select bus route and stop')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        await _authService.registerStudent(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          department: _deptController.text.trim(),
          year: _yearController.text.trim(),
          routeId: _selectedRoute!,
          stopId: _selectedStop!,
          collegeId: _collegeIdController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Please login.')),
          );
          Navigator.pop(context); // Go back to login
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
      title: 'Student\nRegistration',
      subtitle: 'Create your account to access Payanam.',
      headerIcon: Icons.person_add_outlined,
      accentColor: AppColors.primaryPurple,
      onBack: () => Navigator.pop(context),
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'example@college.edu',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '10-digit number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.length < 10 ? 'Invalid phone' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Department',
                    value: _deptController.text.isEmpty ? null : _deptController.text,
                    items: ['CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML', 'MBA', 'MCA'],
                    onChanged: (v) => setState(() => _deptController.text = v!),
                    icon: Icons.business_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Year',
                    value: _yearController.text.isEmpty ? null : _yearController.text,
                    items: ['1st Year', '2nd Year', '3rd Year', '4th Year'],
                    onChanged: (v) => setState(() => _yearController.text = v!),
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Bus Route Dropdown
            _buildDropdown(
              label: 'Bus Route',
              value: _selectedRoute,
              items: _routes,
              onChanged: _onRouteChanged,
              icon: Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 16),
            
            // Bus Stop Dropdown
            _buildDropdown(
              label: 'Bus Stop',
              value: _selectedStop,
              items: _stops,
              onChanged: (v) => setState(() => _selectedStop = v),
              icon: Icons.location_on_outlined,
              enabled: _selectedRoute != null,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _collegeIdController,
              label: 'College ID',
              hint: 'e.g. 927623BIT033',
              icon: Icons.badge_outlined,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                // Regex for 9276 23 BIT 033 format
                if (!RegExp(r'^\d{4}\d{2}[A-Z]{2,3}\d{3}$').hasMatch(v)) {
                  return 'Format: 927623BIT033';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              onTogglePassword: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: '••••••••',
              icon: Icons.lock_reset_outlined,
              isPassword: true,
              isPasswordVisible: _isPasswordVisible,
              validator: (v) => v != _passwordController.text ? 'Mismatch' : null,
            ),
            const SizedBox(height: 32),

            // Register Button
            SizedBox(
              width: double.infinity,
              height: 58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Account', style: AppTextStyles.buttonText),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: AppColors.textMutedDark, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
    bool enabled = true,
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
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled ? onChanged : null,
          isExpanded: true, // Fix overflow
          items: items.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(
              e, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            )
          )).toList(),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textMutedDark, size: 20),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          dropdownColor: AppColors.getSurfaceCardColor(context),
          style: TextStyle(color: AppColors.getTextPrimary(context)),
        ),
      ],
    );
  }
}
