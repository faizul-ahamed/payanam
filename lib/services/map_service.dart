import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter/foundation.dart';
import 'config/api_keys.dart';

class RouteResult {
  final List<LatLng> polyline;
  final String totalDistance;
  final String totalDuration;
  final Map<int, String> segmentDistances;
  final Map<int, String> segmentDurations;

  RouteResult({
    required this.polyline,
    required this.totalDistance,
    required this.totalDuration,
    required this.segmentDistances,
    required this.segmentDurations,
  });
}

class MapService {
  static const String _googleApiKey = ApiKeys.googleMapsKey;

  /// Fetches a road-snapped polyline for a list of stops.
  /// Handles more than 25 stops by chunking the requests.
  static Future<RouteResult> fetchRoadPolyline(List<LatLng> points) async {
    if (points.length < 2) {
      return RouteResult(
        polyline: points,
        totalDistance: "0 km",
        totalDuration: "0 min",
        segmentDistances: {},
        segmentDurations: {},
      );
    }

    List<LatLng> fullPolyline = [];
    double totalMeters = 0;
    int totalSeconds = 0;
    Map<int, String> segmentDistances = {};
    Map<int, String> segmentDurations = {};
    
    int stopOffset = 0;

    // chunk size of 10 stops (9 waypoints) is safe for all Google API tiers
    // and avoids URL length issues.
    const int chunkSize = 10;
    
    for (int i = 0; i < points.length - 1; i += (chunkSize - 1)) {
      int end = (i + chunkSize < points.length) ? i + chunkSize : points.length;
      List<LatLng> chunk = points.sublist(i, end);
      
      if (chunk.length < 2) break;
      
      final LatLng origin = chunk.first;
      final LatLng destination = chunk.last;
      List<LatLng> waypoints = chunk.length > 2 ? chunk.sublist(1, chunk.length - 1) : [];
      
      String waypointsStr = waypoints.map((l) => "${l.latitude},${l.longitude}").join("%7C");
      final url = "https://maps.googleapis.com/maps/api/directions/json?"
          "origin=${origin.latitude},${origin.longitude}&"
          "destination=${destination.latitude},${destination.longitude}&"
          "${waypoints.isNotEmpty ? 'waypoints=$waypointsStr&' : ''}"
          "mode=driving&key=$_googleApiKey";
      
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            
            // Decode Polyline
            final poly = route['overview_polyline']['points'];
            List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(poly);
            fullPolyline.addAll(decodedPoints.map((p) => LatLng(p.latitude, p.longitude)));
            
            // Process Legs
            for (int k = 0; k < route['legs'].length; k++) {
              var leg = route['legs'][k];
              totalSeconds += (leg['duration']['value'] as num).toInt();
              totalMeters += (leg['distance']['value'] as num).toDouble();
              
              segmentDistances[stopOffset] = leg['distance']['text'];
              segmentDurations[stopOffset] = leg['duration']['text'];
              stopOffset++;
            }
          } else {
            debugPrint("Directions API Error for chunk starting at $i: ${data['status']}");
            // Fallback for this segment: use straight lines
            _useFallbackForChunk(chunk, fullPolyline, segmentDistances, segmentDurations, stopOffset);
            stopOffset += (chunk.length - 1);
          }
        } else {
          _useFallbackForChunk(chunk, fullPolyline, segmentDistances, segmentDurations, stopOffset);
          stopOffset += (chunk.length - 1);
        }
      } catch (e) {
        debugPrint("Exception in fetchRoadPolyline for chunk starting at $i: $e");
        _useFallbackForChunk(chunk, fullPolyline, segmentDistances, segmentDurations, stopOffset);
        stopOffset += (chunk.length - 1);
      }
    }

    return RouteResult(
      polyline: fullPolyline,
      totalDistance: "${(totalMeters / 1000).toStringAsFixed(1)} km",
      totalDuration: "${(totalSeconds / 60).round()} min",
      segmentDistances: segmentDistances,
      segmentDurations: segmentDurations,
    );
  }

  static void _useFallbackForChunk(
    List<LatLng> chunk, 
    List<LatLng> fullPolyline,
    Map<int, String> segmentDistances,
    Map<int, String> segmentDurations,
    int startOffset
  ) {
    fullPolyline.addAll(chunk);
    for (int i = 0; i < chunk.length - 1; i++) {
      segmentDistances[startOffset + i] = "N/A";
      segmentDurations[startOffset + i] = "N/A";
    }
  }
}
