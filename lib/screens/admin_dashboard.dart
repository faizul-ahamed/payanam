import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/theme_toggle_button.dart';
import 'admin/panes/overview_pane.dart';
import 'admin/panes/tracking_pane.dart';
import 'admin/panes/buses_pane.dart';
import 'admin/panes/routes_pane.dart';
import 'admin/panes/student_management_pane.dart';
import 'admin/panes/driver_management_pane.dart';
import 'admin/panes/notifications_pane.dart';
import 'admin/panes/reports_pane.dart';
import 'admin/panes/tracking_history_pane.dart';
import 'admin/panes/settings_pane.dart';
import 'landing_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<int> _navigationStack = [0];

  final List<String> _titles = [
    'Dashboard',
    'Live Tracking',
    'Bus Management',
    'Route Management',
    'Driver Management',
    'Student Management',
    'Notifications',
    'Reports',
    'Tracking History',
    'Settings',
  ];

  String? _pendingTripId;

  Widget _getContent() {
    switch (_selectedIndex) {
      case 0: return OverviewPane(
        onNavigateToTracking: (tripId) {
          setState(() {
            _selectedIndex = 1;
            _pendingTripId = tripId;
            if (!_navigationStack.contains(1)) {
              _navigationStack.add(1);
            }
          });
        },
      );
      case 1: 
        final tp = TrackingPane(initialTripId: _pendingTripId);
        _pendingTripId = null; // clear after passing
        return tp;
      case 2: return const BusesPane();
      case 3: return const RoutesPane();
      case 4: return const DriverManagementPane();
      case 5: return const StudentManagementPane();
      case 6: return const NotificationsPane();
      case 7: return const ReportsPane();
      case 8: return const TrackingHistoryPane();
      case 9: return const SettingsPane();
      default: return OverviewPane(
        onNavigateToTracking: (tripId) {
          setState(() {
            _selectedIndex = 1;
            _pendingTripId = tripId;
            if (!_navigationStack.contains(1)) {
              _navigationStack.add(1);
            }
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

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
        key: _scaffoldKey,
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            _titles[_selectedIndex],
            style: AppTextStyles.heading1(context).copyWith(fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.primaryPurple),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            const ThemeToggleButton(),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await AuthService().signOut();
                if (!mounted) return;
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LandingPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _buildDrawer(),
        body: _getContent(),
        floatingActionButton: _selectedIndex == 5
            ? FloatingActionButton(
                onPressed: () => _handleFABPressed(),
                backgroundColor: AppColors.primaryPurple,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        bottomNavigationBar: isMobile ? BottomNavigationBar(
          currentIndex: _selectedIndex < 2 ? _selectedIndex : (_selectedIndex == 7 ? 2 : (_selectedIndex == 9 ? 3 : 0)),
          onTap: (index) {
            int targetIndex = 0;
            if (index == 0) targetIndex = 0;
            if (index == 1) targetIndex = 1;
            if (index == 2) targetIndex = 7; // Reports
            if (index == 3) targetIndex = 9; // Settings
            
            if (_selectedIndex != targetIndex) {
              setState(() {
                _selectedIndex = targetIndex;
                if (_navigationStack.contains(targetIndex)) {
                  _navigationStack.remove(targetIndex);
                }
                _navigationStack.add(targetIndex);
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.getSurfaceCardColor(context),
          selectedItemColor: AppColors.primaryPurple,
          unselectedItemColor: AppColors.textMutedDark,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Tracking'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ) : null,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.getBackgroundColor(context),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 60),
                  const SizedBox(height: 12),
                  const Text(
                    'Payanam Admin',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(0, Icons.dashboard_outlined, 'Dashboard'),
                _drawerItem(1, Icons.location_on_outlined, 'Live Tracking'),
                _drawerItem(2, Icons.directions_bus_outlined, 'Buses'),
                _drawerItem(3, Icons.route_outlined, 'Routes'),
                _drawerItem(4, Icons.badge_outlined, 'Drivers'),
                _drawerItem(5, Icons.school_outlined, 'Students'),
                _drawerItem(6, Icons.notifications_active_outlined, 'Notifications'),
                _drawerItem(7, Icons.analytics_outlined, 'Reports'),
                _drawerItem(8, Icons.history_rounded, 'Tracking History'),
                const Divider(color: Colors.white12),
                _drawerItem(9, Icons.settings_outlined, 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primaryPurple : AppColors.textMutedDark),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primaryPurple : AppColors.getTextPrimary(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
            if (_navigationStack.contains(index)) {
              _navigationStack.remove(index);
            }
            _navigationStack.add(index);
          });
        }
        Navigator.pop(context);
      },
    );
  }

  void _handleFABPressed() {
    String entity = '';
    switch (_selectedIndex) {
      case 2: entity = 'Bus/Driver'; break;
      case 3: entity = 'Route'; break;
      case 4: entity = 'Driver'; break;
      case 5: entity = 'Student'; break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        title: Text('Add New $entity'),
        content: Text('Form to manually create a new $entity will be integrated here.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
