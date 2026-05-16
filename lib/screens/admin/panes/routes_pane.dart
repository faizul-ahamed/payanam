import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../config/api_keys.dart';

class RoutesPane extends StatefulWidget {
  const RoutesPane({super.key});

  @override
  State<RoutesPane> createState() => _RoutesPaneState();
}

class _RoutesPaneState extends State<RoutesPane> {
  String? _selectedRouteId;
  Map<String, dynamic>? _selectedRouteData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRoutes = [];
  final String _googleApiKey = ApiKeys.googleMapsKey;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Check Firestore for existing routes
      final snapshot = await FirebaseFirestore.instance.collection('routes').orderBy('routeId').get();
      
      if (snapshot.docs.isNotEmpty) {
        _allRoutes = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
      } else {
        // 2. Fallback to JSON and Initialize Firestore
        final String jsonContent = await rootBundle.loadString('assets/data/bus_routes.json');
        final Map<String, dynamic> jsonData = json.decode(jsonContent);
        List<Map<String, dynamic>> initialRoutes = [];
        int index = 1;
        for (var entry in jsonData.entries) {
          final routeName = entry.key; // Canonical Name
          final routeId = 'Route $index';
          final stopsList = List<String>.from(entry.value);
          
          List<Map<String, dynamic>> stopsWithCoords = [];
          for (var s in stopsList) {
            final loc = await _geocodeStopName(s); // Geocode immediately on init
            stopsWithCoords.add({
              'name': s,
              'lat': loc?.latitude ?? 0.0,
              'lng': loc?.longitude ?? 0.0,
            });
          }
          
          final routeData = {
            'routeId': routeId,
            'name': routeName,
            'stops': stopsWithCoords,
            'distance': '0.0 km',
            'estimatedTime': '0 mins',
            'isActive': true,
          };
          
          await FirebaseFirestore.instance.collection('routes').doc(routeId).set(routeData);
          initialRoutes.add({'id': routeId, ...routeData});
          
          // Trigger auto-calculation once we have coords
          _autoCalculateRouteMetricsForInit(routeId, stopsWithCoords);
          
          index++;
        }
        _allRoutes = initialRoutes;
      }
    } catch (e) {
      debugPrint('Error loading routes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
    }

    if (_selectedRouteId != null) {
      return _buildDetailView();
    }

    return Column(
      children: [
        // Header with Route Count
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Text(
                'Transportation Routes',
                style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allRoutes.length} Total',
                  style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Route Search/Filter and Add Route Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Route...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.getSurfaceCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    // TODO: Implement search filtering
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: _handleAddRoute,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  tooltip: 'Add New Route',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Route Grid/List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            itemCount: _allRoutes.length,
            itemBuilder: (context, index) {
              final route = _allRoutes[index];
              return _buildRouteCard(route);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final List stops = route['stops'] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        onTap: () {
          setState(() {
            _selectedRouteId = route['id'];
            _selectedRouteData = route;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route['routeId'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route['name'] ?? 'Route Name'} • ${stops.length} Stops',
                      style: TextStyle(color: AppColors.textMutedDark, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route['distance'] ?? '0.0 km'} • ${route['estimatedTime'] ?? '0 mins'}',
                      style: const TextStyle(color: AppColors.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    if (_selectedRouteData == null) return const SizedBox();
    
    final List stops = List.from(_selectedRouteData!['stops'] ?? []);
    
    return Column(
      children: [
        // Detail Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedRouteId = null),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedRouteData!['routeId'] ?? 'Route Details',
                    style: AppTextStyles.heading1(context).copyWith(fontSize: 20),
                  ),
                  Text(
                    _selectedRouteData!['name'] ?? '',
                    style: TextStyle(color: AppColors.textMutedDark, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              _buildIconButton(Icons.delete_outline_rounded, AppColors.error, () => _handleDeleteRoute()),
            ],
          ),
        ),

        // Route Stats Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              _buildStatChip(Icons.straighten_rounded, _selectedRouteData!['distance'] ?? '0.0 km'),
              const SizedBox(width: 12),
              _buildStatChip(Icons.timer_outlined, _selectedRouteData!['estimatedTime'] ?? '0 mins'),
            ],
          ),
        ),

        const Divider(height: 1),

        // Stops Management Section
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: stops.length + 1, // Restored +1 for the Add Stop button
            itemBuilder: (context, index) {
              if (index < stops.length) {
                final stop = stops[index];
                return _buildStopListTile(stop, index, index == stops.length - 1 && index > 0);
              } else {
                return _buildAddStopButton();
              }
            },
          ),
        ),

        // Bottom Actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceCardColor(context),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleGeocodeAllStops(),
                  icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: const Text('Update All Coordinates'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStopListTile(Map<String, dynamic> stop, int index, bool isLastManaged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop['name'] ?? 'Stop Name',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Lat: ${stop['lat']?.toStringAsFixed(4) ?? '0.0'}, Lng: ${stop['lng']?.toStringAsFixed(4) ?? '0.0'}',
                  style: TextStyle(color: AppColors.textMutedDark, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(Icons.edit_location_alt_outlined, AppColors.primaryPurple, () => _handleEditStop(index)),
              const SizedBox(width: 4),
              _buildIconButton(Icons.delete_outline_rounded, AppColors.error, () => _handleDeleteStop(index)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddStopButton() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: () => _handleAddStop(),
        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
        label: const Text('Add New Stop'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: AppColors.primaryPurple,
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- LOGIC HANDLERS ---

  double _calculateStraightLineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 - math.cos((lat2 - lat1) * p)/2 + 
          math.cos(lat1 * p) * math.cos(lat2 * p) * 
          (1 - math.cos((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a));
  }

    // Helper specifically for initialization (takes parameters instead of relying on _selectedRouteData)
  void _autoCalculateRouteMetricsForInit(String routeId, List stops) async {
    const double destLat = 11.0543; 
    const double destLng = 78.0494;
    double startLat = 0.0;
    double startLng = 0.0;
    for (var stop in stops) {
      if ((stop['lat'] ?? 0.0) != 0.0) {
        startLat = stop['lat'];
        startLng = stop['lng'];
        break; // Distance from first stop to college
      }
    }
    if (startLat != 0.0) {
      double dist = _calculateStraightLineDistance(startLat, startLng, destLat, destLng) * 1.35;
      int mins = ((dist / 30.0) * 60).round() + stops.length;
      await FirebaseFirestore.instance.collection('routes').doc(routeId).update({
        'distance': '${dist.toStringAsFixed(1)} km',
        'estimatedTime': '$mins mins',
      });
    }
  }

  void _autoCalculateRouteMetrics(List stops) async {
    if (_selectedRouteData == null) return;
    
    // College Coordinates (Approximate MKCE location)
    const double destLat = 11.0543; 
    const double destLng = 78.0494;

    double startLat = 0.0;
    double startLng = 0.0;
    int validStops = 0;

    for (var stop in stops) {
      double lat = stop['lat'] ?? 0.0;
      double lng = stop['lng'] ?? 0.0;
      if (lat != 0.0 && lng != 0.0) {
        if (startLat == 0.0) {
          startLat = lat;
          startLng = lng;
        }
        validStops++;
      }
    }

    double totalDistance = 0.0;
    if (startLat != 0.0 && startLng != 0.0) {
        double directDistance = _calculateStraightLineDistance(startLat, startLng, destLat, destLng);
        // Add 35% road overhead to straight-line radius to account for roads
        totalDistance = directDistance * 1.35;
    }
    
    // Assumed average transit speed of ~30 km/h in real driving scenarios
    int timeInMins = ((totalDistance / 30.0) * 60).round();
    
    // Add 1 min delay for each intermediate stopping point
    timeInMins += validStops; 
    
    String distanceStr = '${totalDistance.toStringAsFixed(1)} km';
    String timeStr = '${math.max(timeInMins, 0)} mins';
    
    if (mounted) {
      setState(() {
         _selectedRouteData!['distance'] = distanceStr;
         _selectedRouteData!['estimatedTime'] = timeStr;
      });
    }

    try {
      await FirebaseFirestore.instance.collection('routes').doc(_selectedRouteId).update({
          'distance': distanceStr,
          'estimatedTime': timeStr,
      });
      
      final idx = _allRoutes.indexWhere((r) => r['id'] == _selectedRouteId);
      if (idx != -1) {
          _allRoutes[idx]['distance'] = distanceStr;
          _allRoutes[idx]['estimatedTime'] = timeStr;
      }
    } catch (e) {
      debugPrint("Failed to update firestore with metrics: $e");
    }
  }

  Future<void> _handleAddRoute() async {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: idController, decoration: const InputDecoration(labelText: 'Route ID (e.g., Route 31)')),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Route Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                final routeData = {
                  'routeId': idController.text,
                  'name': nameController.text,
                  'stops': [],
                  'distance': '0.0 km',
                  'estimatedTime': '0 mins',
                  'isActive': true,
                };
                await FirebaseFirestore.instance.collection('routes').doc(idController.text).set(routeData);
                setState(() {
                  _allRoutes.add({'id': idController.text, ...routeData});
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Add Route'),
          ),
        ],
      ),
    );
  }


  Future<void> _handleEditStop(int index) async {
    final List stops = List.from(_selectedRouteData!['stops']);
    final Map<String, dynamic> stop = Map<String, dynamic>.from(stops[index]);
    
    final TextEditingController nameController = TextEditingController(text: stop['name']);
    final TextEditingController latController = TextEditingController(text: stop['lat'].toString());
    final TextEditingController lngController = TextEditingController(text: stop['lng'].toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Stop Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Stop Name')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitude'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              stop['name'] = nameController.text;
              stop['lat'] = double.tryParse(latController.text) ?? 0.0;
              stop['lng'] = double.tryParse(lngController.text) ?? 0.0;
              stops[index] = stop;
              
              await _updateRouteInFirestore(stops);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddStop() async {
    final List stops = List.from(_selectedRouteData!['stops']);
    
    final TextEditingController nameController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Stop Name')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitude'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                stops.add({
                  'name': nameController.text,
                  'lat': double.tryParse(latController.text) ?? 0.0,
                  'lng': double.tryParse(lngController.text) ?? 0.0,
                });
                await _updateRouteInFirestore(stops);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteStop(int index) async {
    final List stops = List.from(_selectedRouteData!['stops']);
    stops.removeAt(index);
    await _updateRouteInFirestore(stops);
  }

  Future<void> _handleGeocodeAllStops() async {
    setState(() => _isLoading = true);
    final List stops = List.from(_selectedRouteData!['stops']);
    
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (stop['lat'] == 0.0 || stop['lng'] == 0.0) {
        final loc = await _geocodeStopName(stop['name']);
        if (loc != null) {
          stops[i] = {'name': stop['name'], 'lat': loc.latitude, 'lng': loc.longitude};
        }
      }
    }
    
    await _updateRouteInFirestore(stops);
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates updated successfully.')));
  }

  Future<LatLng?> _geocodeStopName(String stop) async {
    try {
      final query = '$stop, Karur, Tamil Nadu, India';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _updateRouteInFirestore(List stops) async {
    try {
      await FirebaseFirestore.instance.collection('routes').doc(_selectedRouteId).update({
        'stops': stops,
      });
      // Refresh local data
      final updatedRoute = Map<String, dynamic>.from(_selectedRouteData!);
      updatedRoute['stops'] = stops;
      
      setState(() {
        _selectedRouteData = updatedRoute;
        final idx = _allRoutes.indexWhere((r) => r['id'] == _selectedRouteId);
        if (idx != -1) _allRoutes[idx] = updatedRoute;
      });
      
      // Post-calculation
      _autoCalculateRouteMetrics(stops);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e')));
    }
  }

  Future<void> _handleDeleteRoute() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route?'),
        content: const Text('This will permanently remove the route. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Validation check
        final busCheck = await FirebaseFirestore.instance.collection('drivers').where('routeId', isEqualTo: _selectedRouteId).get();
        final studentCheck = await FirebaseFirestore.instance.collection('students').where('routeId', isEqualTo: _selectedRouteId).get();

        if (busCheck.docs.isNotEmpty || studentCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete route: Buses or Students are still assigned to it.'))
          );
          return;
        }

        await FirebaseFirestore.instance.collection('routes').doc(_selectedRouteId).delete();
        _allRoutes.removeWhere((r) => r['id'] == _selectedRouteId);
        _selectedRouteId = null;
        _selectedRouteData = null;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}
