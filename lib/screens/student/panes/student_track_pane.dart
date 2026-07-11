import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../theme/app_theme.dart';
import '../../../services/map_service.dart';
import '../../../config/api_keys.dart';

class StudentTrackPane extends StatefulWidget {
  final Map<String, dynamic> studentData;
  const StudentTrackPane({super.key, required this.studentData});

  @override
  State<StudentTrackPane> createState() => _StudentTrackPaneState();
}

class _StudentTrackPaneState extends State<StudentTrackPane> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  
  StreamSubscription? _routeSubscription;
  String? _canonicalRouteDocId;
  
  final FlutterTts _flutterTts = FlutterTts();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  Map<String, LatLng> _stopCoords = {};
  List<String> _routeStops = [];
  bool _isArrivalAlertTriggered = false;
  StreamSubscription<QuerySnapshot>? _tripSubscription;
  Timer? _refreshTimer;
  
  final String _googleApiKey = ApiKeys.googleMapsKey;
  
  // Centre of the Karur/Namakkal district - used as Places API location bias.
  static const double _routeBiasLat = 11.0050;
  static const double _routeBiasLng = 78.0800;
  static const double _routeBiasRadiusMeters = 50000.0;

  // Curated override: colloquial bus-stop name to precise Google Maps query.
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

  String _currentSession = 'Morning';
  bool _isFollowingBus = true;
  String? _etaText;
  LatLng? _lastBusLocation;
  int _currentStopIndex = 0;
  String? _lastStatus;
  Map<int, String> _segmentDistances = {};
  Map<int, String> _segmentDurations = {};
  String? _tripDuration;
  String? _tripDistance;
  bool _isMapMaximized = false;
  bool _isRouteLoading = true;
  int _lastNotifiedStopIndex = -1; // Prevent duplicate stop notifications
  String? _lastNotifiedStatus;     // Prevent duplicate status (Delayed/Breakdown) notifications

  @override
  void initState() {
    super.initState();
    _tripSubscription = FirebaseFirestore.instance.collection('trips')
        .where('status', whereIn: ['running', 'delayed', 'breakdown', 'completed'])
        .snapshots()
        .listen(_handleTripUpdate);
    _initializeNotifications();
    _setupRouteStream(); // Replaces _loadStops() with real-time sync
    _setupTts();
    
    // Auto-refresh every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        debugPrint("Refreshing tracking data...");
        _setupRouteStream();
      }
    });

    _startBackgroundPresence();
  }

  StreamSubscription<Position>? _backgroundPositionSubscription;

  void _startBackgroundPresence() {
    _backgroundPositionSubscription?.cancel();
    
    late LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.low, // Use low accuracy to save battery for students
        distanceFilter: 10,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Tracking bus status for your route in background.",
          notificationTitle: "Payanam Monitoring Active",
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
      // Just receiving location to keep the app process alive for Firestore listeners
    });
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _routeSubscription?.cancel();
    _refreshTimer?.cancel();
    _backgroundPositionSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _setupRouteStream() async {
    final String routeId = widget.studentData['routeId'] ?? '';
    
    // Find the canonical route document first
    final routeQuery = await FirebaseFirestore.instance.collection('routes').get();
    final List<DocumentSnapshot> matches = routeQuery.docs.where((doc) {
      final name = (doc.data() as Map<String, dynamic>)['name']?.toString() ?? '';
      return name == routeId || name.startsWith(routeId) || routeId.startsWith(name);
    }).toList();

    if (matches.isNotEmpty) {
      _canonicalRouteDocId = matches.first.id;
      _routeSubscription = FirebaseFirestore.instance.collection('routes')
          .doc(_canonicalRouteDocId)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
               _processRouteUpdate(snapshot.data() as Map<String, dynamic>);
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

        // Determine session (either from active trip or default to Morning)
        String session = _currentSession; 
        final tripQuery = await FirebaseFirestore.instance.collection('trips')
            .where('routeId', isEqualTo: widget.studentData['routeId'])
            .limit(1).get();
        if (tripQuery.docs.isNotEmpty) {
           session = tripQuery.docs.first.data()['currentSession'] ?? tripQuery.docs.first.data()['session'] ?? 'Morning';
        }

        if (session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.insert(0, 'MKCE College Campus');
        }

        if (mounted) {
          setState(() {
            _routeStops = stopsList;
            _currentSession = session;
            _stopCoords = coordsFromFirestore;
            _isRouteLoading = true;
          });

          await _geocodeStops(stopsList); // Geocode missing ones
          await _fetchRoadPolyline();
          _updateMarkers();
          if (mounted) setState(() => _isRouteLoading = false);
        }
      } catch (e) {
        debugPrint("Error processing route stream update: $e");
      }
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  Future<void> _loadStops({String? sessionOverride}) async {
    try {
      final String routeId = widget.studentData['routeId'] ?? '';
      String session = sessionOverride ?? 'Morning';
      if (sessionOverride == null) {
        final tripQuery = await FirebaseFirestore.instance.collection('trips')
            .where('routeId', isEqualTo: routeId)
            .limit(1)
            .get();
        if (tripQuery.docs.isNotEmpty) {
          session = tripQuery.docs.first.data()['currentSession'] ?? tripQuery.docs.first.data()['session'] ?? 'Morning';
        }
      }

      if (session == _currentSession && _routeStops.isNotEmpty) return;

      // 1. Try Firestore first
      final routeQuery = await FirebaseFirestore.instance.collection('routes')
          .where('name', isEqualTo: routeId)
          .limit(1)
          .get();
          
      if (routeQuery.docs.isNotEmpty) {
        final routeData = routeQuery.docs.first.data();
        final List<dynamic> stopsData = routeData['stops'] ?? [];
        List<String> stopsList = stopsData.map((s) => s['name'].toString().trim()).toList();
        Map<String, LatLng> coordsFromFirestore = {};
        for (var s in stopsData) {
          final stopName = s['name']?.toString().trim() ?? "";
          if (s['lat'] != 0.0 && s['lng'] != 0.0 && stopName.isNotEmpty) {
            coordsFromFirestore[stopName.toUpperCase()] = LatLng(s['lat'].toDouble(), s['lng'].toDouble());
          }
        }

        if (session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.insert(0, 'MKCE College Campus');
        }

        setState(() {
          _routeStops = stopsList;
          _currentSession = session;
          _stopCoords.addAll(coordsFromFirestore);
          _isRouteLoading = true;
        });

        await _geocodeStops(stopsList); // Geocode anything missing
        await _fetchRoadPolyline();
        _updateMarkers();
        _zoomToRoute();
        if (mounted) setState(() => _isRouteLoading = false);
        return;
      }

      // 2. Fallback to JSON
      final String response = await rootBundle.loadString('assets/data/bus_routes.json');
      final data = json.decode(response);
      
      if (data.containsKey(routeId)) {
        List<String> stopsList = List<String>.from(data[routeId]).map((s) => s.trim()).toList();
        
        if (session == 'Morning') {
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.add('MKCE College Campus');
        } else {
          stopsList = stopsList.reversed.toList();
          if (!stopsList.any((s) => s.toUpperCase() == 'MKCE COLLEGE CAMPUS')) stopsList.insert(0, 'MKCE College Campus');
        }

        setState(() {
          _routeStops = stopsList;
          _currentSession = session;
          _isRouteLoading = true;
        });
        
        await _geocodeStops(stopsList);
        await _fetchRoadPolyline();
        _updateMarkers();
        _zoomToRoute();
        if (mounted) setState(() => _isRouteLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
      if (mounted) setState(() => _isRouteLoading = false);
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
        50.0,
      ),
    );
  }

  Future<void> _geocodeStops(List<String> stops) async {
    await Future.wait(stops.map((stop) => _geocodeStop(stop)));
    if (mounted) setState(() {});
  }

  Future<void> _geocodeStop(String stop) async {
    // ONLY geocode if coordinates are missing or zero
    if (_stopCoords.containsKey(stop.toUpperCase())) {
      final existing = _stopCoords[stop.toUpperCase()]!;
      if (existing.latitude != 0.0 && existing.longitude != 0.0) {
        return; // Use coordinates from Firestore (Admin's edits)
      }
    }

    try {
      final String query = _stopQueryOverrides[stop] ?? _stopQueryOverrides[stop.toUpperCase()] ?? '$stop, Karur, Tamil Nadu, India';

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
          final LatLng pos = LatLng(loc['latitude'].toDouble(), loc['longitude'].toDouble());
          _stopCoords[stop.toUpperCase()] = pos;
          _updateStopsInFirestore(stop, pos); // Sync back to Firestore
          return;
        }
      }

      // 2. Fallback to Geocoding API
      final geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&bounds=10.55,77.58%7C11.45,78.60&region=in&key=$_googleApiKey';
      final geoResponse = await http.get(Uri.parse(geocodeUrl));
      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        if (geoData['status'] == 'OK' && geoData['results'].isNotEmpty) {
          final loc = geoData['results'][0]['geometry']['location'];
          final LatLng pos = LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
          _stopCoords[stop.toUpperCase()] = pos;
          _updateStopsInFirestore(stop, pos); // Sync back to Firestore
        }
      }
    } catch (e) {
      debugPrint("Geocoding failed for $stop: $e");
    }
  }

  // Write back geocoded coordinates to Firestore so Admin and other users benefit
  Future<void> _updateStopsInFirestore(String stopName, LatLng pos) async {
    try {
      final String routeId = widget.studentData['routeId'] ?? '';
      
      // Fuzzy matching lookup
      final routeQuery = await FirebaseFirestore.instance.collection('routes').get();
      final List<DocumentSnapshot> matches = routeQuery.docs.where((doc) {
        final name = (doc.data() as Map<String, dynamic>)['name']?.toString() ?? '';
        return name == routeId || name.startsWith(routeId) || routeId.startsWith(name);
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
      debugPrint("Student: Failed to sync stops: $e");
    }
  }

  Future<void> _fetchRoadPolyline() async {
    if (_routeStops.length < 2) return;
    
    _isRouteLoading = true;
    if (mounted) setState(() {});

    try {
      List<LatLng> points = [];
      for (var stop in _routeStops) {
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
      }
    } catch (e) {
      debugPrint("Polyline fetch failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error drawing route: $e"),
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.red,
        ));
        setState(() {
          _isRouteLoading = false;
        });
      }
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route_path_${_polylineCoordinates.length}'),
          points: _polylineCoordinates.isNotEmpty ? _polylineCoordinates : _getOrderedStopPoints(),
          color: AppColors.primaryPurple,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });
  }

  List<LatLng> _getOrderedStopPoints() {
    List<LatLng> points = [];
    for (var stop in _routeStops) {
      LatLng? pos = _stopCoords[stop.toUpperCase()];
      if (pos != null) points.add(pos);
    }
    return points;
  }

  void _updateMarkers({LatLng? busLocation}) {
    if (busLocation != null) {
      _lastBusLocation = busLocation;
    }
    
    LatLng? locationToShow = busLocation ?? _lastBusLocation;
    Set<Marker> newMarkers = {};
    
    for (int i = 0; i < _routeStops.length; i++) {
      String stop = _routeStops[i];
      LatLng? pos = _stopCoords[stop.toUpperCase()];
      if (pos == null) continue;

      bool isVisited = i < _currentStopIndex;
      bool isCurrent = i == _currentStopIndex;
      bool isCollege = stop.toUpperCase() == 'MKCE COLLEGE CAMPUS';
      bool isStudentStop = stop.toUpperCase() == (widget.studentData['stopId'] ?? "").toUpperCase();

      newMarkers.add(
        Marker(
          markerId: MarkerId(stop),
          position: pos,
          infoWindow: InfoWindow(title: stop, snippet: isStudentStop ? "YOUR STOP" : null),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCollege ? BitmapDescriptor.hueViolet :
            (isVisited ? BitmapDescriptor.hueGreen : 
            (isCurrent ? BitmapDescriptor.hueCyan : BitmapDescriptor.hueRed))
          ),
        ),
      );
    }
    
    // Add Bus Marker
    if (locationToShow != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('bus_marker'),
          position: locationToShow,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: "LIVE BUS LOCATION"),
          zIndex: 2, // Ensure bus is above stops
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _handleStatusUpdate(String status, String? reason) async {
    if (_lastNotifiedStatus == status) return;
    String oldStatus = _lastNotifiedStatus ?? 'None';
    _lastNotifiedStatus = status;
    
    // Don't alert if it's the first time we load the status and it's 'running'
    if (oldStatus == 'None' && status == 'running') return;

    if (status == 'delayed') {
      await _flutterTts.speak("The bus is delayed. Reason: ${reason ?? 'Unknown'}");
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 1000);
      }
    } else if (status == 'breakdown') {
      await _flutterTts.speak("Emergency alert. The bus has reported a breakdown.");
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
    }
  }

  void _handleBusLocationUpdate(LatLng busLocation, double heading, int firestoreStopIndex) {
    bool indexChanged = _currentStopIndex != firestoreStopIndex;
    bool hasMoved = _lastBusLocation == null || 
                    _lastBusLocation!.latitude != busLocation.latitude || 
                    _lastBusLocation!.longitude != busLocation.longitude;
    
    if (indexChanged || hasMoved) {
      if (mounted) {
        setState(() {
          _currentStopIndex = firestoreStopIndex;
          _lastBusLocation = busLocation;
          _updateMarkers(busLocation: busLocation);
        });

        // Voice alert + vibration for every stop reached
        if (indexChanged && firestoreStopIndex > 0 && firestoreStopIndex <= _routeStops.length) {
          bool voiceEnabled = widget.studentData['voiceEnabled'] ?? true;
          bool vibrationEnabled = widget.studentData['vibrationEnabled'] ?? true;
          
          String reachedStop = _routeStops[firestoreStopIndex - 1];
          String studentStop = (widget.studentData['stopId'] ?? "").toUpperCase();
          bool isMyStop = reachedStop.toUpperCase() == studentStop;

          // Voice Alert
          if (voiceEnabled) {
            if (isMyStop) {
              _flutterTts.speak("Attention! Your stop $reachedStop has been reached. Please get ready.");
            } else {
              _flutterTts.speak("Bus reached $reachedStop");
            }
          }

          // Vibration Alert
          if (vibrationEnabled) {
            Vibration.hasVibrator().then((has) {
              if (has ?? false) {
                if (isMyStop) {
                  Vibration.vibrate(pattern: [500, 1000, 500, 1000, 500, 1000]);
                } else {
                  Vibration.vibrate(duration: 500);
                }
              }
            });
          }

          // Local Notification
          bool pushEnabled = widget.studentData['pushEnabled'] ?? true;
          if (pushEnabled) {
            const androidDetails = AndroidNotificationDetails(
              'stop_alerts',
              'Stop Arrival Alerts',
              importance: Importance.high,
              priority: Priority.high,
            );
            const iosDetails = DarwinNotificationDetails();
            const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
          // Only Notify if we haven't notified for this specific index before
          if (_lastNotifiedStopIndex != firestoreStopIndex) {
              _lastNotifiedStopIndex = firestoreStopIndex;
              _notificationsPlugin.show(
                id: firestoreStopIndex,
                title: isMyStop ? '🚌 Your Stop Reached!' : 'Stop Reached',
                body: isMyStop
                    ? 'The bus has reached $reachedStop — your stop!'
                    : 'The bus has reached $reachedStop',
                notificationDetails: details,
              );
          }
          }
        }
      }
    }

    if (hasMoved && _isFollowingBus && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: busLocation,
            zoom: 17.0,
            bearing: heading,
            tilt: 45.0,
          ),
        ),
      );
    }

    // Calculate distance and ETA to student stop
    String studentStop = (widget.studentData['stopId'] ?? "").toUpperCase();
    LatLng? stopLoc = _stopCoords[studentStop];
    
    if (stopLoc != null) {
      double distance = Geolocator.distanceBetween(
        busLocation.latitude, busLocation.longitude,
        stopLoc.latitude, stopLoc.longitude
      );
      
      double km = distance / 1000.0;
      int minutes = (km * 2).round(); // Sync with driver: 2 mins per km
      String newEtaText = distance < 500 ? "Arriving Now" : "$minutes mins (${km.toStringAsFixed(1)} km)";
      
      if (_etaText != newEtaText) {
        if (mounted) {
          setState(() {
            _etaText = newEtaText;
          });
        }
      }

      if (distance <= 200 && !_isArrivalAlertTriggered) {
        _triggerArrivalAlert();
      }
    }
  }

  void _handleTripUpdate(QuerySnapshot snapshot) {
    if (!mounted) return;

    final String studentRouteId = widget.studentData['routeId'] ?? '';
    final String studentRouteNum = studentRouteId.contains(' - ') 
        ? studentRouteId.split(' - ').first.trim() 
        : studentRouteId;

    String normalize(String s) {
      return s.toLowerCase().replaceAll('route', '').replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
    }

    final String normalizedStudentRoute = normalize(studentRouteId);
    final String normalizedStudentRouteNum = normalize(studentRouteNum);

    final matchingTrips = snapshot.docs.where((doc) {
      final tripData = doc.data() as Map<String, dynamic>;
      final tripRouteId = tripData['routeId']?.toString() ?? '';
      final normalizedTripRoute = normalize(tripRouteId);
      
      return normalizedTripRoute == normalizedStudentRoute || 
             normalizedTripRoute == normalizedStudentRouteNum ||
             normalizedTripRoute.contains(normalizedStudentRoute) ||
             normalizedStudentRoute.contains(normalizedTripRoute);
    });

    if (matchingTrips.isEmpty) {
      if (_lastStatus != "BUS NOT STARTED") {
        setState(() {
          _lastStatus = "BUS NOT STARTED";
        });
      }
      return;
    }

    final tripData = matchingTrips.first.data() as Map<String, dynamic>;
    String status = tripData['status'] ?? 'running';
    String? reason = tripData['issueReason'];
    int firestoreStopIndex = (tripData['currentStopIndex'] ?? 0).toInt();
    String currentSession = tripData['currentSession'] ?? tripData['session'] ?? 'Morning';
    GeoPoint? gp = tripData['lastLocation'];
    double heading = (tripData['heading'] ?? 0.0).toDouble();

    // 0. Status Sync (Alerts)
    _handleStatusUpdate(status, reason);
    
    // Perform updates in next frame to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      setState(() {
        _lastStatus = status;
        if (status == 'completed') {
          _etaText = "Trip Completed";
        }
        
        // 1. Session Sync
        if (currentSession != _currentSession) {
          _loadStops(sessionOverride: currentSession);
        }
        
        // 2. Stop Index & Location Sync
        if (gp != null) {
          LatLng busLoc = LatLng(gp.latitude, gp.longitude);
          _handleBusLocationUpdate(busLoc, heading, firestoreStopIndex);
        } else if (_currentStopIndex != firestoreStopIndex) {
          // If location is null but index changed, update index and markers
          _currentStopIndex = firestoreStopIndex;
          _updateMarkers(busLocation: _lastBusLocation);
        }
      });
    });
  }

  void _triggerArrivalAlert() async {
    _isArrivalAlertTriggered = true;
    
    // 1. Voice Announcement
    await _flutterTts.speak("Your bus has arrived near your stop. Please be ready.");
    
    // 2. Vibration
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
    }
    
    // 3. Notification
    const androidDetails = AndroidNotificationDetails(
      'bus_arrival',
      'Bus Arrival Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _notificationsPlugin.show(
      id: 0,
      title: 'Bus Arriving Soon!',
      body: 'Your bus is within 200 meters of your stop.',
      notificationDetails: details,
    );

    // 4. In-app popup
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Bus Arriving!"),
          content: const Text("Your bus is within 200 meters of your stop. Please head to the boarding point."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isMapMaximized) _buildBusStatusHeader(),
        Expanded(
          flex: _isMapMaximized ? 1 : 0,
          child: SizedBox(
            height: _isMapMaximized ? null : 350,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(11.0050, 78.0800),
                    zoom: 12,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    if (_polylineCoordinates.isNotEmpty) _zoomToRoute();
                  },
                  onCameraMoveStarted: () {
                    // Only disable follow if the user manually moved the map? 
                    // flutter_maps doesn't give us the reason easily.
                    // But we can check if it was triggered by a programmatic move.
                    // For now, let's keep it enabled as requested by user.
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: true,
                  indoorViewEnabled: false,
                  padding: const EdgeInsets.only(bottom: 20),
                ),
                
                // Map Controls
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapButton(
                        icon: _isMapMaximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                        onPressed: () => setState(() => _isMapMaximized = !_isMapMaximized),
                      ),
                      const SizedBox(height: 12),
                      _buildMapButton(
                        icon: _isFollowingBus ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: _isFollowingBus ? AppColors.primaryPurple : AppColors.textMutedDark,
                        onPressed: () {
                          setState(() => _isFollowingBus = !_isFollowingBus);
                          if (_isFollowingBus && _lastBusLocation != null) {
                            _mapController!.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(target: _lastBusLocation!, zoom: 17, tilt: 45)
                              )
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMapButton(
                        icon: Icons.route_rounded,
                        onPressed: _zoomToRoute,
                      ),
                    ],
                  ),
                ),

                // Loading Overlay
                if (_isRouteLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceCardColor(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
                            ),
                            const SizedBox(width: 16),
                            const Text("Loading Route...", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                if (!_isMapMaximized) _buildFloatingEtaCard(),
              ],
            ),
          ),
        ),
        if (!_isMapMaximized) _buildStopListPanel(),
      ],
    );
  }

  Widget _buildBusStatusHeader() {
    String statusText = "BUS NOT STARTED";
    Color statusColor = Colors.grey;
    String status = _lastStatus ?? "unknown";

    if (status == 'running') {
      statusText = "BUS RUNNING";
      statusColor = AppColors.success;
    } else if (status == 'delayed') {
      statusText = "BUS DELAYED";
      statusColor = AppColors.warning;
    } else if (status == 'breakdown') {
      statusText = "BUS BREAKDOWN / EMERGENCY";
      statusColor = AppColors.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(
            statusText == "BUS NOT STARTED" ? Icons.cloud_off_rounded : 
            (statusColor == AppColors.error ? Icons.warning_rounded : Icons.directions_bus_rounded), 
            color: statusColor, size: 20
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(fontWeight: FontWeight.w900, color: statusColor, fontSize: 13, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingEtaCard() {
    return Positioned(
      bottom: 20, left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceCardColor(context).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryPurple,
              child: Icon(Icons.timer, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Estimated Arrival", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(_etaText ?? "Calculating...", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            TextButton(
              onPressed: _zoomToRoute,
              child: const Text("FULL ROUTE"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 20, right: 20,
      child: Column(
        children: [
          _buildMapButton(
            icon: _isFollowingBus ? Icons.gps_fixed : Icons.gps_not_fixed,
            color: _isFollowingBus ? AppColors.primaryPurple : Colors.grey,
            onPressed: () {
              setState(() => _isFollowingBus = !_isFollowingBus);
              if (_isFollowingBus && _lastBusLocation != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLng(_lastBusLocation!));
              }
            },
          ),
          const SizedBox(height: 12),
          _buildMapButton(
            icon: Icons.layers_outlined,
            onPressed: () {}, // Future: Toggle satellite view
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onPressed, Color? color}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(icon, color: color ?? AppColors.primaryPurple, size: 20),
        ),
      ),
    );
  }

  Widget _buildStopListPanel() {
    if (_routeStops.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ROUTE PROGRESS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                Text('${_routeStops.length} STOPS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMutedDark)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 105,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _routeStops.length,
              itemBuilder: (context, index) {
                bool isVisited = index < _currentStopIndex;
                bool isCurrent = index == _currentStopIndex;
                bool isStudentStop = _routeStops[index].toUpperCase() == (widget.studentData['stopId'] ?? "").toUpperCase();
                
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent 
                        ? AppColors.primaryPurple.withValues(alpha: 0.05) 
                        : (isVisited ? AppColors.success.withValues(alpha: 0.1) : 
                           (isStudentStop ? AppColors.success.withValues(alpha: 0.05) : AppColors.getSurfaceCardColor(context))),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrent 
                          ? AppColors.primaryPurple 
                          : (isVisited ? AppColors.success.withValues(alpha: 0.8) : 
                             (isStudentStop ? AppColors.success.withValues(alpha: 0.5) : AppColors.getBorderColor(context).withValues(alpha: 0.2))),
                      width: isCurrent || isVisited || isStudentStop ? 2 : 1,
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
                            isStudentStop ? 'YOUR STOP' : (isVisited ? 'PASSED' : (isCurrent ? 'ACTIVE' : 'UPCOMING')), 
                            style: TextStyle(
                              fontSize: 8, 
                              fontWeight: FontWeight.w900, 
                              color: isStudentStop ? AppColors.primaryPurple : (isVisited ? AppColors.success : (isCurrent ? AppColors.primaryPurple : AppColors.textMutedDark))
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _routeStops[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 12, 
                          color: isCurrent ? AppColors.primaryPurple : (isVisited ? AppColors.textMutedDark : null)
                        ),
                      ),
                      if (index < _routeStops.length - 1 && _segmentDistances.containsKey(index)) ...[
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
      ),
    );
  }
}
