import 'dart:convert';
import 'dart:io';

Future<void> test() async {
  List<List<double>> points = [
    [11.0050, 78.0800],
    [11.0200, 78.0900],
    [11.0500, 78.1000],
    [11.0800, 78.1100],
    [11.1271, 78.1217]
  ];
  
  String apiKey = "AIzaSyBOdKcxOtz8wf-LFctkUi8RhZfo0XuesZ4";
  
  final origin = points.first;
  final destination = points.last;
  List<List<double>> waypoints = points.length > 2 ? points.sublist(1, points.length - 1) : [];
  
  String waypointsStr = waypoints.map((l) => "${l[0]},${l[1]}").join("|");
  final url = "https://maps.googleapis.com/maps/api/directions/json?"
      "origin=${origin[0]},${origin[1]}&"
      "destination=${destination[0]},${destination[1]}&"
      "${waypoints.isNotEmpty ? 'waypoints=$waypointsStr&' : ''}"
      "mode=driving&key=$apiKey";
      
  print("URL: $url");
  
  var request = await HttpClient().getUrl(Uri.parse(url));
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var data = json.decode(responseBody);
  
  print("Status: ${data['status']}");
  if (data['status'] != 'OK') {
    print("Error: ${data['error_message']}");
  } else {
    var route = data['routes'][0];
    print("Legs count: ${route['legs'].length}");
    try {
      for (int k = 0; k < route['legs'].length; k++) {
        var leg = route['legs'][k];
        int dur = leg['duration']['value'] as int;
        double dist = (leg['distance']['value'] as num).toDouble();
      }
      print("Parsed legs successfully.");
    } catch(e) {
      print("Error parsing legs: $e");
    }
  }
}

void main() async {
  await test();
}
