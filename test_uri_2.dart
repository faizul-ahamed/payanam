import 'package:http/http.dart' as http;

void main() {
  try {
    var uri = Uri.parse("https://google.com/?waypoints=11.0,78.0|11.1,78.1");
    print(uri.toString());
  } catch (e) {
    print("Error: $e");
  }
}
