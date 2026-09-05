import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/event_config.dart';
import '../models/ticket.dart';

class ShopProvider with ChangeNotifier {
  static const _lotsKey = 'labomba_ticket_lots';
  static const _salesHistoryKey = 'labomba_sales_history';

  final List<TicketLot> _lots = [
    TicketLot(
      id: 'VIP',
      name: 'Pré-venda VIP',
      total: 50,
      sold: 12,
      price: 129,
    ),
    TicketLot(id: 'FIRST', name: '1º Lote', total: 100, sold: 34, price: 159),
    TicketLot(id: 'SECOND', name: '2º Lote', total: 150, sold: 0, price: 189),
  ];
  final List<int> _salesHistory = [4, 7, 5, 11, 8, 14, 10];

  ShopProvider() {
    _loadLots();
  }

  final Ticket _ticket = Ticket(
    id: 'PRE',
    description: 'Pré-venda VIP\nLaBomba 2027',
    subtitle:
        'Garanta seu lugar no maior bloco de carnaval do ano com o melhor preço e benefícios exclusivos.',
    price: 129.0,
  );

  Ticket get ticket => _ticket;
  List<TicketLot> get lots => List.unmodifiable(_lots);
  int get totalSold => _lots.fold(0, (sum, lot) => sum + lot.sold);
  int get totalCapacity => _lots.fold(0, (sum, lot) => sum + lot.total);
  double get estimatedRevenue =>
      _lots.fold(0, (sum, lot) => sum + lot.sold * lot.price);
  List<int> get salesHistory => List.unmodifiable(_salesHistory);

  Future<void> _loadLots() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_lotsKey);
    final savedHistory = preferences.getString(_salesHistoryKey);
    if (savedHistory != null) {
      try {
        _salesHistory
          ..clear()
          ..addAll((jsonDecode(savedHistory) as List<dynamic>).cast<int>());
      } catch (_) {}
    }
    if (saved == null) return;
    try {
      final decoded = jsonDecode(saved) as List<dynamic>;
      _lots
        ..clear()
        ..addAll(
          decoded.map(
            (item) =>
                TicketLot.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Keep the built-in defaults when local data is invalid.
    }
  }

  Future<void> _saveLots() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _lotsKey,
      jsonEncode(_lots.map((lot) => lot.toJson()).toList()),
    );
  }

  Future<bool> registerSale(String lotId, {int quantity = 1}) async {
    final index = _lots.indexWhere((lot) => lot.id == lotId);
    if (index < 0 || quantity < 1) return false;
    final lot = _lots[index];
    if (!lot.active || lot.remaining < quantity) return false;
    lot.sold += quantity;
    _salesHistory.add(quantity);
    if (_salesHistory.length > 14) {
      _salesHistory.removeAt(0);
    }
    notifyListeners();
    await _saveLots();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_salesHistoryKey, jsonEncode(_salesHistory));
    return true;
  }

  Future<void> updateLot({
    required String lotId,
    required int total,
    required double price,
    required bool active,
  }) async {
    final lot = _lots.firstWhere((item) => item.id == lotId);
    if (total < lot.sold || total < 0 || price < 0) return;
    lot
      ..total = total
      ..price = price
      ..active = active;
    notifyListeners();
    await _saveLots();
  }

  /// Adds a new lot. The id will be generated from the name and ensured unique.
  Future<void> addLot({
    required String name,
    required int total,
    required double price,
    bool active = true,
  }) async {
    var baseId = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    if (baseId.isEmpty) baseId = 'LOT';
    var id = baseId;
    var counter = 1;
    while (_lots.any((l) => l.id == id)) {
      id = '${baseId}_${counter++}';
    }
    _lots.add(
      TicketLot(
        id: id,
        name: name,
        total: total,
        sold: 0,
        price: price,
        active: active,
      ),
    );
    notifyListeners();
    await _saveLots();
  }

  /// Reverts sales on a lot by decreasing the sold counter. Does not touch sales history.
  Future<void> revertSale(String lotId, {int quantity = 1}) async {
    final index = _lots.indexWhere((lot) => lot.id == lotId);
    if (index < 0 || quantity < 1) return;
    final lot = _lots[index];
    lot.sold = (lot.sold - quantity).clamp(0, lot.total);
    notifyListeners();
    await _saveLots();
  }

  Future<bool> launchWhatsApp({String? message}) async {
    final encodedMessage = Uri.encodeComponent(
      message ?? EventConfig.whatsappPurchaseMessage,
    );

    final url = Uri.parse(
      'https://wa.me/${EventConfig.whatsappPhone}?text=$encodedMessage',
    );

    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
