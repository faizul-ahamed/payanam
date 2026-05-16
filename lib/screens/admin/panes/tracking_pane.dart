import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../../theme/app_theme.dart';
import '../../../services/map_service.dart';
import '../../../config/api_keys.dart';

class TrackingPane extends StatefulWidget {
  final String? initialTripId;
  const TrackingPane({super.key, this.initialTripId});

  @override
  State<TrackingPane> createState() => _TrackingPaneState();
}

class _TrackingPaneState extends State<TrackingPane> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, LatLng> _lastKnownLocations = {};
  
  String? _selectedTripId;
  Map<String, dynamic> _busRoutes = {};
  final Map<String, LatLng> _stopCoordsCache = {};
  bool _isLoadingRoute = false;
  List<String> _selectedRouteStops = [];

  final String _googleApiKey = ApiKeys.googleMapsKey;
  
  static const double _routeBiasLat = 11.0050;
  static const double _routeBiasLng = 78.0800;
  static const double _routeBiasRadiusMeters = 50000.0;

  static const Map<String, String> _stopQueryOverrides = {
    'MKCE College Campus':         'M.Kumarasamy College of Engineering Karur',
    'MKCE COLLEGE CAMPUS':         'M.Kumarasamy College of Engineering Karur',
    'MURUGAN KOVIL':               'Murugan Koil Mohanur Namakkal',
    'MOHANUR BUS STAND':           'Mohanur Bus Stand Namakkal',
    'AGRAHARAM':                   'Agraharam Vangal Karur Tamil Nadu',
    'VANGAL TOWN':                 'Vangal Town Karur Tamil Nadu',
    'VANGAL GOVT SCHOOL':          'Government Higher Secondary School Vangal Karur',
    'Light house':                 'Light House Karur',
    'Ulavar santhai':              'Ulavar Santhai Market Karur',
    'Delhi Sweets':                'Delhi Sweets Karur',
    'Kumar store':                 'Kumar Store Karur',
    'Sungagate':                   'Sungam Gate Karur',
    'Vaiyapuri Nagar':             'Vaiyapuri Nagar Karur',
    'Annapoorna':                  'Annapoorna Restaurant Karur',
    'NERUR':                       'Nerur Karur Tamil Nadu',
    'MANMANGALAM':                 'Manmangalam Karur Tamil Nadu',
    'COLLECTOR OFFICE':            'Collector Office Karur',
    'BUS STAND':                   'Karur New Bus Stand',
    'KARUR NEW BUS STAND':         'Karur New Bus Stand',
    'ARTS COLLEGE 1':              'Government Arts College Karur',
    'ARTS COLLEGE 2':              'Government Arts College Karur Tamil Nadu',
    'RTO OFFICE (KARUR)':          'RTO Office Karur',
    'MALAR SCHOOL':                'Malar School Karur',
  };

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(11.1271, 78.1217),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.initialTripId;
    _loadBusRoutes();
    _startBackgroundPresence();
  }

  StreamSubscription<Position>? _backgroundPositionSubscription;

  void _startBackgroundPresence() {
    _backgroundPositionSubscription?.cancel();
    
    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Monitoring fleet performance in background.",
          notificationTitle: "Fleet Tracking Active",
          enableWakeLock: false,
        )
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
      );
    }

    _backgroundPositionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Keep process alive for Firestore stream
    });
  }

  @override
  void dispose() {
    _backgroundPositionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadBusRoutes() async {
    try {
      final String response = await rootBundle.loadString('assets/data/bus_routes.json');
      _busRoutes = json.decode(response);
    } catch (e) {
      debugPrint('Error loading bus routes: $e');
    }
  }

  Future<void> _showRouteForTrip(Map<String, dynamic> tripData, String tripId) async {
    if (_selectedTripId == tripId && _polylines.isNotEmpty) return;

    setState(() {
      _selectedTripId = tripId;
      _isLoadingRoute = true;
      _polylines.clear();
      _selectedRouteStops = [];
    });

    final String routeId = tripData['routeId'] ?? '';
    List<String> stopsList = [];
    
    // 1. Try to fetch from Firestore first
    try {
      String normalize(String s) {
        return s.toLowerCase().replaceAll('route', '').replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
      }
      final search = normalize(routeId);
      
      final routeQuery = await FirebaseFirestore.instance.collection('routes').get();
      final List<DocumentSnapshot> matches = routeQuery.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = normalize(data['name']?.toString() ?? '');
        final rid = normalize(data['routeId']?.toString() ?? '');
        return name == search || rid == search || name.contains(search) || search.contains(name);
      }).toList();

      if (matches.isNotEmpty) {
        final routeData = matches.first.data() as Map<String, dynamic>;
        final List<dynamic> stopsData = routeData['stops'] ?? [];
        stopsList = stopsData.map((s) => s['name'].toString().trim()).toList();
        
        for (var s in stopsData) {
          final stopName = s['name']?.toString().trim() ?? "";
          if (s['lat'] != 0.0 && s['lng'] != 0.0 && stopName.isNotEmpty) {
            _stopCoordsCache[stopName.toUpperCase()] = LatLng(s['lat'].toDouble(), s['lng'].toDouble());
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching from Firestore: $e");
    }

    // 2. Fallback to local JSON
    if (stopsList.isEmpty) {
      if (!_busRoutes.containsKey(routeId)) {
        String? matchedKey;
        try {
          matchedKey = _busRoutes.keys.firstWhere((k) => k.toLowerCase().startsWith(routeId.toLowerCase()) || k.toLowerCase().contains('$routeId -'));
        } catch (_) {}
        if (matchedKey != null) {
          stopsList = List<String>.from(_busRoutes[matchedKey]).map((s) => s.trim()).toList();
        } else {
          setState(() => _isLoadingRoute = false);
          return;
        }
      } else {
        stopsList = List<String>.from(_busRoutes[routeId]).map((s) => s.trim()).toList();
      }
    }

    final String session = tripData['session'] ?? 'Morning';
    
    // Identical MKCE Logic as Student Dashboard
    if (session == 'Morning') {
      if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) {
        stopsList.add('MKCE College Campus');
      }
    } else {
      stopsList = stopsList.reversed.toList();
      if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) {
        stopsList.insert(0, 'MKCE College Campus');
      } else {
        stopsList.removeWhere((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS');
        stopsList.insert(0, 'MKCE College Campus');
      }
    }

    // Geocode stops in parallel
    await Future.wait(stopsList.map((stop) => _geocodeStop(stop)));

    List<LatLng> stopLocations = [];
    for (String stop in stopsList) {
      LatLng? loc = _stopCoordsCache[stop.toUpperCase().trim()];
      if (loc != null) stopLocations.add(loc);
    }

    if (stopLocations.length >= 2) {
      await _fetchRoutePolyline(stopLocations);
    }

    if (mounted) {
      setState(() {
        _selectedRouteStops = stopsList;
        _isLoadingRoute = false;
      });
      
      if (stopLocations.isNotEmpty) {
        _zoomToSelection(stopLocations);
      }
    }
  }

  Future<LatLng?> _geocodeStop(String stop) async {
    final String cacheKey = stop.toUpperCase().trim();
    if (_stopCoordsCache.containsKey(cacheKey)) return _stopCoordsCache[cacheKey];

    try {
      final String query = _stopQueryOverrides[stop] ?? _stopQueryOverrides[cacheKey] ?? '$stop, Karur, Tamil Nadu, India';

      // 1. Places API (New) with location bias
      final placesResponse = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchText'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
          'X-Goog-FieldMask': 'places.location',
        },
        body: json.encode({
          'textQuery': query,
          'locationBias': {
            'circle': {
              'center': {'latitude': _routeBiasLat, 'longitude': _routeBiasLng},
              'radius': _routeBiasRadiusMeters,
            },
          },
        }),
      );

      if (placesResponse.statusCode == 200) {
        final data = json.decode(placesResponse.body);
        if (data['places'] != null && (data['places'] as List).isNotEmpty) {
          final loc = data['places'][0]['location'];
          final latLng = LatLng(loc['latitude'].toDouble(), loc['longitude'].toDouble());
          _stopCoordsCache[cacheKey] = latLng;
          return latLng;
        }
      }

      // 2. Fallback to Geocoding API
      final geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&bounds=10.55,77.58%7C11.45,78.60&region=in&key=$_googleApiKey';
      final geoResponse = await http.get(Uri.parse(geocodeUrl));
      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        if (geoData['status'] == 'OK' && geoData['results'].isNotEmpty) {
          final loc = geoData['results'][0]['geometry']['location'];
          final latLng = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          _stopCoordsCache[cacheKey] = latLng;
          return latLng;
        }
      }
    } catch (e) {
      debugPrint('Geocoding error for $stop: $e');
    }
    return null;
  }

  Future<void> _fetchRoutePolyline(List<LatLng> points) async {
    if (points.length < 2) return;

    try {
      final RouteResult result = await MapService.fetchRoadPolyline(points);
      
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('selected_route'),
            points: result.polyline,
            color: AppColors.primaryPurple,
            width: 5,
            jointType: JointType.round,
          ),
        );
      });
    } catch (e) {
      debugPrint('Directions error: $e');
      // Fallback
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('selected_route'),
            points: _getOrderedStopPoints(points),
            color: AppColors.primaryPurple,
            width: 5,
            jointType: JointType.round,
          ),
        );
      });
    }
  }

  List<LatLng> _getOrderedStopPoints(List<LatLng> points) {
    if (points.isNotEmpty) return points;
    List<LatLng> fallback = [];
    for (var stop in _selectedRouteStops) {
      LatLng? pos = _stopCoordsCache[stop.toUpperCase().trim()];
      if (pos != null) fallback.add(pos);
    }
    return fallback;
  }

  void _zoomToSelection(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Bus or Route...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.getSurfaceCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_selectedTripId != null)
                IconButton(
                  onPressed: () => setState(() {
                    _selectedTripId = null;
                    _polylines.clear();
                    _selectedRouteStops = [];
                  }),
                  icon: const Icon(Icons.refresh, color: AppColors.primaryPurple),
                ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list_rounded, color: AppColors.primaryPurple),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('trips').where('status', whereIn: ['running', 'delayed', 'breakdown', 'emergency']).snapshots(),
            builder: (context, snapshot) {
              _markers.clear();
              Map<String, dynamic>? selectedTripData;

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final gp = data['lastLocation'] as GeoPoint?;
                  
                  // Cache and use last known location to prevent vanishing markers
                  LatLng? latLng;
                  if (gp != null) {
                    latLng = LatLng(gp.latitude, gp.longitude);
                    _lastKnownLocations[doc.id] = latLng;
                  } else {
                    latLng = _lastKnownLocations[doc.id];
                  }

                  if (latLng != null) {
                    final isSelected = _selectedTripId == doc.id;
                    if (isSelected) selectedTripData = data;

                    final statusStr = data['status'] ?? 'running';
                    double markerHue = BitmapDescriptor.hueGreen; // Running
                    if (statusStr == 'delayed') markerHue = BitmapDescriptor.hueOrange;
                    else if (statusStr == 'breakdown' || statusStr == 'emergency') markerHue = BitmapDescriptor.hueRed;

                    _markers.add(
                      Marker(
                        markerId: MarkerId(doc.id),
                        position: latLng,
                        anchor: const Offset(0.5, 0.5),
                        infoWindow: InfoWindow(
                          title: 'BUS: ${data['busId']}',
                          snippet: 'Route: ${data['routeId']} • ${data['session']}',
                        ),
                        onTap: () => _showRouteForTrip(data, doc.id),
                        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
                        zIndex: 10,
                      ),
                    );
                  }
                }
              }

              if (selectedTripData != null && _selectedRouteStops.isNotEmpty) {
                int currentStopIndex = (selectedTripData['currentStopIndex'] ?? 0).toInt();
                
                for (int i = 0; i < _selectedRouteStops.length; i++) {
                  String stopName = _selectedRouteStops[i];
                  LatLng? pos = _stopCoordsCache[stopName.toUpperCase().trim()];
                  
                  if (pos != null) {
                    bool isVisited = i < currentStopIndex;
                    bool isCurrent = i == currentStopIndex;
                    bool isCollege = stopName.toUpperCase().contains('COLLEGE CAMPUS');
                    
                    _markers.add(
                      Marker(
                        markerId: MarkerId('stop_${_selectedTripId}_$i'),
                        position: pos,
                        infoWindow: InfoWindow(
                          title: '${i + 1}. $stopName',
                          snippet: isCurrent ? 'BUS IS HERE' : (isVisited ? 'VISITED' : 'UPCOMING'),
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          isCollege ? BitmapDescriptor.hueViolet :
                          (isCurrent ? BitmapDescriptor.hueCyan : 
                          (isVisited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed))
                        ),
                      ),
                    );
                  }
                }
              }

              if (selectedTripData != null && _polylines.isEmpty && !_isLoadingRoute) {
                // Auto trigger route loading if we pass an initialTripId
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showRouteForTrip(selectedTripData!, _selectedTripId!);
                });
              }

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _kInitialPosition,
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: MapType.normal,
                    style: _getMapStyle(),
                  ),
                  
                  if (_isLoadingRoute)
                    const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),

                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _selectedTripId != null 
                        ? _buildDetailedInfoCard(selectedTripData)
                        : _buildFleetSummaryCard(_markers.where((m) => !m.markerId.value.startsWith('stop_')).length),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFleetSummaryCard(int activeCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(activeCount == 0 ? 'No Active Buses' : '$activeCount Buses Currently Active', 
               style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text('Tap a bus for details', style: TextStyle(fontSize: 11, color: AppColors.primaryPurple)),
        ],
      ),
    );
  }

  Widget _buildDetailedInfoCard(Map<String, dynamic>? tripData) {
    if (tripData == null) return const SizedBox();

    String currentStatus = tripData['status'] ?? 'running';
    Color statusColor = AppColors.success;
    String displayStatus = 'RUNNING';

    if (currentStatus == 'delayed') {
      statusColor = AppColors.warning;
      displayStatus = 'DELAYED';
    } else if (currentStatus == 'breakdown' || currentStatus == 'emergency') {
      statusColor = AppColors.error;
      displayStatus = 'EMERGENCY';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor,
                child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tripData['routeId'] ?? 'Unknown Route', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Bus: ${tripData['busId']} • Session: ${tripData['session']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(onPressed: () => setState(() {
                _selectedTripId = null;
                _polylines.clear();
                _selectedRouteStops = [];
              }), icon: const Icon(Icons.close, size: 20)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Status', displayStatus, statusColor),
              _buildStat('Stop Index', '${(tripData['currentStopIndex'] ?? 0) + 1}', AppColors.primaryPurple),
              _buildStat('Progress', '${_selectedRouteStops.length > 0 ? (((tripData['currentStopIndex'] ?? 0) / (_selectedRouteStops.length - 1)) * 100).round() : 0}%', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }

  String? _getMapStyle() => null;
}
