import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void main() {
  PolylinePoints polylinePoints = PolylinePoints();
  var result = polylinePoints.decodePolyline("q{p_A{_p_A");
  print("DECODED: $result");
}
