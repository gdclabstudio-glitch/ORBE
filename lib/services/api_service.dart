import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'observability_service.dart';

class ApiService {
  final AuthService? _authService;

  // Resilience defaults
  static const Duration _defaultTimeout = Duration(seconds: 12);
  static const int _maxRetries = 3; // total attempts (initial + retries)

  ApiService({AuthService? authService}) : _authService = authService;

  String get _base => ApiConfig.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    try {
      final token =
          _authService == null ? null : await _authService!.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e, s) {
      // Report non-fatal error for diagnostics via ObservabilityService
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService._authHeaders',
      );
    }
    return headers;
  }

  // Generic retry wrapper with exponential backoff for network operations
  Future<T> _withRetries<T>(Future<T> Function() operation) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation().timeout(_defaultTimeout);
      } on SocketException catch (e, s) {
        if (attempt >= _maxRetries) {
          await ObservabilityService.reportError(
            e,
            s,
            reason: 'ApiService.withRetriesExhausted',
          );
          rethrow;
        }
        final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future.delayed(delay);
      } on TimeoutException catch (e, s) {
        if (attempt >= _maxRetries) {
          await ObservabilityService.reportError(
            e,
            s,
            reason: 'ApiService.withRetriesExhausted',
          );
          rethrow;
        }
        final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future.delayed(delay);
      }
    }
  }

  // --- Rotas P�blicas ---

  Future<Map<String, dynamic>> getEventConfig() async {
    try {
      final response = await _withRetries(
        () => http.get(Uri.parse(_base + '/event')),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Falha ao carregar configurações do evento');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.getEventConfig',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }

  Future<Map<String, dynamic>> getContent() async {
    try {
      final response = await _withRetries(
        () => http.get(Uri.parse(_base + '/content')),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Falha ao carregar conteúdo');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.getContent',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }

  Future<List<dynamic>> getPricing() async {
    try {
      final response = await _withRetries(
        () => http.get(Uri.parse(_base + '/pricing')),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Falha ao carregar lotes de preço');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.getPricing',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }

  // --- Rotas PrivADAS ---

  Future<void> updateEventConfig(Map<String, dynamic> data) async {
    try {
      final headers = await _authHeaders();
      final response = await _withRetries(
        () => http.put(
          Uri.parse(_base + '/event'),
          headers: headers,
          body: jsonEncode(data),
        ),
      );
      if (response.statusCode != 200)
        throw Exception('Falha ao atualizar evento');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.updateEventConfig',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }

  Future<void> updateRules(List<String> rules) async {
    try {
      final headers = await _authHeaders();
      final response = await _withRetries(
        () => http.put(
          Uri.parse(_base + '/content/rules'),
          headers: headers,
          body: jsonEncode({'rules': rules}),
        ),
      );
      if (response.statusCode != 200)
        throw Exception('Falha ao atualizar regras');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.updateRules',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }

  Future<String> uploadMedia(List<int> fileBytes, String filename) async {
    try {
      Future<http.Response> sendMultipart() async {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(_base + '/media/upload'),
        );
        final headers = await _authHeaders();
        request.headers.addAll(headers);
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
        );
        var streamedResponse = await request.send();
        return await http.Response.fromStream(streamedResponse);
      }

      final response = await _withRetries(() => sendMultipart());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
      throw Exception('Falha ao fazer upload da mídia');
    } on SocketException catch (e, s) {
      await ObservabilityService.reportError(
        e,
        s,
        reason: 'ApiService.uploadMedia',
      );
      throw Exception('Conexão falhou: ' + e.toString());
    }
  }
}
