class ClothingItem {
  final String id;
  final String imagePath; // Chemin local de la photo
  final String mainCategory; // ex: "Haut", "Bas"
  final String subCategory;  // ex: "Jogging", "Jean"
  final List<String> tags;   // ex: ["Hiver", "Coton", "Bleu"]

  ClothingItem({
    required this.id,
    required this.imagePath,
    required this.mainCategory,
    required this.subCategory,
    this.tags = const [],
  });
}

// Pour gérer tes catégories dynamiques
class Category {
  final String name;
  final List<String> subCategories;

  Category({required this.name, required this.subCategories});
}