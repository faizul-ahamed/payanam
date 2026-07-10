import 'package:flutter_polyline_points/flutter_polyline_points.dart';
void main() {
  try {
    var result1 = PolylinePoints.decodePolyline("q{p_A{_p_A");
    print("Static works");
  } catch (e) {
    print("Static failed: $e");
  }
}
