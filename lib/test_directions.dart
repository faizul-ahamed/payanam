import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config/api_keys.dart';

void main() async {
  final apiKey = ApiKeys.googleMapsKey;
  final waypoints = List.generate(25, (i) => "11.00$i,78.00$i").join("|");
  final origin = "11.0,78.0";
  final dest = "11.1,78.1";
  
  final url = "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&waypoints=$waypoints&mode=driving&key=$apiKey";
  final response = await http.get(Uri.parse(url));
  
  if (response.statusCode == 200) {
    print(json.decode(response.body)['status']);
  } else {
    print("Error ${response.statusCode}");
  }
}
