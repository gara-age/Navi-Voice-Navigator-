import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/response_models.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Uri _base = Uri.parse('http://127.0.0.1:18400');

  Future<SessionStartResponseModel> startSession(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _base.resolve('/session/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return SessionStartResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CommandResponseModel> submitTextCommand(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _base.resolve('/command/text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return CommandResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ScreenReadResponseModel> readScreen(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _base.resolve('/screen/read'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return ScreenReadResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SettingsUpdateResponseModel> updateSettings(Map<String, dynamic> payload) async {
    final response = await _client.post(
      _base.resolve('/settings/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return SettingsUpdateResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SettingsResponseModel> getCurrentSettings() async {
    final response = await _client.get(_base.resolve('/settings/current'));
    return SettingsResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CommandResponseModel> submitVoiceCommand({
    required File audioFile,
    required Map<String, dynamic> metadata,
  }) async {
    final request = http.MultipartRequest('POST', _base.resolve('/command/voice'));
    request.fields['metadata'] = jsonEncode(metadata);
    request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return CommandResponseModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
