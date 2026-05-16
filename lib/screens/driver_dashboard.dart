import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'driver/panes/driver_home_pane.dart';
import 'driver/panes/driver_history_pane.dart';
import 'driver/panes/driver_profile_pane.dart';
import 'landing_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  final List<int> _navigationStack = [0];

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getDriverDetails(user.uid);
      if (mounted) {
        setState(() {
          _driverData = data;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.streamDriverDetails(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _driverData == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
           _driverData = snapshot.data;
        }

        if (_driverData == null) {
          return const Scaffold(body: Center(child: Text('Driver data not found.')));
        }

        return PopScope(
          canPop: _selectedIndex == 0 && _navigationStack.length <= 1,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_navigationStack.length > 1) {
              setState(() {
                _navigationStack.removeLast();
                _selectedIndex = _navigationStack.last;
              });
            } else if (_selectedIndex != 0) {
              setState(() {
                _selectedIndex = 0;
                _navigationStack.clear();
                _navigationStack.add(0);
              });
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            appBar: _buildAppBar(context),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                DriverHomePane(driverData: _driverData!),
                DriverHistoryPane(driverId: _driverData!['driverId']),
                DriverProfilePane(driverData: _driverData!),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (_selectedIndex != index) {
                  setState(() {
                    _selectedIndex = index;
                    if (_navigationStack.contains(index)) {
                      _navigationStack.remove(index);
                    }
                    _navigationStack.add(index);
                  });
                }
              },
              backgroundColor: AppColors.getSurfaceCardColor(context),
              selectedItemColor: AppColors.primaryPurple,
              unselectedItemColor: AppColors.textMutedDark,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, 
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 28),
          const SizedBox(width: 8),
          const Text(
            'PAYANAM',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              fontSize: 16,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        const ThemeToggleButton(),
        IconButton(
          onPressed: () async {
            await _authService.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LandingPage()),
                (route) => false,
              );
            }
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
