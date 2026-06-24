import '../utils/json_helpers.dart';

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
  });

  final String id;
  final String description;
  final String category;
  final double amount;
  final DateTime date;

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: jsonString(json['id']),
      description: jsonString(json['description']),
      category: jsonString(json['category'], 'Other'),
      amount: jsonDouble(json['amount']),
      date: jsonDate(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'category': category,
        'amount': amount,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };

  TransactionRecord copyWith({
    String? id,
    String? description,
    String? category,
    double? amount,
    DateTime? date,
  }) {
    return TransactionRecord(
      id: id ?? this.id,
      description: description ?? this.description,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
  }
}
