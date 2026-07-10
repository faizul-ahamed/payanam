import 'dart:convert';
import 'dart:io';

void main() async {
  // Let's use generic coordinates near Karur
  var url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json?origin=10.9601,78.0756&destination=11.1271,78.1217&mode=driving&key=AIzaSyBOdKcxOtz8wf-LFctkUi8RhZfo0XuesZ4");
  var request = await HttpClient().getUrl(url);
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var data = json.decode(responseBody);
  
  if (data['status'] != 'OK') {
    print("Failed: ${data['status']}");
    return;
  }
  
  var poly = data['routes'][0]['overview_polyline']['points'];
  print("Polyline exists: ${poly.isNotEmpty}");
}
