import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/map_service.dart';
import '../../../config/api_keys.dart';

class DriverHomePane extends StatefulWidget {
  final Map<String, dynamic> driverData;
  const DriverHomePane({super.key, required this.driverData});

  @override
  State<DriverHomePane> createState() => _DriverHomePaneState();
}

class _DriverHomePaneState extends State<DriverHomePane> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _tripStatus = 'inactive';
  List<String> _stops = [];
  Map<String, LatLng> _stopCoords = {};
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStopIndex = 0;
  String _session = 'Morning';
  bool _isMapMaximized = false;
  String? _canonicalRouteId; // Track the full name from JSON (e.g. Route 9 - MOHANUR)
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;
  StreamSubscription? _routeSubscription;
  String? _canonicalRouteDocId;
  Map<String, dynamic>? _lastRouteData;
  
  final AuthService _authService = AuthService();
  final String _googleApiKey = ApiKeys.googleMapsKey;
  List<LatLng> _polylineCoordinates = [];
  String? _tripDuration;
  String? _tripDistance;
  Map<int, String> _segmentDistances = {};
  Map<int, String> _segmentDurations = {};
  bool _isRouteLoading = false;
  
  // MKCE Coordinates (M. Kumarasamy College of Engineering, Karur)
  final LatLng _collegeLocation = const LatLng(11.0543, 78.0494);

  // Centre of the Karur/Namakkal district - used as Places API location bias.
  static const double _routeBiasLat = 11.0050;
  static const double _routeBiasLng = 78.0800;
  static const double _routeBiasRadiusMeters = 50000.0;

  // Curated override: colloquial bus-stop name to precise Google Maps query.
  static const Map<String, String> _stopQueryOverrides = {
    'MKCE College Campus':         'M.Kumarasamy College of Engineering Karur',
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

  @override
  void initState() {
    super.initState();
    _tripStatus = widget.driverData['tripStatus'] ?? 'inactive';
    if (_tripStatus == 'running' && widget.driverData['currentSession'] != null) {
      _session = widget.driverData['currentSession'];
    }
    
    _initTripData(); // Initial sync
    _setupRouteStream(); // Replaces _loadStops() with real-time sync
    
    _checkPermissionsAndGetLocation();
    if (_tripStatus == 'running') {
      _startLocationTracking();
    }
  }

  Future<void> _initTripData() async {
    if (_tripStatus == 'running') {
      try {
        final tripDoc = await FirebaseFirestore.instance.collection('trips').doc(widget.driverData['driverId']).get();
        if (tripDoc.exists && mounted) {
          setState(() {
            _currentStopIndex = tripDoc.data()?['currentStopIndex'] ?? 0;
          });
        }
      } catch (e) {
        debugPrint('Error getting trip doc: $e');
      }
    }
    await _loadStops(); // Now load stops correctly using the restored index (if any)
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupRouteStream() async {
    final String rawRouteId = widget.driverData['routeId'] ?? '';
    
    // Find the canonical route document first
    String normalize(String s) {
      return s.toLowerCase().replaceAll('route', '').replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
    }
    
    final String search = normalize(rawRouteId);
    
    // Find the canonical route document first
    final routeQuery = await FirebaseFirestore.instance.collection('routes').get();
    final List<DocumentSnapshot> matches = routeQuery.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = normalize(data['name']?.toString() ?? '');
      final rid = normalize(data['routeId']?.toString() ?? '');
      return name == search || rid == search || name.contains(search) || search.contains(name);
    }).toList();

    if (matches.isNotEmpty) {
      _canonicalRouteDocId = matches.first.id;
      _routeSubscription = FirebaseFirestore.instance.collection('routes')
          .doc(_canonicalRouteDocId)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
               _lastRouteData = snapshot.data();
               _processRouteUpdate(_lastRouteData!);
            }
          });
    } else {
       // Fallback to local if no matching Firestore route found yet
       _loadStops(); 
    }
  }

  Future<void> _processRouteUpdate(Map<String, dynamic> routeData) async {
      try {
        final List<dynamic> stopsData = routeData['stops'] ?? [];
        List<String> stopsList = stopsData.map((s) => s['name'].toString().trim()).toList();
        Map<String, LatLng> coordsFromFirestore = {};
        for (var s in stopsData) {
          final stopName = s['name']?.toString().trim() ?? "";
          if (s['lat'] != 0.0 && s['lng'] != 0.0 && stopName.isNotEmpty) {
            coordsFromFirestore[stopName.toUpperCase()] = LatLng(s['lat'].toDouble(), s['lng'].toDouble());
          }
        }

        if (_session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.insert(0, 'MKCE College Campus');
        }

        if (mounted) {
          setState(() {
            _stops = stopsList;
            _canonicalRouteId = routeData['name'] ?? widget.driverData['routeId'];
            _stopCoords = Map.from(coordsFromFirestore); // Overwrite to ensure Admin edits win
            _isRouteLoading = true;
          });

          await _generateMockCoordinates(); // Geocode missing ones & rebuild polyline/markers
          if (mounted) setState(() => _isRouteLoading = false);
        }
      } catch (e) {
        debugPrint("Driver: Error processing route stream update: $e");
      }
  }

  Future<void> _loadStops() async {
    try {
      final String rawRouteId = widget.driverData['routeId'] ?? '';
      
      // 1. First try to find the route in Firestore 'routes' collection
      final routeQuery = await FirebaseFirestore.instance.collection('routes')
          .where('routeId', isEqualTo: rawRouteId)
          .get();
          
      DocumentSnapshot? routeDoc;
      if (routeQuery.docs.isNotEmpty) {
        routeDoc = routeQuery.docs.first;
      } else {
        String normalize(String s) {
          return s.toLowerCase().replaceAll('route', '').replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
        }
        final search = normalize(rawRouteId);
        
        final allRoutes = await FirebaseFirestore.instance.collection('routes').get();
        try {
          routeDoc = allRoutes.docs.firstWhere((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = normalize(data['name']?.toString() ?? "");
            final rid = normalize(data['routeId']?.toString() ?? "");
            return name == search || rid == search || name.contains(search) || search.contains(name);
          });
        } catch (_) {}
      }

      if (routeDoc != null) {
        final routeData = routeDoc.data() as Map<String, dynamic>;
        final String matchedKey = routeData['name'] ?? rawRouteId;
        final List<dynamic> stopsData = routeData['stops'] ?? [];
        
        List<String> stopsList = stopsData.map((s) => s['name'].toString().trim()).toList();
        Map<String, LatLng> coordsFromFirestore = {};
        for (var s in stopsData) {
          final stopName = s['name']?.toString().trim() ?? "";
          if (s['lat'] != 0.0 && s['lng'] != 0.0 && stopName.isNotEmpty) {
            coordsFromFirestore[stopName.toUpperCase()] = LatLng(s['lat'].toDouble(), s['lng'].toDouble());
          }
        }

        if (_session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.insert(0, 'MKCE College Campus');
        }

        setState(() {
          _stops = stopsList;
          _canonicalRouteId = matchedKey;
          _stopCoords.addAll(coordsFromFirestore); // Use existing coordinates if available
          if (_tripStatus != 'running') _currentStopIndex = 0;
        });
        _generateMockCoordinates(); // Still run geocoding for missing coords
        return;
      }

      // 2. Fallback to Local JSON (Original Logic)
      final String response = await rootBundle.loadString('assets/data/bus_routes.json');
      final Map<String, dynamic> data = json.decode(response);
      
      String? matchedKey;
      if (data.containsKey(rawRouteId)) {
        matchedKey = rawRouteId;
      } else {
        try {
          matchedKey = data.keys.firstWhere(
            (k) => k.toLowerCase().startsWith(rawRouteId.toLowerCase()) || 
                   k.toLowerCase().contains('$rawRouteId -'),
          );
        } catch (_) {}
      }

      if (matchedKey != null) {
        List<String> stopsList = List<String>.from(data[matchedKey]).map((s) => s.trim()).toList();
        
        if (_session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase().contains('MKCE'))) stopsList.insert(0, 'MKCE College Campus');
        }

        setState(() {
          _stops = stopsList;
          _canonicalRouteId = matchedKey;
          if (_tripStatus != 'running') _currentStopIndex = 0;
        });
        _generateMockCoordinates();
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
    }
  }

  // Write back geocoded coordinates to Firestore so Admin and other users benefit
  Future<void> _updateStopsInFirestore(String stopName, LatLng pos) async {
    try {
      final String routeId = widget.driverData['routeId'] ?? '';
      final String searchKey = _canonicalRouteId ?? routeId;
      
      // Fuzzy matching lookup
      final routeQuery = await FirebaseFirestore.instance.collection('routes').get();
      final List<DocumentSnapshot> matches = routeQuery.docs.where((doc) {
        final name = (doc.data() as Map<String, dynamic>)['name']?.toString() ?? '';
        return name == searchKey || name.startsWith(searchKey) || searchKey.startsWith(name);
      }).toList();
          
      if (matches.isNotEmpty) {
        final docId = matches.first.id;
        final data = matches.first.data() as Map<String, dynamic>;
        List stops = List.from(data['stops'] ?? []);
        
        bool updated = false;
        for (int i = 0; i < stops.length; i++) {
          if (stops[i]['name'].toString().trim().toUpperCase() == stopName.toUpperCase() && 
              (stops[i]['lat'] == 0.0 || stops[i]['lng'] == 0.0)) {
            stops[i] = {
              'name': stops[i]['name'],
              'lat': pos.latitude,
              'lng': pos.longitude,
            };
            updated = true;
          }
        }
        
        if (updated) {
          await FirebaseFirestore.instance.collection('routes').doc(docId).update({'stops': stops});
        }
      }
    } catch (e) {
      debugPrint("Driver: Failed to sync stops: $e");
    }
  }

  @override
  void didUpdateWidget(DriverHomePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the data from parent updated (e.g. from Firestore stream)
    // and we are NOT in the middle of a trip, sync our local status.
    if (_tripStatus != 'running' && widget.driverData['tripStatus'] != null) {
      if (_tripStatus != widget.driverData['tripStatus']) {
        setState(() {
          _tripStatus = widget.driverData['tripStatus'];
        });
      }
    }
  }

  Future<void> _generateMockCoordinates() async {
    // Only clear coords that aren't already set (preserve Admin edits)
    // We don't call _stopCoords.clear() here anymore to let Firestore updates persist
    
    await Future.wait(_stops.map(_geocodeStop));
    
    // Safety check: Filter out any stops that failed geocoding to prevent anomalous lines
    // CRITICAL: use .toUpperCase() for matching as _stopCoords uses uppercase keys
    List<String> validStops = _stops.where((s) => _stopCoords.containsKey(s.toUpperCase())).toList();
    if (validStops.length != _stops.length) {
      debugPrint("Warning: Some stops could not be geocoded: ${_stops.where((s) => !_stopCoords.containsKey(s.toUpperCase())).toList()}");
      _stops = validStops;
    }

    await _fetchRoadPolyline();
    _updateMapElements();
    _zoomToRoute();
  }

  /// Resolve a bus-stop name → LatLng using Google Places API (New).
  /// Uses locationBias so generic names like 'Murugan Kovil' are found
  /// near the Karur/Namakkal route, not somewhere in another state.
  Future<void> _geocodeStop(String stopName) async {
    final String key = stopName.toUpperCase();
    if (_stopCoords.containsKey(key)) {
      final existing = _stopCoords[key]!;
      if (existing.latitude != 0.0 && existing.longitude != 0.0) {
        return; // Use Admin's manual edits
      }
    }

    try {
      final String query = _stopQueryOverrides[stopName] ?? '$stopName, Karur, Tamil Nadu, India';

      // ── Primary: Places API (New) with 50 km location bias ───────────────
      final placesResponse = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchText'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleApiKey,
          'X-Goog-FieldMask': 'places.location,places.displayName',
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
          final name = data['places'][0]['displayName']?['text'] ?? stopName;
          debugPrint('Places API: "$stopName" -> "$name" @ ${loc['latitude']},${loc['longitude']}');
          final LatLng pos = LatLng(loc['latitude'].toDouble(), loc['longitude'].toDouble());
          _stopCoords[stopName.toUpperCase()] = pos;
          _updateStopsInFirestore(stopName, pos); // Sync back to Firestore
          return;
        }
        debugPrint('Places API no result for "$stopName", trying Geocoding API');
      } else {
        if (placesResponse.statusCode == 403 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Enable 'Places API (New)' in Google Cloud Console."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        debugPrint('Places API error ${placesResponse.statusCode} for "$stopName"');
      }

      // ── Fallback: Geocoding API with bounding box ────────────────────────
      // SW=10.55,77.58  NE=11.45,78.60 covers ~50km around Karur/Namakkal
      final String encodedQuery = Uri.encodeComponent(query);
      final String geocodeUrl =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?address=$encodedQuery&bounds=10.55,77.58%7C11.45,78.60&region=in&key=$_googleApiKey';
      final geoResponse = await http.get(Uri.parse(geocodeUrl));
      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        if (geoData['status'] == 'OK' && geoData['results'].isNotEmpty) {
          final loc = geoData['results'][0]['geometry']['location'];
          debugPrint('Geocoding API: "$stopName" @ ${loc['lat']},${loc['lng']}');
          final LatLng pos = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          _stopCoords[stopName.toUpperCase()] = pos;
          _updateStopsInFirestore(stopName, pos); // Sync back to Firestore
          return;
        } else {
          debugPrint('Geocoding failed for "$stopName": ${geoData['status']}');
        }
      }

      // ── Last Resort: Hardcoded MKCE Location ────────────────────────────
      if (stopName.toUpperCase().contains('MKCE')) {
        debugPrint('Using hardcoded MKCE location for "$stopName"');
        _stopCoords[stopName.toUpperCase()] = _collegeLocation;
      }
    } catch (e) {
      debugPrint('geocodeStop exception for "$stopName": $e');
    }
  }

  void _zoomToRoute() {
    if (_polylineCoordinates.isEmpty || _mapController == null) return;

    double minLat = _polylineCoordinates.first.latitude;
    double maxLat = _polylineCoordinates.first.latitude;
    double minLng = _polylineCoordinates.first.longitude;
    double maxLng = _polylineCoordinates.first.longitude;

    for (var point in _polylineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ),
    );
  }

  Future<void> _fetchRoadPolyline() async {
    if (_stops.length < 2) return;
    
    _isRouteLoading = true;
    if (mounted) setState(() {});
    
    try {
      List<LatLng> points = [];
      for (var stop in _stops) {
        LatLng? pos = _stopCoords[stop.toUpperCase()];
        if (pos != null) points.add(pos);
      }
      
      if (points.length < 2) return;
      
      final RouteResult result = await MapService.fetchRoadPolyline(points);
      
      if (mounted) {
        setState(() {
          _polylineCoordinates = result.polyline;
          _segmentDistances = result.segmentDistances;
          _segmentDurations = result.segmentDurations;
          _tripDuration = result.totalDuration;
          _tripDistance = result.totalDistance;
          _isRouteLoading = false;
        });
        
        debugPrint("Polyline fetched successfully: ${_polylineCoordinates.length} points");
      }
    } catch (e) {
      debugPrint("Error fetching polyline: $e");
      if (mounted) {
        setState(() {
          _isRouteLoading = false;
          _useFallbackStraightLines();
        });
      }
    }
    
    _updateMapElements();
  }

  void _useFallbackStraightLines() {
    setState(() {
      _polylineCoordinates = _getOrderedStopPoints();
    });
  }

  List<LatLng> _getOrderedStopPoints() {
    List<LatLng> points = [];
    for (var stop in _stops) {
      LatLng? pos = _stopCoords[stop.toUpperCase()];
      if (pos != null) points.add(pos);
    }
    return points;
  }

  void _updateMapElements() {
    Set<Marker> newMarkers = {};
    List<LatLng> fallbackPoints = [];

    for (int i = 0; i < _stops.length; i++) {
      String stop = _stops[i];
      LatLng? pos = _stopCoords[stop.toUpperCase()];
      if (pos == null) continue;

      fallbackPoints.add(pos);

      bool isVisited = i < _currentStopIndex;
      bool isCurrent = i == _currentStopIndex;
      bool isCollege = stop == 'MKCE College Campus';

      newMarkers.add(
        Marker(
          markerId: MarkerId(stop),
          position: pos,
          infoWindow: InfoWindow(title: stop),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCollege ? BitmapDescriptor.hueViolet :
            (isVisited ? BitmapDescriptor.hueGreen : 
            (isCurrent ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueRed))
          ),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
      _polylines = {
        Polyline(
          // Use a unique ID based on point count to force Google Maps to refresh the polyline
          polylineId: PolylineId('route_${_polylineCoordinates.length}'),
          points: _polylineCoordinates.isNotEmpty ? _polylineCoordinates : fallbackPoints,
          color: AppColors.primaryPurple,
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition();
    setState(() {});
    
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          14,
        ),
      );
    }
  }

  void _startLocationTracking() {
    _stopLocationTracking(); 
    
    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Bus tracking is active for students and admin.",
          notificationTitle: "Payanam Tracking Active",
          enableWakeLock: true,
        )
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // 1. Always update Firestore regardless of 'mounted' status to ensure background delivery
      if (_tripStatus == 'running') {
        _authService.updateLocation(
          widget.driverData['driverId'],
          position.latitude,
          position.longitude,
          heading: position.heading,
          currentStopIndex: _currentStopIndex,
        );
      }

      // 2. UI updates only if mounted
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _checkStopProximity(position);
          _updateLiveMetrics(position);
        });
        
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 17.0,
                bearing: position.heading,
                tilt: 45.0,
              ),
            ),
          );
        }
      }
    });
  }

  void _updateLiveMetrics(Position pos) {
    if (_stops.isEmpty || _currentStopIndex >= _stops.length || _tripStatus != 'running') return;

    LatLng? nextStopPos = _stopCoords[_stops[_currentStopIndex].toUpperCase()];
    if (nextStopPos == null) return;

    double distance = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      nextStopPos.latitude, nextStopPos.longitude
    );

    double km = distance / 1000.0;
    // Calculation: 30km/h average = 2 mins per km.
    int minutes = (km * 2).round();

    setState(() {
      _tripDistance = km < 1 ? "${(km * 1000).toInt()} m" : "${km.toStringAsFixed(1)} km";
      _tripDuration = minutes <= 0 ? "Arriving" : "$minutes min";
    });
  }

  void _checkStopProximity(Position pos) {
    if (_stops.isEmpty || _tripStatus != 'running') return;
    
    int furthestReachedIndex = -1;
    
    // Check all upcoming stops to see if we reached any of them
    // This allows skipping stops or detecting a stop even if we missed the exact point of the previous one
    for (int i = _currentStopIndex; i < _stops.length; i++) {
      LatLng? stopPos = _stopCoords[_stops[i].toUpperCase()];
      if (stopPos == null) continue;
      
      double distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, 
        stopPos.latitude, stopPos.longitude
      );
      
      if (distance < 200) { // Keep radius at exactly 200m as requested
        furthestReachedIndex = i;
      }
    }
      
    if (furthestReachedIndex != -1) {
      String reachedStop = _stops[furthestReachedIndex];
      int newIndex = furthestReachedIndex + 1;
      
      setState(() {
        _currentStopIndex = newIndex;
        _updateMapElements();
      });
      
      // Trigger immediate Firestore update so student sees it instantly
      _authService.updateLocation(
        widget.driverData['driverId'],
        pos.latitude,
        pos.longitude,
        heading: pos.heading,
        currentStopIndex: _currentStopIndex,
      );

      // Trigger stop notification to students
      _authService.sendNotification(
        routeId: _canonicalRouteId ?? widget.driverData['routeId'],
        title: "Stop Reached",
        body: "The bus has passed $reachedStop",
        type: "stop",
      );

      // Show snackbar for automatic stop arrival
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passed $reachedStop'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.success,
        ),
      );

      // Automatically end the trip if the final destination is reached
      if (_currentStopIndex >= _stops.length) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _tripStatus == 'running') {
            _handleEndTrip();
          }
        });
      }
    }
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _positionSubscription = null;
    _locationUpdateTimer = null;
  }

  Future<void> _handleStartTrip() async {
    try {
      await _authService.startTrip(
        widget.driverData['driverId'],
        widget.driverData['assignedBus'],
        _canonicalRouteId ?? widget.driverData['routeId'], // Use full canonical ID for student lookup
        _session,
      );
      setState(() {
        _tripStatus = 'running';
        _currentStopIndex = 0;
      });
      
      // Auto-update to the current location's stops if trip started mid-route
      if (_currentPosition != null) {
        _checkStopProximity(_currentPosition!);
      }
      
      _startLocationTracking();
      _updateMapElements();

      // Notify students that the trip has started
      _authService.sendNotification(
        routeId: _canonicalRouteId ?? widget.driverData['routeId'],
        title: "Trip Started",
        body: "$_session trip for Route ${_canonicalRouteId ?? widget.driverData['routeId']} has started.",
        type: "trip",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip Started Successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _handleEndTrip() async {
    try {
      await _authService.endTrip(widget.driverData['driverId']);

      // Notify students
      _authService.sendNotification(
        routeId: _canonicalRouteId ?? widget.driverData['routeId'],
        title: "Trip Ended",
        body: "$_session trip for Route ${_canonicalRouteId ?? widget.driverData['routeId']} has ended.",
        type: "trip",
      );

      setState(() {
        _tripStatus = 'completed';
        // Retain _currentStopIndex so all stops show as passed
        _tripDuration = null;
        _tripDistance = null;
      });
      _stopLocationTracking();
      _updateMapElements();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip Ended Successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showDelayBottomSheet() {
    final reasons = [
      {'name': 'Traffic', 'icon': Icons.traffic_rounded, 'color': Colors.blue},
      {'name': 'Road Construction', 'icon': Icons.construction_rounded, 'color': Colors.orange},
      {'name': 'Student Delay', 'icon': Icons.school_rounded, 'color': Colors.indigo},
      {'name': 'Mechanical issue', 'icon': Icons.settings_rounded, 'color': Colors.red},
      {'name': 'Weather', 'icon': Icons.cloud_rounded, 'color': Colors.cyan},
      {'name': 'Other', 'icon': Icons.more_horiz_rounded, 'color': Colors.grey},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMutedDark.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Report Delay',
              style: AppTextStyles.heading1(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: reasons.length,
              itemBuilder: (context, index) {
                final reason = reasons[index];
                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _submitIssue('delayed', reason['name'] as String);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (reason['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (reason['color'] as Color).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(reason['icon'] as IconData, color: reason['color'] as Color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          reason['name'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIssue(String status, String reason) async {
    try {
      await _authService.reportIssue(widget.driverData['driverId'], status, reason);
      
      // Push notification to students
      await _authService.sendNotification(
        routeId: _canonicalRouteId ?? widget.driverData['routeId'],
        title: status == 'delayed' ? "Bus Delayed" : "Bus Emergency",
        body: reason,
        type: status == 'delayed' ? 'alert' : 'emergency',
      );

      setState(() {
        _tripStatus = status;
        _tripStatus = status; // Replaces redundant local state
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${status.toUpperCase()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isMapMaximized) {
      return Column(
        children: [
          Expanded(child: _buildMapSection()),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildInfoCard(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildMapSection(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatusCard(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStopList(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildControlPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final name = widget.driverData['fullName'] ?? 'Driver';
    final id = widget.driverData['driverId'] ?? 'N/A';
    final bus = widget.driverData['assignedBus'] ?? 'N/A';
    final route = widget.driverData['routeId'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
           Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.2), width: 2),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.person_rounded, size: 28, color: AppColors.primaryPurple),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5),
                ),
                Text(
                  'Employee ID: $id',
                  style: const TextStyle(color: AppColors.textMutedDark, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus_rounded, size: 12, color: AppColors.primaryPurple),
                    const SizedBox(width: 6),
                    Text(bus, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primaryPurple)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ROUTE #${route.contains(' - ') ? route.split(' - ').first.replaceAll(RegExp(r'[^0-9]'), '') : route}',
                  style: const TextStyle(color: AppColors.primaryPurple, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    bool isRunning = _tripStatus == 'running';
    bool isDelayed = _tripStatus == 'delayed';
    bool isEmergency = _tripStatus == 'emergency' || _tripStatus == 'breakdown';
    bool isCompleted = _tripStatus == 'completed';
    
    Color color = isRunning ? AppColors.success : 
                 (isDelayed ? AppColors.warning : 
                 (isEmergency ? AppColors.error : 
                 (isCompleted ? AppColors.primaryPurple : AppColors.textMutedDark)));
    
    String text = isRunning ? 'TRIP IS RUNNING' : 
                 (isDelayed ? 'TRIP DELAYED' : 
                 (isEmergency ? 'EMERGENCY REPORTED' : 
                 (isCompleted ? 'TRIP COMPLETED' : 'WAITING TO START')));

    IconData icon = isRunning ? Icons.play_arrow_rounded : 
                    (isDelayed ? Icons.timer_rounded : 
                    (isEmergency ? Icons.warning_rounded : 
                    (isCompleted ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

    Widget _buildMapSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_isMapMaximized ? 0 : 28),
        border: Border.all(color: AppColors.getBorderColor(context).withValues(alpha: 0.4)),
        boxShadow: _isMapMaximized ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition != null 
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(10.9601, 78.0766),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              // Delay the zoom so the map widget has fully rendered
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) _zoomToRoute();
              });
            },
          ),
          if (_tripDuration != null && _tripDistance != null && _tripStatus == 'running') Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      _tripDuration!,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _tripDistance!,
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              children: [
                _mapActionButton(
                  icon: _isMapMaximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                  onPressed: () => setState(() => _isMapMaximized = !_isMapMaximized),
                ),
                const SizedBox(height: 12),
                _mapActionButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _checkPermissionsAndGetLocation,
                ),
              ],
            ),
          ),
          if (_tripStatus == 'running' && _currentStopIndex < _stops.length) Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.navigation_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('HEADING TO', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        Text(
                          _stops[_currentStopIndex],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapActionButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Icon(icon, color: AppColors.primaryPurple, size: 20),
      ),
    );
  }

  Widget _buildStopList() {
    if (_stops.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LIVE STOP SEQUENCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
              if (_tripStatus == 'inactive' || _tripStatus == 'completed') Row(
                children: [
                   _sessionToggle('Morning'),
                   const SizedBox(width: 8),
                   _sessionToggle('Evening'),
                ],
              ) else Text('${_stops.length} STOPS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMutedDark)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _stops.length,
            itemBuilder: (context, index) {
              bool isVisited = index < _currentStopIndex;
              bool isCurrent = index == _currentStopIndex;
              bool isCollege = _stops[index].toUpperCase().contains('MKCE');
              
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent 
                      ? AppColors.primaryPurple.withValues(alpha: 0.05) 
                      : (isCollege ? Colors.indigo.withValues(alpha: 0.05) : AppColors.getSurfaceCardColor(context)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrent 
                        ? AppColors.primaryPurple 
                        : (isCollege ? Colors.indigo.withValues(alpha: 0.5) : AppColors.getBorderColor(context).withValues(alpha: 0.2)),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isVisited ? Icons.check_circle_rounded : (isCurrent ? Icons.play_circle_fill_rounded : Icons.radio_button_off_rounded),
                          size: 16,
                          color: isVisited ? AppColors.success : (isCurrent ? AppColors.primaryPurple : AppColors.textMutedDark),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVisited ? 'PASSED' : (isCurrent ? 'ACTIVE' : 
                          (isCollege ? (_session == 'Morning' ? 'DESTINATION' : 'ORIGIN') : 'UPCOMING')), 
                          style: TextStyle(
                            fontSize: 8, 
                            fontWeight: FontWeight.w900, 
                            color: isVisited ? AppColors.success : (isCurrent ? AppColors.primaryPurple : AppColors.textMutedDark)
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stops[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 12, 
                        color: isCurrent ? AppColors.primaryPurple : (isVisited ? AppColors.textMutedDark : null)
                      ),
                    ),
                    if (index < _stops.length - 1 && _segmentDistances.containsKey(index)) ...[
                      const SizedBox(height: 2),
                      Text(
                        "${_segmentDistances[index]} • ${_segmentDurations[index]}",
                        style: TextStyle(
                          fontSize: 8, 
                          color: isCurrent ? AppColors.primaryPurple.withValues(alpha: 0.7) : AppColors.textMutedDark, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: (_tripStatus == 'inactive' || _tripStatus == 'completed') ? 'START RUN' : 'STOP RUN',
                icon: (_tripStatus == 'inactive' || _tripStatus == 'completed') ? Icons.play_arrow_rounded : Icons.stop_rounded,
                color: (_tripStatus == 'inactive' || _tripStatus == 'completed') ? AppColors.success : AppColors.error,
                onPressed: (_tripStatus == 'inactive' || _tripStatus == 'completed') ? _handleStartTrip : _handleEndTrip,
                isPrimary: true,
              ),
            ),
             // Manual ARRIVED button removed as requested (automatic detection prioritized)
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'DELAY',
                icon: Icons.access_time_filled_rounded,
                color: AppColors.warning,
                onPressed: _showDelayBottomSheet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                label: 'EMERGENCY',
                icon: Icons.error_rounded,
                color: AppColors.error,
                onPressed: () => _submitIssue('breakdown', 'Mechanical Breakdown reported'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isPrimary ? null : Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : color, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionToggle(String session) {
    bool isSelected = _session == session;
    return InkWell(
      onTap: _tripStatus == 'running' ? null : () {
        setState(() {
          _session = session;
          if (_lastRouteData != null) {
            _processRouteUpdate(_lastRouteData!);
          } else {
            _loadStops(); // Fallback if no stream data yet
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primaryPurple : AppColors.textMutedDark.withValues(alpha: 0.3)),
        ),
        child: Text(
          session.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMutedDark,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class StringUtils {
  static String truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }
}
