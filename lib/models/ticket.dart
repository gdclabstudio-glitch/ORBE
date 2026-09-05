class Ticket {
  final String id;
  final String description;
  final String subtitle;
  final double price;
  final String badge;

  Ticket({
    required this.id,
    required this.description,
    required this.subtitle,
    required this.price,
    this.badge = 'PRÉ-VENDA VIP',
  });
}

class TicketLot {
  TicketLot({
    required this.id,
    required this.name,
    required this.total,
    required this.sold,
    required this.price,
    this.active = true,
  });

  final String id;
  final String name;
  int total;
  int sold;
  double price;
  bool active;

  int get remaining => total - sold;
  double get occupancy => total == 0 ? 0 : sold / total;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'total': total,
        'sold': sold,
        'price': price,
        'active': active,
      };

  factory TicketLot.fromJson(Map<String, dynamic> json) => TicketLot(
        id: json['id'] as String,
        name: json['name'] as String,
        total: json['total'] as int,
        sold: json['sold'] as int,
        price: (json['price'] as num).toDouble(),
        active: json['active'] as bool? ?? true,
      );
}
