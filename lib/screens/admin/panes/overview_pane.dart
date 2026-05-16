import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/summary_card.dart';
import '../../../widgets/fleet_item.dart';

class OverviewPane extends StatelessWidget {
  final Function(String)? onNavigateToTracking;

  const OverviewPane({super.key, this.onNavigateToTracking});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder: (context, driverSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('trips').where('status', whereIn: ['running', 'delayed', 'breakdown', 'emergency']).snapshots(),
          builder: (context, tripSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, studentSnapshot) {
                int totalBuses = 0;
                int activeTrips = 0;
                int pendingApproval = 0;
                int totalStudents = 0;
                List<DocumentSnapshot> fleetDocs = [];

                if (driverSnapshot.hasError || tripSnapshot.hasError || studentSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Access Denied / Permission Error',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please verify your Firestore Security Rules allow the current user to read these collections.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMutedDark),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => (context as Element).markNeedsBuild(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (driverSnapshot.hasData) {
                  totalBuses = driverSnapshot.data!.docs.length;
                  fleetDocs = driverSnapshot.data!.docs;
                  for (var doc in fleetDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final docStatus = data['status'] ?? data['accountStatus'] ?? 'pending';
                    if (docStatus == 'pending') {
                      pendingApproval++;
                    }
                  }
                }

                if (tripSnapshot.hasData) {
                  activeTrips = tripSnapshot.data!.docs.length;
                }

                if (studentSnapshot.hasData) {
                  totalStudents = studentSnapshot.data!.docs.length;
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Header
                      _buildHeader(context, pendingApproval),
                      
                      const SizedBox(height: 24),
                      
                      // Summary Cards Grid - Adjusted Aspect Ratio to prevent overflow
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Increased height to prevent vertical overflow
                          final double itemWidth = (constraints.maxWidth - 16) / 2;
                          const double itemHeight = 165; // Increased from 145
                          final double aspectRatio = itemWidth / itemHeight;
                          
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: aspectRatio,
                            children: [
                              SummaryCard(
                                title: 'Total Buses',
                                value: totalBuses.toString().padLeft(2, '0'),
                                change: 'Fleet Size',
                                icon: Icons.directions_bus_filled_rounded,
                                color: AppColors.primaryBlue,
                                onTap: () {},
                              ),
                              SummaryCard(
                                title: 'Active Trips',
                                value: activeTrips.toString().padLeft(2, '0'),
                                change: 'Live Now',
                                icon: Icons.alt_route_rounded,
                                color: AppColors.success,
                                onTap: () {},
                              ),
                              SummaryCard(
                                title: 'Students',
                                value: totalStudents.toString().padLeft(2, '0'),
                                change: 'Total Users',
                                icon: Icons.school_rounded,
                                color: AppColors.primaryPurple,
                                onTap: () {},
                              ),
                              SummaryCard(
                                title: 'Pending',
                                value: pendingApproval.toString().padLeft(2, '0'),
                                change: 'New Drivers',
                                icon: Icons.timer_rounded,
                                color: AppColors.warning,
                                onTap: () {},
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Live Fleet Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Live Fleet Overview',
                            style: AppTextStyles.heading1(context).copyWith(fontSize: 20),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      if (fleetDocs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.bus_alert_outlined, size: 48, color: AppColors.textMutedDark.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                const Text('No active fleet data to show.'),
                              ],
                            ),
                          ),
                        )
                      else
                        ...fleetDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          
                          // Check if this driver has an active trip
                          bool isRunning = false;
                          String? tripId;
                          String tripStatusStr = 'inactive';
                          if (tripSnapshot.hasData) {
                            try {
                              final tripDoc = tripSnapshot.data!.docs.firstWhere((trip) => trip.id == doc.id);
                              isRunning = true;
                              tripId = tripDoc.id;
                              tripStatusStr = (tripDoc.data() as Map<String, dynamic>)['status'] ?? 'inactive';
                            } catch (_) {}
                          }
                          
                          BusStatus statusEnum;
                          if (tripStatusStr == 'running') {
                            statusEnum = BusStatus.running;
                          } else if (tripStatusStr == 'delayed') {
                            statusEnum = BusStatus.delayed;
                          } else if (tripStatusStr == 'breakdown' || tripStatusStr == 'emergency') {
                            statusEnum = BusStatus.breakdown;
                          } else {
                            statusEnum = BusStatus.inactive;
                          }
                          
                          return FleetItem(
                            routeName: data['routeId'] ?? 'New Route',
                            currentStop: data['stopId'] ?? 'Start Point',
                            busNumber: '#${data['assignedBus'] ?? '??'}',
                            status: statusEnum,
                            eta: isRunning ? 'In Transit' : 'Offline',
                            onTap: () {
                              if (onNavigateToTracking != null && tripId != null) {
                                onNavigateToTracking!(tripId);
                              }
                            },
                          );
                        }).toList(),
                        
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildHeader(BuildContext context, int pending) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Morning, Admin',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pending > 0 ? AppColors.warning : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pending > 0 ? '$pending Drivers Pending Approval' : 'System Health: Optimal',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: pending > 0 ? AppColors.warning : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
          ),
          child: IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppColors.primaryPurple),
                if (pending > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
