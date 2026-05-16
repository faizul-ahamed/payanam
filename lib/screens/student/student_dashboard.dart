import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/theme_toggle_button.dart';
import 'panes/student_home_pane.dart';
import 'panes/student_track_pane.dart';
import 'panes/student_notifications_pane.dart';
import 'panes/student_profile_pane.dart';
import '../landing_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  final List<int> _navigationStack = [0];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getStudentDetails(user.uid);
      if (mounted) {
        setState(() {
          _studentData = data;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.streamStudentDetails(FirebaseAuth.instance.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _studentData == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        _studentData = snapshot.data;

        if (_studentData == null) {
          return const Scaffold(
            body: Center(child: Text('Student data not found. Please log in again.')),
          );
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
            appBar: AppBar(
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
            ),
            body: _buildBody(),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: BottomNavigationBar(
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
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                  BottomNavigationBarItem(icon: Icon(Icons.location_on_rounded), label: 'Track'),
                  BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alerts'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _changeTab(int index) {
    if (mounted && _selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
        if (_navigationStack.contains(index)) {
          _navigationStack.remove(index);
        }
        _navigationStack.add(index);
      });
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        StudentHomePane(
          studentData: _studentData!,
          onActionTap: _changeTab,
        ),
        StudentTrackPane(studentData: _studentData!),
        StudentNotificationsPane(studentData: _studentData!),
        StudentProfilePane(studentData: _studentData!),
      ],
    );
  }
}
