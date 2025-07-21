// lib/services/deezer_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Classes/Track.dart'; // se il modello è in un file separato

Future<List<Track>> searchTracks(String query) async {
  final url = Uri.parse('https://api.deezer.com/search?q=$query');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    final List<dynamic> data = json['data'];

    return data.map((item) => Track.fromJson(item)).toList();
  } else {
    throw Exception('Errore durante la ricerca: ${response.statusCode}');
  }
}
