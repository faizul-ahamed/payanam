import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'config/api_keys.dart';

void main() async {
  final apiKey = ApiKeys.googleMapsKey;
  final jsonString = File('assets/data/bus_routes.json').readAsStringSync();
  final routesData = json.decode(jsonString);
  
  for (final routeEntry in routesData.entries) {
    print('Testing ${routeEntry.key}...');
    // We simulate geocoding by using a mock coordinate for all stops
    // except if we use the real geocode it takes time. Let's just 
    // test the waypoint limits or string generation if we had it.
  }
}
