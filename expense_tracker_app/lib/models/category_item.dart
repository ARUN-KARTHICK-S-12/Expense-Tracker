import '../utils/json_helpers.dart';

class CategoryItem {
  const CategoryItem({required this.name, this.isCustom = false});

  final String name;
  final bool isCustom;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      name: jsonString(json['name']),
      isCustom: jsonBool(json['isCustom']),
    );
  }
}
