import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class BusesPane extends StatefulWidget {
  const BusesPane({super.key});

  @override
  State<BusesPane> createState() => _BusesPaneState();
}

class _BusesPaneState extends State<BusesPane> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bus Management',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => _showBusDialog(context, null),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  tooltip: 'Add New Bus',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('buses').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_bus_outlined, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No registered buses found in the fleet.', style: TextStyle(color: AppColors.textMutedDark)),
                    ],
                  ),
                );
              }

              final buses = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: buses.length,
                itemBuilder: (context, index) {
                  final doc = buses[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final busNumber = doc.id;
                  final capacity = data['capacity'] ?? '0';
                  final routeId = data['routeId']?.isEmpty == true ? 'Unassigned' : data['routeId'] ?? 'Unassigned';
                  final driverId = data['driverId']?.isEmpty == true ? 'Unassigned' : data['driverId'] ?? 'Unassigned';
                  final status = data['status'] ?? 'inactive';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceCardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.directions_bus_rounded, 
                            color: _getStatusColor(status),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    busNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_outline, size: 16, color: AppColors.textMutedDark),
                                      const SizedBox(width: 6),
                                      Text('$capacity Seats', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.route_outlined, size: 16, color: AppColors.textMutedDark),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Route: $routeId', 
                                          style: TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 16, color: AppColors.textMutedDark),
                                  const SizedBox(width: 6),
                                  Text('Driver: $driverId', style: TextStyle(color: AppColors.textMutedDark, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.primaryPurple),
                              tooltip: 'Edit Bus Profile',
                              onPressed: () => _showBusDialog(context, doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              tooltip: 'Remove Bus',
                              onPressed: () => _deleteBus(context, busNumber),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'maintenance': return AppColors.error;
      case 'inactive': return AppColors.textMutedDark;
      default: return AppColors.primaryPurple;
    }
  }

  void _showBusDialog(BuildContext context, DocumentSnapshot? doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BusEditorDialog(doc: doc),
    );
  }

  void _deleteBus(BuildContext context, String busNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        title: const Text('Remove Bus Configuration'),
        content: Text('Are you sure you want to permanently delete $busNumber from the active fleet system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                // 1. Validation Logic: Ensure no active trips are utilizing this bus.
                final tripsCheck = await FirebaseFirestore.instance.collection('trips').where('busId', isEqualTo: busNumber).get();
                if (tripsCheck.docs.isNotEmpty) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot remove: Bus is currently assigned to an ongoing running trip!')));
                  }
                  return;
                }

                // 2. Safe to delete
                await FirebaseFirestore.instance.collection('buses').doc(busNumber).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $busNumber from system.')));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete bus: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Remove Bus'),
          ),
        ],
      ),
    );
  }
}

class _BusEditorDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  const _BusEditorDialog({this.doc});

  @override
  State<_BusEditorDialog> createState() => _BusEditorDialogState();
}

class _BusEditorDialogState extends State<_BusEditorDialog> {
  late TextEditingController _busNumberController;
  late TextEditingController _capacityController;
  
  String? _selectedRoute;
  String? _selectedDriver;
  String _selectedStatus = 'active';
  
  List<String> _validRoutes = [];
  List<Map<String, String>> _validDrivers = []; // ID and Name pairs
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() as Map<String, dynamic>?;

    _busNumberController = TextEditingController(text: widget.doc?.id ?? '');
    _capacityController = TextEditingController(text: data?['capacity']?.toString() ?? '');
    
    _selectedRoute = data?['routeId']?.isEmpty == true ? null : data?['routeId'];
    _selectedDriver = data?['driverId']?.isEmpty == true ? null : data?['driverId'];
    _selectedStatus = data?['status'] ?? 'active';
    
    _fetchDependencies();
  }

  Future<void> _fetchDependencies() async {
    try {
      final routesSnap = await FirebaseFirestore.instance.collection('routes').get();
      final driversSnap = await FirebaseFirestore.instance.collection('drivers').get();
      
      final routesList = routesSnap.docs.map((d) => d.id).toList();
      
      List<Map<String, String>> driversList = [];
      for (var d in driversSnap.docs) {
        final driverData = d.data();
        driversList.add({
          'id': d.id,
          'name': driverData['fullName'] ?? d.id,
        });
      }

      // Safely preserve currently assigned references even if they were deleted/archived
      if (_selectedRoute != null && !routesList.contains(_selectedRoute)) {
        routesList.add(_selectedRoute!);
      }
      if (_selectedDriver != null && !driversList.any((d) => d['id'] == _selectedDriver)) {
        driversList.add({'id': _selectedDriver!, 'name': 'Archived Driver ($_selectedDriver)'});
      }

      if (mounted) {
        setState(() {
          _validRoutes = routesList;
          _validDrivers = driversList;
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

    final isEditing = widget.doc != null;

    return AlertDialog(
      backgroundColor: AppColors.getSurfaceCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEditing ? 'Edit Vehicle Profile' : 'Add New Bus'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _busNumberController, 
              decoration: const InputDecoration(labelText: 'Bus/Vehicle Number (e.g., TN-39-BT-1249)'),
              enabled: !isEditing, // Do not allow primary key to change, they must delete and recreate.
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController, 
              decoration: const InputDecoration(labelText: 'Passenger Seating Capacity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRoute,
              decoration: const InputDecoration(labelText: 'Assign Servicing Route'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ..._validRoutes.map((route) => DropdownMenuItem(value: route, child: Text(route))),
              ],
              onChanged: (val) => setState(() => _selectedRoute = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDriver,
              decoration: const InputDecoration(labelText: 'Assign Primary Driver'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned Drop-in')),
                ..._validDrivers.map((driver) => DropdownMenuItem(value: driver['id']!, child: Text('${driver['name']} (${driver['id']})'))),
              ],
              onChanged: (val) => setState(() => _selectedDriver = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Operational Status'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active (In Fleet)')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance (Offline)')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive (Stored)')),
              ],
              onChanged: (val) => setState(() => _selectedStatus = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final busNumber = _busNumberController.text.trim();
            if (busNumber.isEmpty) return; // Basic validation
            
            try {
              if (!isEditing) {
                // Ensure bus doesn't already physically exist logic
                final exists = await FirebaseFirestore.instance.collection('buses').doc(busNumber).get();
                if (exists.exists) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A bus with this Number Plate / Identifier already exists!')));
                   }
                   return;
                }
              }

              // Update primary bus profile
              await FirebaseFirestore.instance.collection('buses').doc(busNumber).set({
                'capacity': _capacityController.text.trim(),
                'routeId': _selectedRoute ?? '',
                'driverId': _selectedDriver ?? '',
                'status': _selectedStatus,
              }, SetOptions(merge: true));

              // Bonus Synchronization Engine: Automatically force-sync drivers `assignedBus` and `routeId` configurations 
              // guaranteeing complete accuracy if a specific primary driver was bound.
              if (_selectedDriver != null && _selectedDriver!.isNotEmpty) {
                 await FirebaseFirestore.instance.collection('drivers').doc(_selectedDriver).update({
                   'assignedBus': busNumber,
                   'routeId': _selectedRoute ?? '',
                 });
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus configuration successfully saved.')));
              }
            } catch (e) {
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
               }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
          child: const Text('Save Configure'),
        ),
      ],
    );
  }
}
