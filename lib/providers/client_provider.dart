import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/storage_service.dart';
import '../services/storage_mobile.dart';

import 'package:uuid/uuid.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';

import '../models/client.dart';

abstract class IClientRepository {
  Future<List<Client>> fetchClients();
  Future<void> saveClients(List<Client> clients);
}

class SecureClientRepository implements IClientRepository {
  final StorageService secureStorage;
  static const _clientsKey = 'secure_labomba_clients';

  SecureClientRepository(this.secureStorage);

  @override
  Future<List<Client>> fetchClients() async {
    final saved = await secureStorage.read(key: _clientsKey);
    if (saved == null) return [];

    // 3. Alta Performance: Utilizando Isolates (compute) para decode
    return await compute(_decodeClients, saved);
  }

  @override
  Future<void> saveClients(List<Client> clients) async {
    // 3. Alta Performance: Utilizando Isolates (compute) para encode
    final jsonStr = await compute(_encodeClients, clients);
    await secureStorage.write(key: _clientsKey, value: jsonStr);
  }

  static List<Client> _decodeClients(String jsonString) {
    final decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((e) => Client.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static String _encodeClients(List<Client> clients) {
    return jsonEncode(clients.map((c) => c.toJson()).toList());
  }
}

class ClientProvider with ChangeNotifier {
  final IClientRepository _repository;
  List<Client> _clients = [];
  bool _isLoading = false;

  // 1. Separação de Responsabilidades (SRP) via Injeção de Dependência
  ClientProvider({IClientRepository? repository})
      : _repository =
            repository ?? SecureClientRepository(MobileStorageService()) {
    _loadClients();
  }

  List<Client> get clients => List.unmodifiable(_clients);
  bool get isLoading => _isLoading;

  Future<void> _loadClients() async {
    _isLoading = true;
    notifyListeners();
    try {
      _clients = await _repository.fetchClients();
    } catch (e) {
      debugPrint('Falha ao ler clientes seguros: $e');
      // 6. Proteção de Dados: Não utilizamos _clients.clear() caso ocorra um erro de leitura.
      // Isso protege contra race conditions ou falha de leitura corrompendo os dados gravados.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Client> registerClient({
    required String fullName,
    required DateTime birthDate,
    required String cpf,
    required String phone,
    required bool acceptedTerms,
  }) async {
    if (!acceptedTerms) {
      throw const ClientRegistrationException(
        'É obrigatório aceitar o termo de responsabilidade.',
      );
    }

    // 5. Validação de Dados (CPF)
    if (!CPFValidator.isValid(cpf)) {
      throw const ClientRegistrationException('CPF inválido.');
    }

    final newClient = Client(
      id: const Uuid().v4(), // 4. Identificadores Únicos Seguros (UUID v4)
      fullName: fullName.trim(),
      birthDate: birthDate,
      cpf: CPFValidator.strip(cpf), // 5. Higienização: Apenas os números
      phone: phone.trim(),
      registeredAt: DateTime.now(),
      acceptedTerms: acceptedTerms,
      purchaseHistory: const [], // 7. Imutabilidade: Lista vazia constante
    );

    if (newClient.age < 18) {
      throw const ClientRegistrationException(
        'O evento é restrito para maiores de 18 anos.',
      );
    }

    _clients = [..._clients, newClient];
    notifyListeners();
    await _repository.saveClients(_clients);
    return newClient;
  }

  Future<void> updateClient({
    required String clientId,
    String? fullName,
    DateTime? birthDate,
    String? cpf,
    String? phone,
    bool? acceptedTerms,
  }) async {
    final index = _clients.indexWhere((c) => c.id == clientId);
    if (index < 0) return;

    final existing = _clients[index];

    if (cpf != null && cpf != existing.cpf && !CPFValidator.isValid(cpf)) {
      throw const ClientRegistrationException('CPF inválido.');
    }

    // 7. Imutabilidade de Estado: Criando cópia via copyWith
    final updated = existing.copyWith(
      fullName: fullName?.trim(),
      birthDate: birthDate,
      cpf: cpf != null ? CPFValidator.strip(cpf) : null,
      phone: phone?.trim(),
      acceptedTerms: acceptedTerms,
    );

    _clients[index] = updated;
    notifyListeners();
    await _repository.saveClients(_clients);
  }

  Future<void> deleteClient(String clientId) async {
    _clients.removeWhere((c) => c.id == clientId);
    notifyListeners();
    await _repository.saveClients(_clients);
  }

  Future<void> updateLatestPaymentStatus(String clientId, String status) async {
    final index = _clients.indexWhere((c) => c.id == clientId);
    if (index < 0) return;

    final client = _clients[index];
    if (client.purchaseHistory.isEmpty) return;

    final last = client.purchaseHistory.last;
    final updatedPurchase = ClientPurchase(
      description: last.description,
      quantity: last.quantity,
      amount: last.amount,
      purchasedAt: last.purchasedAt,
      paymentMethod: last.paymentMethod,
      paymentStatus: status,
    );

    // 7. Imutabilidade de Estado
    final updatedHistory = List<ClientPurchase>.from(client.purchaseHistory);
    updatedHistory[updatedHistory.length - 1] = updatedPurchase;

    _clients[index] = client.copyWith(purchaseHistory: updatedHistory);
    notifyListeners();
    await _repository.saveClients(_clients);
  }

  Future<void> addPurchase(String clientId, ClientPurchase purchase) async {
    final index = _clients.indexWhere((c) => c.id == clientId);
    if (index < 0) return;

    final client = _clients[index];

    // 7. Imutabilidade de Estado: Utilizando copyWith com spread operator
    final updatedClient = client.copyWith(
      purchaseHistory: [...client.purchaseHistory, purchase],
    );

    _clients[index] = updatedClient;
    notifyListeners();
    await _repository.saveClients(_clients);
  }
}

class ClientRegistrationException implements Exception {
  const ClientRegistrationException(this.message);
  final String message;
}
