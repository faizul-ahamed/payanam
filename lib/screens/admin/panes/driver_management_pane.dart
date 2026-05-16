import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class DriverManagementPane extends StatelessWidget {
  const DriverManagementPane({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No drivers found.'));
        }

        final drivers = snapshot.data!.docs;
        final pendingDrivers = drivers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final s = data['status'] ?? data['accountStatus'] ?? 'pending';
          return s == 'pending';
        }).toList();
        final activeDrivers = drivers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final s = data['status'] ?? data['accountStatus'] ?? 'pending';
          return s == 'approved' || s == 'active';
        }).toList();
        final inactiveDrivers = drivers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final s = data['status'] ?? data['accountStatus'] ?? 'pending';
          return s == 'inactive' || s == 'rejected';
        }).toList();

        return DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  'Driver Management',
                  style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
                ),
              ),
              TabBar(
                labelColor: AppColors.primaryPurple,
                unselectedLabelColor: AppColors.textMutedDark,
                indicatorColor: AppColors.primaryPurple,
                tabs: [
                  Tab(text: 'Active (${activeDrivers.length})'),
                  Tab(text: 'Pending (${pendingDrivers.length})'),
                  Tab(text: 'Inactive (${inactiveDrivers.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDriverList(context, activeDrivers, listType: 'active'),
                    _buildDriverList(context, pendingDrivers, listType: 'pending'),
                    _buildDriverList(context, inactiveDrivers, listType: 'inactive'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverList(BuildContext context, List<DocumentSnapshot> drivers, {required String listType}) {
    if (drivers.isEmpty) {
      return Center(
        child: Text('No $listType drivers found.', style: TextStyle(color: AppColors.textMutedDark)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final doc = drivers[index];
        final data = doc.data() as Map<String, dynamic>;
        final driverId = doc.id;
        final name = data['fullName'] ?? 'Unknown';
        final bus = data['assignedBus'] ?? 'Unassigned';
        final phone = data['phone'] ?? 'N/A';
        final tripStatus = data['tripStatus'] ?? 'inactive'; // running, inactive
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showDriverProfile(context, doc),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                  backgroundImage: data['avatarUrl'] != null ? NetworkImage(data['avatarUrl']) : null,
                  child: data['avatarUrl'] == null ? const Icon(Icons.person, color: AppColors.primaryPurple) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          if (listType == 'active' && tripStatus == 'running')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('ON TRIP', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('ID: $driverId • Bus: $bus', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                      Text('Ph: $phone', style: TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
                    ],
                  ),
                ),
                if (listType == 'pending')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                        tooltip: 'Approve',
                        onPressed: () => _updateDriverStatus(context, driverId, 'approved'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                        tooltip: 'Reject',
                        onPressed: () => _updateDriverStatus(context, driverId, 'rejected'),
                      ),
                    ],
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDriverProfile(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final driverId = doc.id;
    final status = data['status'] ?? data['accountStatus'] ?? 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.textMutedDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                  backgroundImage: data['avatarUrl'] != null ? NetworkImage(data['avatarUrl']) : null,
                  child: data['avatarUrl'] == null ? const Icon(Icons.person, size: 32, color: AppColors.primaryPurple) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['fullName'] ?? 'Unknown', style: AppTextStyles.heading1(context).copyWith(fontSize: 20)),
                      Text('Driver ID: $driverId', style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    _editDriver(context, doc);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProfileDetailRow(Icons.email_outlined, 'Email', data['email'] ?? 'N/A'),
            _buildProfileDetailRow(Icons.phone_outlined, 'Phone', data['phone'] ?? 'N/A'),
            _buildProfileDetailRow(Icons.badge_outlined, 'License No.', data['licenseNumber'] ?? 'N/A'),
            _buildProfileDetailRow(Icons.directions_bus_outlined, 'Assigned Bus', data['assignedBus'] ?? 'N/A'),
            _buildProfileDetailRow(Icons.route_outlined, 'Assigned Route', data['routeId'] ?? 'N/A'),
            const SizedBox(height: 24),
            Row(
              children: [
                if (status == 'pending') ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _updateDriverStatus(context, driverId, 'approved');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _updateDriverStatus(context, driverId, 'rejected');
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                      child: const Text('Reject'),
                    ),
                  ),
                ] else if (status == 'approved') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _updateDriverStatus(context, driverId, 'inactive');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.block),
                      label: const Text('Deactivate Account'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    ),
                  ),
                ] else if (status == 'inactive' || status == 'rejected') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateDriverStatus(context, driverId, 'approved');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('Activate Account'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMutedDark),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMutedDark)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.success;
      case 'pending': return Colors.orange;
      case 'rejected': return AppColors.error;
      case 'inactive': return AppColors.textMutedDark;
      default: return AppColors.primaryPurple;
    }
  }

  void _editDriver(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => _EditDriverDialog(doc: doc),
    );
  }

  void _updateDriverStatus(BuildContext context, String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(docId).update({
        'status': status,
        'accountStatus': status, // Update both to ensure compatibility
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Driver status updated to ${status.toUpperCase()}.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _EditDriverDialog extends StatefulWidget {
  final DocumentSnapshot doc;
  const _EditDriverDialog({required this.doc});

  @override
  State<_EditDriverDialog> createState() => _EditDriverDialogState();
}

class _EditDriverDialogState extends State<_EditDriverDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _licenseController;
  
  String? _selectedBus;
  String? _selectedRoute;
  
  List<String> _buses = [];
  List<String> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;
    _nameController = TextEditingController(text: data['fullName']);
    _phoneController = TextEditingController(text: data['phone']);
    _licenseController = TextEditingController(text: data['licenseNumber']);
    
    _selectedBus = data['assignedBus'];
    _selectedRoute = data['routeId'];
    
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final busesSnap = await FirebaseFirestore.instance.collection('buses').get();
      final routesSnap = await FirebaseFirestore.instance.collection('routes').get();
      
      final busesList = busesSnap.docs.map((d) => d.id).toList();
      final routesList = routesSnap.docs.map((d) => d.id).toList();

      // Ensure current values are in lists even if deleted, to prevent dropdown errors
      if (_selectedBus != null && _selectedBus!.isNotEmpty && !busesList.contains(_selectedBus)) {
        busesList.add(_selectedBus!);
      }
      if (_selectedRoute != null && _selectedRoute!.isNotEmpty && !routesList.contains(_selectedRoute)) {
        routesList.add(_selectedRoute!);
      }

      if (mounted) {
        setState(() {
          _buses = busesList;
          _routes = routesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.getSurfaceCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Driver Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            const SizedBox(height: 12),
            TextField(controller: _licenseController, decoration: const InputDecoration(labelText: 'License Number')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBus?.isEmpty ?? true ? null : _selectedBus,
              decoration: const InputDecoration(labelText: 'Assigned Bus Number'),
              items: _buses.map((bus) => DropdownMenuItem(value: bus, child: Text(bus))).toList(),
              onChanged: (val) => setState(() => _selectedBus = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRoute?.isEmpty ?? true ? null : _selectedRoute,
              decoration: const InputDecoration(labelText: 'Assigned Route ID'),
              items: _routes.map((route) => DropdownMenuItem(value: route, child: Text(route))).toList(),
              onChanged: (val) => setState(() => _selectedRoute = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('drivers').doc(widget.doc.id).update({
              'fullName': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'licenseNumber': _licenseController.text.trim(),
              'assignedBus': _selectedBus ?? '',
              'routeId': _selectedRoute ?? '',
            });
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver details updated.')));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

