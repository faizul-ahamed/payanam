import 'dart:convert';
import 'dart:io';

void main() async {
  // Let's geocode Palapatti and Ammapatti
  var origin = "10.669865,77.940713"; // roughly Palapatti, Karur
  var dest = "10.741000,77.965000"; // roughly Koombur/Ammapatti
  var url = Uri.parse("https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&mode=driving&key=AIzaSyBOdKcxOtz8wf-LFctkUi8RhZfo0XuesZ4");
  var request = await HttpClient().getUrl(url);
  var response = await request.close();
  var responseBody = await response.transform(utf8.decoder).join();
  var data = json.decode(responseBody);
  
  print("Status: ${data['status']}");
}
