import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_template.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _busNumberController = TextEditingController();
  final _addressController = TextEditingController();
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
      // Also update bus number if it matches route name or similar,
      // but usually bus number refers to the physical vehicle.
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _licenseExpiryController.dispose();
    _busNumberController.dispose();
    _addressController.dispose();
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
          const SnackBar(content: Text('Please select bus route and starting stop')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        String driverId = await _authService.registerDriver(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          assignedBus: _busNumberController.text.trim(),
          routeId: _selectedRoute!,
          stopId: _selectedStop!,
          password: _passwordController.text,
        );

        if (mounted) {
          _showGeneratedIdDialog(driverId);
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

  void _showGeneratedIdDialog(String driverId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        title: const Text('Registration Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your account has been created. Please use the following ID to login:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryBlue),
              ),
              child: Center(
                child: Text(
                  driverId,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to login
            },
            child: const Text('OKAY, LOGIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthTemplate(
      title: 'Driver\nRegistration',
      subtitle: 'Join the Payanam team as a driver.',
      headerIcon: Icons.drive_eta_outlined,
      accentColor: AppColors.primaryBlue,
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
              accentColor: AppColors.primaryBlue,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'example@email.com',
              icon: Icons.email_outlined,
              accentColor: AppColors.primaryBlue,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '10-digit number',
              icon: Icons.phone_outlined,
              accentColor: AppColors.primaryBlue,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.length < 10 ? 'Invalid phone' : null,
            ),
            const SizedBox(height: 16),

            // Bus Route Dropdown
            _buildDropdown(
              label: 'Assigned Bus Route',
              value: _selectedRoute,
              items: _routes,
              onChanged: _onRouteChanged,
              icon: Icons.directions_bus_outlined,
            ),
            const SizedBox(height: 16),
            
            // Bus Stop Dropdown
            _buildDropdown(
              label: 'Starting Point / Depot',
              value: _selectedStop,
              items: _stops,
              onChanged: (v) => setState(() => _selectedStop = v),
              icon: Icons.location_on_outlined,
              enabled: _selectedRoute != null,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _busNumberController,
              label: 'Vehicle Number',
              hint: 'e.g. TN33 AJ 1234',
              icon: Icons.local_shipping_outlined,
              accentColor: AppColors.primaryBlue,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _licenseController,
              label: 'License Number',
              hint: 'Enter DL number',
              icon: Icons.badge_outlined,
              accentColor: AppColors.primaryBlue,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _licenseExpiryController,
              label: 'License Expiry Date',
              hint: 'DD/MM/YYYY',
              icon: Icons.calendar_today_outlined,
              accentColor: AppColors.primaryBlue,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Address',
              hint: 'Enter your full address',
              icon: Icons.home_outlined,
              accentColor: AppColors.primaryBlue,
              maxLines: 3,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              accentColor: AppColors.primaryBlue,
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
              accentColor: AppColors.primaryBlue,
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
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    : const Text('Register', style: AppTextStyles.buttonText),
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
    required Color accentColor,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
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
          maxLines: maxLines,
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
              borderSide: BorderSide(color: accentColor, width: 1.5),
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
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
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
