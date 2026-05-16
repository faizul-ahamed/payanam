import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class StudentHomePane extends StatelessWidget {
  final Map<String, dynamic> studentData;
  final Function(int)? onActionTap;
  const StudentHomePane({super.key, required this.studentData, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(context),
          const SizedBox(height: 24),
          _buildInfoCard(context),
          const SizedBox(height: 24),
          _buildStatsRow(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, "Quick Actions"),
          const SizedBox(height: 16),
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: AppTextStyles.bodyMedium(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        Text(
          studentData['fullName'] ?? 'Student',
          style: AppTextStyles.heading1(context).copyWith(fontSize: 28),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.school, color: Colors.white, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  studentData['collegeId'] ?? 'N/A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow("Department", studentData['department'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildInfoRow("Assigned Route", studentData['routeId'] ?? 'Not Assigned'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoRow("Assigned Stop", studentData['stopId'] ?? 'Not Assigned')),
              _buildSeatBadge(studentData['seatNumber']?.toString() ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatBadge(String seat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('SEAT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(seat, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final String studentRouteId = studentData['routeId'] ?? '';
    final String studentRouteNum = studentRouteId.contains(' - ') 
        ? studentRouteId.split(' - ').first.trim() 
        : studentRouteId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('trips')
          .where('status', isEqualTo: 'running')
          .snapshots(),
      builder: (context, snapshot) {
        String todayStatus = "Offline";
        IconData statusIcon = Icons.timer_outlined;
        Color statusColor = AppColors.textMutedDark;
        
        String nextTrip = "Morning";
        IconData tripIcon = Icons.wb_sunny_outlined;
        Color tripColor = AppColors.warning;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // Find the trip that matches this student's route (fuzzy match)
          final matchingTrips = snapshot.data!.docs.where((doc) {
            final tripRouteId = (doc.data() as Map<String, dynamic>)['routeId']?.toString() ?? '';
            return tripRouteId == studentRouteId || 
                   tripRouteId == studentRouteNum ||
                   studentRouteId.startsWith(tripRouteId) ||
                   tripRouteId.startsWith(studentRouteId);
          });

          if (matchingTrips.isNotEmpty) {
            final trip = matchingTrips.first.data() as Map<String, dynamic>;
            final status = trip['status'] ?? 'inactive';
            final session = trip['currentSession'] ?? trip['session'] ?? 'Morning';

            if (status == 'running') {
              todayStatus = "On Time";
              statusColor = AppColors.success;
            } else if (status == 'delayed') {
              todayStatus = "Delayed";
              statusColor = AppColors.warning;
            } else if (status == 'breakdown') {
              todayStatus = "Critical";
              statusColor = AppColors.error;
            }

            nextTrip = session == 'Morning' ? 'Evening' : 'Morning';
            tripIcon = session == 'Morning' ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined;
            tripColor = session == 'Morning' ? AppColors.primaryBlue : AppColors.warning;
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                "Today's Status",
                todayStatus,
                statusIcon,
                statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                "Next Trip",
                nextTrip,
                tripIcon,
                tripColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.heading1(context).copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: AppTextStyles.heading1(context).copyWith(fontSize: 20),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildActionCard(context, "Track Bus", Icons.map_outlined, AppColors.primaryPurple, () => onActionTap?.call(1)),
        _buildActionCard(context, "Stop List", Icons.list_alt_rounded, AppColors.primaryBlue, () => onActionTap?.call(1)),
        _buildActionCard(context, "Notifications", Icons.notifications_none_rounded, AppColors.warning, () => onActionTap?.call(2)),
        _buildActionCard(context, "Support", Icons.headset_mic_outlined, AppColors.error, () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Support chat coming soon!")));
        }),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
