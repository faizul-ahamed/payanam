import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'super_admin/panes/admin_list_pane.dart';
import 'super_admin/panes/secret_code_pane.dart';
import 'super_admin/panes/super_admin_profile_pane.dart';
import 'landing_page.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  final List<String> _titles = [
    'Admin List',
    'Secret Code',
    'Profile',
  ];

  Widget _getDetailPane() {
    switch (_selectedIndex) {
      case 0: return const AdminListPane();
      case 1: return const SecretCodePane();
      case 2: return const SuperAdminProfilePane();
      default: return const AdminListPane();
    }
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const LandingPage();
    }
    
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppColors.getSurfaceCardColor(context),
              elevation: 0,
              centerTitle: true,
              title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  onPressed: _handleLogout,
                )
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.getSurfaceCardColor(context), // Opaque background
              child: _buildDrawerContent(),
            )
          : null,
      body: SafeArea(
        child: isMobile
            ? _getDetailPane()
            : Row(
                children: [
                  Container(
                    width: 250,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceCardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
                    ),
                    child: _buildDrawerContent(),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.getBackgroundColor(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _getDetailPane(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: isMobile 
        ? BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.getSurfaceCardColor(context),
            selectedItemColor: AppColors.primaryPurple,
            unselectedItemColor: AppColors.textMutedDark,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admins'),
              BottomNavigationBarItem(icon: Icon(Icons.vpn_key), label: 'Secret Code'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
        )
        : null,
    );
  }

  Widget _buildDrawerContent() {
    return Column(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.security_rounded, size: 48, color: AppColors.primaryPurple),
        const SizedBox(height: 16),
        const Text('Super Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
        const Text('Payanam Control Layer', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 40),
        _drawerItem(0, Icons.admin_panel_settings_outlined, 'Admin List'),
        _drawerItem(1, Icons.vpn_key_outlined, 'Secret Code'),
        _drawerItem(2, Icons.person_outline, 'Profile'),
        const Spacer(),
        Divider(color: AppColors.getBorderColor(context).withValues(alpha: 0.5), height: 1),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: const Icon(Icons.logout_rounded, color: AppColors.error),
          title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          onTap: _handleLogout,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryPurple.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primaryPurple : AppColors.textMutedDark),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primaryPurple : AppColors.textMutedDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (MediaQuery.of(context).size.width < 900) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}
