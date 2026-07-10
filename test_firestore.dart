import 'dart:convert';
import 'dart:io';

void main() async {
  var url = Uri.parse("https://firestore.googleapis.com/v1/projects/payanam-681cd/databases/(default)/documents/routes");
  var request = await HttpClient().getUrl(url);
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var data = json.decode(responseBody);
  
  if (data['documents'] != null) {
    for (var doc in data['documents']) {
      print("Route: ${doc['name']}");
      var fields = doc['fields'];
      if (fields != null && fields['stops'] != null) {
        var stops = fields['stops']['arrayValue']['values'];
        print("  Stops count: ${stops?.length ?? 0}");
        if (stops != null) {
          for (var stop in stops) {
            var stopFields = stop['mapValue']['fields'];
            if (stopFields != null) {
              var name = stopFields['name']?['stringValue'] ?? 'Unknown';
              var lat = stopFields['lat']?['doubleValue'] ?? stopFields['lat']?['integerValue'] ?? 0.0;
              var lng = stopFields['lng']?['doubleValue'] ?? stopFields['lng']?['integerValue'] ?? 0.0;
              print("    - $name ($lat, $lng)");
            }
          }
        }
      }
    }
  } else {
    print("No documents found or error: $data");
  }
}
