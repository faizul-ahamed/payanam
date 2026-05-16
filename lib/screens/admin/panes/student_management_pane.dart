import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';

class StudentManagementPane extends StatefulWidget {
  const StudentManagementPane({super.key});

  @override
  State<StudentManagementPane> createState() => _StudentManagementPaneState();
}

class _StudentManagementPaneState extends State<StudentManagementPane> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRouteFilter;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildFilters(context),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('students').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
              }

              final allStudents = snapshot.data?.docs ?? [];
              
              // Local Filtering
              final filteredStudents = allStudents.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['fullName'] ?? '').toString().toLowerCase();
                final collegeId = (data['collegeId'] ?? '').toString().toLowerCase();
                final route = (data['routeId'] ?? '').toString();
                
                bool matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                                     collegeId.contains(_searchQuery.toLowerCase());
                bool matchesRoute = _selectedRouteFilter == null || route == _selectedRouteFilter;
                
                return matchesSearch && matchesRoute;
              }).toList();

              if (filteredStudents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: AppColors.textMutedDark.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isEmpty ? 'No registered students found' : 'No students matching filters', 
                        style: TextStyle(color: AppColors.textMutedDark)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: filteredStudents.length,
                itemBuilder: (context, index) {
                  final doc = filteredStudents[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildStudentCard(context, doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Student Management',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('students').snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Text(
                      '$count Total Students',
                      style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by Name or College ID...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryPurple),
              filled: true,
              fillColor: AppColors.getSurfaceCardColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('routes').snapshots(),
        builder: (context, snapshot) {
          final routes = snapshot.data?.docs ?? [];
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildFilterChip(null, 'All Routes'),
              ...routes.map((r) {
                final name = (r.data() as Map<String, dynamic>)['name'] ?? r.id;
                return _buildFilterChip(name, name);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    bool isSelected = _selectedRouteFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedRouteFilter = selected ? value : null);
        },
        selectedColor: AppColors.primaryPurple,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textMutedDark,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: AppColors.getSurfaceCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: isSelected ? AppColors.primaryPurple : AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['accountStatus'] ?? data['status'] ?? 'active';
    final isActive = status == 'active' || status == 'approved';
    final seatNum = data['seatNumber'] ?? 'N/A';
    final gender = data['gender'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                child: Text(
                  (data['fullName'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.getSurfaceCardColor(context), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['fullName'] ?? 'Unknown Student',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID: ${data['collegeId'] ?? docId} • ${data['department'] ?? 'Dept'} • ${data['yearOfStudy'] ?? 'Year'}',
                  style: TextStyle(color: AppColors.textMutedDark, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Route: ${data['routeId'] ?? 'Unassigned'}',
                          style: const TextStyle(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Stop: ${data['stopId'] ?? 'N/A'}',
                        style: TextStyle(color: AppColors.textMutedDark.withValues(alpha: 0.8), fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (gender == 'Female' ? Colors.pink : Colors.blue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('SEAT', style: TextStyle(fontSize: 8, color: gender == 'Female' ? Colors.pink : Colors.blue, fontWeight: FontWeight.bold)),
                    Text(seatNum, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildIconButton(Icons.edit_note_rounded, AppColors.primaryPurple, () => _showEditDialog(context, docId, data)),
                  const SizedBox(width: 4),
                  _buildIconButton(
                    isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, 
                    isActive ? AppColors.error : AppColors.success, 
                    () => _toggleAccountStatus(docId, isActive)
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _toggleAccountStatus(String docId, bool currentActive) async {
    final status = currentActive ? 'disabled' : 'active';
    await FirebaseFirestore.instance.collection('students').doc(docId).update({
      'accountStatus': status,
      'status': status,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account ${currentActive ? "deactivated" : "activated"}')));
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _StudentEditDialog(docId: docId, studentData: data),
    );
  }
}

class _StudentEditDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> studentData;
  const _StudentEditDialog({required this.docId, required this.studentData});

  @override
  State<_StudentEditDialog> createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<_StudentEditDialog> {
  late String _selectedRoute;
  String? _selectedStop;
  late String _selectedDepartment;
  late String _selectedYear;
  late String _gender;
  List<String> _routes = [];
  List<String> _stops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedRoute = widget.studentData['routeId'] ?? '';
    _selectedStop = widget.studentData['stopId'];
    
    // Fix: Red screen error for case-sensitive or missing values
    final deptList = ['CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML', 'MBA', 'MCA'];
    final rawDept = (widget.studentData['department'] ?? 'IT').toString().toUpperCase();
    _selectedDepartment = deptList.contains(rawDept) ? rawDept : 'IT';

    final yearList = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    final rawYear = widget.studentData['yearOfStudy'] ?? '1st Year';
    _selectedYear = yearList.contains(rawYear) ? rawYear : '1st Year';

    _gender = widget.studentData['gender'] ?? 'Female';
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    final snap = await FirebaseFirestore.instance.collection('routes').get();
    setState(() {
      _routes = snap.docs.map((d) => (d.data() as Map<String, dynamic>)['name']?.toString() ?? d.id).toList();
      // Ensure the current selected route exists in the list to avoid dropdown errors
      if (_selectedRoute.isNotEmpty && !_routes.contains(_selectedRoute)) {
        _selectedRoute = '';
      }
      _isLoading = false;
    });
    if (_selectedRoute.isNotEmpty) _updateStops(_selectedRoute);
  }

  Future<void> _updateStops(String routeName) async {
    final snap = await FirebaseFirestore.instance.collection('routes').where('name', isEqualTo: routeName).limit(1).get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      final List rawStops = data['stops'] ?? [];
      setState(() {
        _stops = rawStops.map((s) => s['name'].toString()).toList();
        if (_selectedStop != null && !_stops.contains(_selectedStop)) _selectedStop = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.getSurfaceCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit Student Profile'),
      content: _isLoading ? const Center(child: CircularProgressIndicator()) : SizedBox(
        width: MediaQuery.of(context).size.width * 0.9, // Constrain width
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               DropdownButtonFormField<String>(
                value: _selectedDepartment,
                isExpanded: true, // Fix overflow
                decoration: const InputDecoration(labelText: 'Department'),
                items: ['CSE', 'IT', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML', 'MBA', 'MCA'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _selectedDepartment = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                 value: _selectedYear,
                 isExpanded: true, // Fix overflow
                 decoration: const InputDecoration(labelText: 'Year of Study'),
                 items: ['1st Year', '2nd Year', '3rd Year', '4th Year'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                 onChanged: (v) => setState(() => _selectedYear = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                 value: _gender,
                 isExpanded: true, // Fix overflow
                 decoration: const InputDecoration(labelText: 'Gender'),
                 items: ['Female', 'Male'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                 onChanged: (v) => setState(() => _gender = v!),
              ),
               const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRoute.isEmpty ? null : _selectedRoute,
                isExpanded: true, // Fix overflow
                decoration: const InputDecoration(labelText: 'Assigned Route'),
                items: _routes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) {
                  setState(() => _selectedRoute = v!);
                  _updateStops(v!);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedStop,
                isExpanded: true, // Fix overflow
                decoration: const InputDecoration(labelText: 'Assigned Stop'),
                items: _stops.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _selectedStop = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveStudent,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Update Student'),
        ),
      ],
    );
  }

  bool _isSaving = false;

  void _saveStudent() async {
    if (_selectedRoute.isEmpty || _selectedStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both Route and Stop.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Seating logic: Force a seat update if gender or route changed
      String? newSeat;
      if (widget.studentData['gender'] != _gender || widget.studentData['routeId'] != _selectedRoute || widget.studentData['seatNumber'] == null) {
        newSeat = await _calculateSeat();
      }

      await FirebaseFirestore.instance.collection('students').doc(widget.docId).update({
        'department': _selectedDepartment,
        'yearOfStudy': _selectedYear,
        'gender': _gender,
        'routeId': _selectedRoute,
        'stopId': _selectedStop,
        if (newSeat != null) 'seatNumber': newSeat,
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student profile updated successfully.')));
      }
    } catch (e) {
      debugPrint("Update student error: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating student: $e')));
      }
    }
  }

  Future<String> _calculateSeat() async {
    // Find highest seat number for this gender on this route
    final snap = await FirebaseFirestore.instance.collection('students')
        .where('routeId', isEqualTo: _selectedRoute)
        .where('gender', isEqualTo: _gender)
        .get();
    
    // Female: 1-30, Male: 31-60 (Assuming 60 seat bus)
    int baseSeat = _gender == 'Female' ? 0 : 30;
    int maxOffset = 0;
    
    for (var doc in snap.docs) {
       final seat = doc.data()['seatNumber']?.toString() ?? '0';
       int seatInt = int.tryParse(seat) ?? 0;
       int offset = seatInt - baseSeat;
       if (offset > maxOffset && offset <= 30) {
         maxOffset = offset;
       }
    }
    
    return (baseSeat + maxOffset + 1).toString();
  }
}
