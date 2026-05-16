import 'dart:convert';
import 'dart:io';

void main() {
  final jsonString = File('assets/data/bus_routes.json').readAsStringSync();
  final routesData = json.decode(jsonString);
  
  for (final routeEntry in routesData.entries) {
    if (routeEntry.key == 'Route 9 - MOHANUR') continue;
    List stops = routeEntry.value;
    print('${routeEntry.key} has ${stops.length} stops.');
  }
}
