import 'dart:core';
void main() {
  try {
    Uri uri = Uri.parse("https://maps.googleapis.com/maps/api/directions/json?origin=1,2&destination=3,4&waypoints=5,6|7,8");
    print("Parsed successfully. scheme: ${uri.scheme}, query: ${uri.query}");
  } catch (e) {
    print("Exception thrown: $e");
  }
}
