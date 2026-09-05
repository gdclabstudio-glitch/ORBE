class Client {
  Client({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.cpf,
    required this.phone,
    required this.registeredAt,
    required this.acceptedTerms,
    List<ClientPurchase>? purchaseHistory,
  }) : purchaseHistory = purchaseHistory ?? [];

  final String id;
  final String fullName;
  final DateTime birthDate;
  final String cpf;
  final String phone;
  final DateTime registeredAt;
  final bool acceptedTerms;
  final List<ClientPurchase> purchaseHistory;

  Client copyWith({
    String? id,
    String? fullName,
    DateTime? birthDate,
    String? cpf,
    String? phone,
    DateTime? registeredAt,
    bool? acceptedTerms,
    List<ClientPurchase>? purchaseHistory,
  }) {
    return Client(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      cpf: cpf ?? this.cpf,
      phone: phone ?? this.phone,
      registeredAt: registeredAt ?? this.registeredAt,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      purchaseHistory: purchaseHistory ?? this.purchaseHistory,
    );
  }

  int get age {
    final today = DateTime.now();
    var years = today.year - birthDate.year;
    final birthdayHasPassed = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!birthdayHasPassed) years--;
    return years;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
        'cpf': cpf,
        'phone': phone,
        'registeredAt': registeredAt.toIso8601String(),
        'acceptedTerms': acceptedTerms,
        'purchaseHistory':
            purchaseHistory.map((item) => item.toJson()).toList(),
      };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        birthDate: DateTime.parse(json['birthDate'] as String),
        cpf: json['cpf'] as String,
        phone: json['phone'] as String,
        registeredAt: DateTime.parse(json['registeredAt'] as String),
        acceptedTerms: json['acceptedTerms'] as bool? ?? true,
        purchaseHistory: (json['purchaseHistory'] as List<dynamic>? ?? [])
            .map(
              (item) => ClientPurchase.fromJson(
                  Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );
}

class ClientPurchase {
  const ClientPurchase({
    required this.description,
    required this.quantity,
    required this.amount,
    required this.purchasedAt,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  final String description;
  final int quantity;
  final double amount;
  final DateTime purchasedAt;
  final String paymentMethod; // e.g., 'MercadoPago', 'Whatsapp', 'Cartão'
  final String paymentStatus; // e.g., 'Pendente', 'Confirmado', 'Cancelado'

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'amount': amount,
        'purchasedAt': purchasedAt.toIso8601String(),
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
      };

  factory ClientPurchase.fromJson(Map<String, dynamic> json) => ClientPurchase(
        description: json['description'] as String,
        quantity: json['quantity'] as int,
        amount: (json['amount'] as num).toDouble(),
        purchasedAt: DateTime.parse(json['purchasedAt'] as String),
        paymentMethod: json['paymentMethod'] as String? ?? 'Desconhecido',
        paymentStatus: json['paymentStatus'] as String? ?? 'Pendente',
      );
}
