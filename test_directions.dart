import 'dart:convert';
import 'dart:io';

void main() async {
  var url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json?origin=11.0050,78.0800&destination=11.1271,78.1217&waypoints=11.0500,78.1000|11.0800,78.1100&mode=driving&key=AIzaSyBOdKcxOtz8wf-LFctkUi8RhZfo0XuesZ4");
  print(url.toString());
  
  var request = await HttpClient().getUrl(url);
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  
  print("Status code: ${response.statusCode}");
  
  var data = json.decode(responseBody);
  print("Status: ${data['status']}");
  if (data['status'] != 'OK') {
    print("Error message: ${data['error_message']}");
  }
}
