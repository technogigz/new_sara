class GameItem {
  final String id;
  final String name;
  final String point;
  final String amount;

  GameItem({
    required this.id,
    required this.name,
    required this.point,
    required this.amount,
  });

  factory GameItem.fromJson(Map<String, dynamic> json) {
    return GameItem(
      id: json['id'] ?? '',
      name: json['game_name'] ?? '',
      point: json['point'] ?? '',
      amount: json['amount'] ?? '',
    );
  }
}
