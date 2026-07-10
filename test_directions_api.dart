import 'dart:convert';
import 'dart:io';

void main() async {
  var url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json?origin=11.0050,78.0800&destination=11.0050,78.0800&mode=driving&key=AIzaSyBOdKcxOtz8wf-LFctkUi8RhZfo0XuesZ4");
  var request = await HttpClient().getUrl(url);
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var data = json.decode(responseBody);
  
  print("Status: ${data['status']}");
}
