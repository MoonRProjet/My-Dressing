import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:palette_generator/palette_generator.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const WardrobeApp());

// ==========================================
// --- MODÈLES DE DONNÉES ---
// ==========================================
class Category {
  String name;
  List<String> subCategories;

  Category({required this.name, required this.subCategories});

  Map<String, dynamic> toJson() => {
        'name': name,
        'subCategories': subCategories,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        name: json['name'],
        subCategories: List<String>.from(json['subCategories']),
      );
}

class Cloth {
  final String id;
  final String imagePath;
  final String mainCategory;
  final String subCategory;
  final String brand;
  final int colorValue;

  Cloth({
    required this.id,
    required this.imagePath,
    required this.mainCategory,
    required this.subCategory,
    this.brand = "",
    this.colorValue = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'mainCategory': mainCategory,
        'subCategory': subCategory,
        'brand': brand,
        'colorValue': colorValue,
      };

  factory Cloth.fromJson(Map<String, dynamic> json) => Cloth(
        id: json['id'],
        imagePath: json['imagePath'],
        mainCategory: json['mainCategory'],
        subCategory: json['subCategory'],
        brand: json['brand'] ?? "",
        colorValue: json['colorValue'] ?? 0,
      );
}

class ClothPosition {
  final String clothId;
  double x;
  double y;
  double scale;

  ClothPosition({
    required this.clothId,
    this.x = 50.0,
    this.y = 50.0,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'clothId': clothId,
        'x': x,
        'y': y,
        'scale': scale,
      };

  factory ClothPosition.fromJson(Map<String, dynamic> json) => ClothPosition(
        clothId: json['clothId'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        scale: json['scale'].toDouble(),
      );
}

class Outfit {
  String id;
  String name;
  List<ClothPosition> clothesPositions;
  bool isFavorite;

  Outfit({
    required this.id,
    required this.name,
    required this.clothesPositions,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clothesPositions': clothesPositions.map((e) => e.toJson()).toList(),
        'isFavorite': isFavorite,
      };

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
        id: json['id'],
        name: json['name'],
        clothesPositions: (json['clothesPositions'] as List)
            .map((e) => ClothPosition.fromJson(e))
            .toList(),
        isFavorite: json['isFavorite'] ?? false,
      );
}

class ShopItem {
  final String id;
  final String name;
  final String brand;
  final String imagePath;
  final String mainCategory;
  final String subCategory;
  final double price;
  final bool isSponsor;
  final int colorValue;

  ShopItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.imagePath,
    required this.mainCategory,
    required this.subCategory,
    required this.price,
    this.isSponsor = false,
    this.colorValue = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'imagePath': imagePath,
        'mainCategory': mainCategory,
        'subCategory': subCategory,
        'price': price,
        'isSponsor': isSponsor,
        'colorValue': colorValue,
      };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'],
        name: json['name'],
        brand: json['brand'],
        imagePath: json['imagePath'],
        mainCategory: json['mainCategory'],
        subCategory: json['subCategory'],
        price: json['price'].toDouble(),
        isSponsor: json['isSponsor'] ?? false,
        colorValue: json['colorValue'] ?? 0,
      );
}

// ==========================================
// --- APPLICATION ---
// ==========================================
class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String? _openedCategory;
  String _searchQuery = "";
  String? _selectedSubFilter;
  String? _selectedFamilyFilter;

  // Filtres specifiques au Shop
  bool _showOnlyWishlist = false;
  String _selectedShopCategory = "Tout";
  bool _isAdminMode = false;
  String? _selectedShopBrandFilter;
  String? _selectedShopColorFilter;
  double _maxPriceFilter = 500.0;

  late PageController _pageController;

  final ImagePicker _picker = ImagePicker();
  final ScreenshotController _screenshotController = ScreenshotController();

  List<Cloth> myWardrobe = [];
  List<Outfit> myOutfits = [];
  List<String> myWishlistIds = [];
  List<String> myOwnedItemIds = [];
  List<ShopItem> myShopItems = [];

  List<Category> myCategories = [
    Category(name: 'Haut', subCategories: ['T-shirt', 'Pull', 'Chemise', 'Veste']),
    Category(name: 'Bas', subCategories: ['Jean', 'Pantalon', 'Short', 'Jogging', 'Cargo']),
    Category(name: 'Chaussures', subCategories: ['Baskets', 'Ville']),
  ];

  final String shopJsonUrl = "https://raw.githubusercontent.com/MoonRProjet/my-dressing-assets/main/catalogue.json";

  // CONFIGURATION GITHUB API
  final String _githubToken = "";
  final String _githubRepo = "MoonRProjet/my-dressing-assets";

  @override
  void initState() {
    super.initState();
    // On initialise le PageController à l'index de départ
    _pageController = PageController(initialPage: _selectedIndex);
    _loadData();
  }

  @override
  void dispose() {
    // Toujours détruire le contrôleur pour libérer la mémoire
    _pageController.dispose();
    super.dispose();
  }

  // ==========================================
  // --- CHARGEMENT & PERSISTANCE ---
  // ==========================================
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      String? wS = prefs.getString('wardrobe');
      if (wS != null) myWardrobe = List<Cloth>.from(jsonDecode(wS).map((m) => Cloth.fromJson(m)));

      String? cS = prefs.getString('categories');
      if (cS != null) myCategories = List<Category>.from(jsonDecode(cS).map((m) => Category.fromJson(m)));

      String? oS = prefs.getString('outfits');
      if (oS != null) myOutfits = List<Outfit>.from(jsonDecode(oS).map((m) => Outfit.fromJson(m)));

      myWishlistIds = prefs.getStringList('wishlist') ?? [];
      
      List<String> savedOwned = prefs.getStringList('ownedItems') ?? [];
      myOwnedItemIds = savedOwned.where((id) => myWardrobe.any((cloth) => cloth.id == id)).toList();
    });

    await prefs.setStringList('ownedItems', myOwnedItemIds);

    try {
      final response = await http.get(Uri.parse(shopJsonUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> decodedJson = jsonDecode(response.body);

        setState(() {
          myShopItems = List<ShopItem>.from(decodedJson.map((m) => ShopItem.fromJson(m)));
        });

        await prefs.setString('shopItems_cache', response.body);
      } else {
        _loadShopFromCache(prefs);
      }
    } catch (e) {
      debugPrint("Erreur reseau catalogue : $e");
      _loadShopFromCache(prefs);
    }
  }

  void _loadShopFromCache(SharedPreferences prefs) {
    String? cached = prefs.getString('shopItems_cache');
    List<ShopItem> items = [];

    if (cached != null) {
      items.addAll(List<ShopItem>.from(jsonDecode(cached).map((m) => ShopItem.fromJson(m))));
    }

    setState(() => myShopItems = items);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wardrobe', jsonEncode(myWardrobe.map((e) => e.toJson()).toList()));
    await prefs.setString('categories', jsonEncode(myCategories.map((e) => e.toJson()).toList()));
    await prefs.setString('outfits', jsonEncode(myOutfits.map((e) => e.toJson()).toList()));
    await prefs.setStringList('wishlist', myWishlistIds);
    await prefs.setStringList('ownedItems', myOwnedItemIds);
  }

  // ==========================================
  // --- IA & UTILITAIRES ---
  // ==========================================
  Future<Map<String, String>?> _analyzeImageLabels(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.5);
    final imageLabeler = ImageLabeler(options: options);
    try {
      final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
      for (ImageLabel label in labels) {
        String text = label.label.toLowerCase();
        if (text.contains('shirt') || text.contains('top') || text.contains('jersey') || text.contains('clothing')) return {"main": "Haut", "sub": "T-shirt"};
        if (text.contains('pants') || text.contains('jeans') || text.contains('shorts') || text.contains('trousers')) return {"main": "Bas", "sub": "Jean"};
        if (text.contains('shoe') || text.contains('sneaker') || text.contains('footwear')) return {"main": "Chaussures", "sub": "Baskets"};
      }
    } catch (e) {
      debugPrint("Erreur ML Kit : $e");
    } finally {
      imageLabeler.close();
    }
    return null;
  }

  Future<Uint8List?> _removeBackground(File imageFile) async {
    const String apiKey = "f7a127bc67msh305c85913d9ffecp16cd53jsn7942f8ca8270";
    const String apiHost = "remove-background18.p.rapidapi.com";
    const String apiUrl = "https://remove-background18.p.rapidapi.com/public/remove-background/file";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers.addAll({'x-rapidapi-key': apiKey, 'x-rapidapi-host': apiHost});
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      var response = await request.send();
      var responseString = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseString);
        String? imageUrl = jsonResponse['url'];
        if (imageUrl != null) {
          var imageResponse = await http.get(Uri.parse(imageUrl));
          if (imageResponse.statusCode == 200) return imageResponse.bodyBytes;
        }
      }
    } catch (e) {
      debugPrint("Erreur detourage: $e");
    }
    return null;
  }

  // ==========================================
  // --- INTERACTION API GITHUB (ADMIN) ---
  // ==========================================
  Future<String?> _uploadImageToGitHub(File imageFile, String mainCategory) async {
    String folder = "autres";
    String cat = mainCategory.toLowerCase();
    if (cat.contains("haut")) folder = "hauts";
    if (cat.contains("bas")) folder = "bas";
    if (cat.contains("chaussure")) folder = "chaussures";

    String fileName = "img_${DateTime.now().millisecondsSinceEpoch}.png";
    String targetUrl = "https://api.github.com/repos/$_githubRepo/contents/shop/$folder/$fileName";

    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final response = await http.put(
        Uri.parse(targetUrl),
        headers: {
          "Authorization": "token $_githubToken",
          "Accept": "application/vnd.github+json",
        },
        body: jsonEncode({
          "message": "Ajout image shop automatique depuis l'application",
          "content": base64Image,
        }),
      );

      if (response.statusCode == 201) {
        return "https://raw.githubusercontent.com/$_githubRepo/main/shop/$folder/$fileName";
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> _addItemToGitHubCatalogue(ShopItem newItem) async {
    String jsonUrl = "https://api.github.com/repos/$_githubRepo/contents/catalogue.json";

    try {
      final getResponse = await http.get(Uri.parse(jsonUrl), headers: {
        "Authorization": "token $_githubToken",
      });

      List<dynamic> currentItems = [];
      String? sha;

      if (getResponse.statusCode == 200) {
        final decodedBody = jsonDecode(getResponse.body);
        sha = decodedBody["sha"];
        String utf8Content = utf8.decode(base64Decode(decodedBody["content"].toString().replaceAll('\n', '')));
        currentItems = jsonDecode(utf8Content);
      }

      currentItems.add(newItem.toJson());

      String updatedJsonString = const JsonEncoder.withIndent('  ').convert(currentItems);
      String base64Content = base64Encode(utf8.encode(updatedJsonString));

      final putResponse = await http.put(
        Uri.parse(jsonUrl),
        headers: {
          "Authorization": "token $_githubToken",
          "Accept": "application/vnd.github+json",
        },
        body: jsonEncode({
          "message": "Mise a jour automatique catalogue.json - Ajout ${newItem.name}",
          "content": base64Content,
          if (sha != null) "sha": sha,
        }),
      );

      return putResponse.statusCode == 200 || putResponse.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateItemInGitHubCatalogue(ShopItem updatedItem) async {
    String jsonUrl = "https://api.github.com/repos/$_githubRepo/contents/catalogue.json";
    try {
      final getResponse = await http.get(Uri.parse(jsonUrl), headers: {"Authorization": "token $_githubToken"});
      if (getResponse.statusCode == 200) {
        final decodedBody = jsonDecode(getResponse.body);
        String shaJson = decodedBody["sha"];
        String utf8Content = utf8.decode(base64Decode(decodedBody["content"].toString().replaceAll('\n', '')));
        List<dynamic> currentItems = List.from(jsonDecode(utf8Content));

        int index = currentItems.indexWhere((element) => element["id"] == updatedItem.id);
        if (index != -1) {
          currentItems[index] = updatedItem.toJson();
        }

        String updatedJsonString = const JsonEncoder.withIndent('  ').convert(currentItems);
        String base64Content = base64Encode(utf8.encode(updatedJsonString));

        final putResponse = await http.put(
          Uri.parse(jsonUrl),
          headers: {
            "Authorization": "token $_githubToken",
            "Accept": "application/vnd.github+json",
          },
          body: jsonEncode({
            "message": "Modification de l'article ${updatedItem.name} via l'application",
            "content": base64Content,
            "sha": shaJson,
          }),
        );
        return putResponse.statusCode == 200 || putResponse.statusCode == 201;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteItemFromGitHub(ShopItem item) async {
    String jsonUrl = "https://api.github.com/repos/$_githubRepo/contents/catalogue.json";
    try {
      final getResponse = await http.get(Uri.parse(jsonUrl), headers: {"Authorization": "token $_githubToken"});
      if (getResponse.statusCode == 200) {
        final decodedBody = jsonDecode(getResponse.body);
        String shaJson = decodedBody["sha"];
        String utf8Content = utf8.decode(base64Decode(decodedBody["content"].toString().replaceAll('\n', '')));
        List<dynamic> currentItems = jsonDecode(utf8Content);

        currentItems.removeWhere((element) => element["id"] == item.id);

        String updatedJsonString = const JsonEncoder.withIndent('  ').convert(currentItems);
        String base64Content = base64Encode(utf8.encode(updatedJsonString));

        await http.put(
          Uri.parse(jsonUrl),
          headers: {
            "Authorization": "token $_githubToken",
            "Accept": "application/vnd.github+json",
          },
          body: jsonEncode({
            "message": "Suppression de l'article ${item.name} via l'application",
            "content": base64Content,
            "sha": shaJson,
          }),
        );
      }

      String relativePath = item.imagePath.split('/main/').last;
      String imageUrl = "https://api.github.com/repos/$_githubRepo/contents/$relativePath";

      final getImageResponse = await http.get(Uri.parse(imageUrl), headers: {"Authorization": "token $_githubToken"});
      if (getImageResponse.statusCode == 200) {
        final decodedImage = jsonDecode(getImageResponse.body);
        String shaImage = decodedImage["sha"];

        await http.delete(
          Uri.parse(imageUrl),
          headers: {
            "Authorization": "token $_githubToken",
            "Accept": "application/vnd.github+json",
          },
          body: jsonEncode({
            "message": "Suppression de l'image associee a ${item.name}",
            "sha": shaImage,
          }),
        );
      }
    } catch (e) {
      debugPrint("Erreur suppression GitHub: $e");
    }
  }

  Future<Color> _extractColor(File imageFile) async {
    try {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(FileImage(imageFile), maximumColorCount: 10);
      return paletteGenerator.dominantColor?.color ?? paletteGenerator.vibrantColor?.color ?? Colors.white;
    } catch (e) {
      return Colors.white;
    }
  }

  String _getColorFamily(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.12) return "Noir";
    if (hsl.lightness > 0.90) return "Blanc";
    if (hsl.saturation < 0.15) return "Gris";
    double hue = hsl.hue;
    if (hue >= 345 || hue < 15) return "Rouge";
    if (hue >= 15 && hue < 45) return "Orange/Marron";
    if (hue >= 45 && hue < 70) return "Jaune";
    if (hue >= 70 && hue < 160) return "Vert";
    if (hue >= 160 && hue < 255) return "Bleu";
    if (hue >= 255 && hue < 300) return "Violet";
    if (hue >= 300 && hue < 345) return "Rose";
    return "Gris";
  }

  Color _getFamilyDisplayColor(String family) {
    switch (family) {
      case "Noir": return Colors.black;
      case "Blanc": return Colors.white;
      case "Gris": return Colors.grey;
      case "Rouge": return Colors.red;
      case "Orange/Marron": return Colors.orange;
      case "Jaune": return Colors.yellow;
      case "Vert": return Colors.green;
      case "Bleu": return Colors.blue;
      case "Violet": return Colors.purple;
      case "Rose": return Colors.pink;
      default: return Colors.grey;
    }
  }

  // ==========================================
  // --- CONTROLE ET MODAL CRÉATEUR ---
  // ==========================================
  void _toggleAdminMode() {
    if (_isAdminMode) {
      setState(() => _isAdminMode = false);
      return;
    }
    TextEditingController pwd = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mode Createur"),
        content: TextField(controller: pwd, obscureText: true, decoration: const InputDecoration(hintText: "Mot de passe")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          TextButton(
            onPressed: () {
              if (pwd.text == "admin123") {
                setState(() => _isAdminMode = true);
                Navigator.pop(ctx);
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acces refuse"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Valider"),
          )
        ],
      ),
    );
  }

  void _showShopImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text("Ajouter au Catalogue Shop", style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Appareil Photo"), onTap: () { Navigator.pop(context); _pickShopImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("Galerie Photos"), onTap: () { Navigator.pop(context); _pickShopImage(ImageSource.gallery); })
          ],
        ),
      ),
    );
  }

  Future<void> _pickShopImage(ImageSource s) async {
    final f = await _picker.pickImage(source: s, imageQuality: 60);
    if (f != null && mounted) _showAddShopEntrySheet(File(f.path));
  }

  void _showAddShopEntrySheet(File img) {
    String sCat = myCategories[0].name;
    String sSub = myCategories[0].subCategories[0];
    String sBrand = "";
    String sName = "";
    double sPrice = 0.0;
    bool isSponsor = false;
    bool shouldRemoveBg = false;
    bool isProcessing = false;

    List<String> existingBrands = myShopItems.map((c) => c.brand).toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20, left: 20, right: 20
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                isProcessing
                    ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                    : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(img, height: 120)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.psychology),
                  label: const Text("Auto-detection IA"),
                  onPressed: () async {
                    setModalState(() => isProcessing = true);
                    final d = await _analyzeImageLabels(img);
                    if (d != null) {
                      setModalState(() {
                        sCat = d["main"]!;
                        sSub = d["sub"]!;
                      });
                    }
                    setModalState(() => isProcessing = false);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: "Nom de l'article", border: OutlineInputBorder()),
                  onChanged: (v) => sName = v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (v) => existingBrands.where((b) => b.toLowerCase().contains(v.text.toLowerCase())),
                        onSelected: (s) => sBrand = s,
                        fieldViewBuilder: (ctx, ctrl, node, onEdit) {
                          ctrl.addListener(() => sBrand = ctrl.text);
                          return TextField(controller: ctrl, focusNode: node, decoration: const InputDecoration(labelText: "Marque", border: OutlineInputBorder()));
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Prix (e)", border: OutlineInputBorder()),
                        onChanged: (v) => sPrice = double.tryParse(v) ?? 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Categorie", border: OutlineInputBorder()),
                        value: sCat,
                        items: myCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                        onChanged: (v) => setModalState(() {
                          sCat = v!;
                          sSub = myCategories.firstWhere((c) => c.name == v).subCategories[0];
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                        value: sSub,
                        items: myCategories.firstWhere((c) => c.name == sCat).subCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setModalState(() => sSub = v!),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Detourer"),
                  value: shouldRemoveBg,
                  onChanged: (v) => setModalState(() => shouldRemoveBg = v),
                ),
                SwitchListTile(
                  title: const Text("Sponsor"),
                  value: isSponsor,
                  activeColor: Colors.amber,
                  onChanged: (v) => setModalState(() => isSponsor = v),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50)
                  ),
                  onPressed: isProcessing ? null : () async {
                    setModalState(() => isProcessing = true);
                    
                    File finalImg = img;
                    if (shouldRemoveBg) {
                      var data = await _removeBackground(img);
                      if (data != null) {
                        finalImg = await File(img.path.replaceAll(".jpg", "_nb.jpg")).writeAsBytes(data);
                      }
                    }

                    Color color = await _extractColor(finalImg);
                    int val = color.value;

                    String? gitHubImageUrl = await _uploadImageToGitHub(finalImg, sCat);

                    if (gitHubImageUrl == null) {
                      setModalState(() => isProcessing = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Echec de l'envoi de l'image sur GitHub"), backgroundColor: Colors.red)
                      );
                      return;
                    }

                    ShopItem newItem = ShopItem(
                      id: "item_${DateTime.now().millisecondsSinceEpoch}",
                      name: sName.isEmpty ? "Article" : sName,
                      brand: sBrand,
                      imagePath: gitHubImageUrl,
                      mainCategory: sCat,
                      subCategory: sSub,
                      price: sPrice,
                      isSponsor: isSponsor,
                      colorValue: val,
                    );

                    bool success = await _addItemToGitHubCatalogue(newItem);

                    if (success) {
                      setState(() {
                        myShopItems.insert(0, newItem);
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Article publie en ligne avec succes !"), backgroundColor: Colors.green)
                      );
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Erreur lors de la mise a jour du JSON distant"), backgroundColor: Colors.red)
                      );
                    }
                    
                    setModalState(() => isProcessing = false);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text("Publier sur le Shop"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditShopEntrySheet(ShopItem item) {
    String sCat = item.mainCategory;
    String sSub = item.subCategory;
    String sBrand = item.brand;
    String sName = item.name;
    double sPrice = item.price;
    bool isSponsor = item.isSponsor;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Modifier l'article", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: sName)..selection = TextSelection.collapsed(offset: sName.length),
                  decoration: const InputDecoration(labelText: "Nom de l'article", border: OutlineInputBorder()),
                  onChanged: (v) => sName = v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: sBrand),
                        decoration: const InputDecoration(labelText: "Marque", border: OutlineInputBorder()),
                        onChanged: (v) => sBrand = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: sPrice.toString()),
                        decoration: const InputDecoration(labelText: "Prix (e)", border: OutlineInputBorder()),
                        onChanged: (v) => sPrice = double.tryParse(v) ?? 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text("Sponsor (Mettre en avant)"),
                  value: isSponsor,
                  activeColor: Colors.amber,
                  onChanged: (v) => setModalState(() => isSponsor = v),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                  onPressed: isProcessing ? null : () async {
                    setModalState(() => isProcessing = true);

                    ShopItem updatedItem = ShopItem(
                      id: item.id,
                      name: sName,
                      brand: sBrand,
                      imagePath: item.imagePath,
                      mainCategory: sCat,
                      subCategory: sSub,
                      price: sPrice,
                      isSponsor: isSponsor,
                      colorValue: item.colorValue,
                    );

                    bool success = await _updateItemInGitHubCatalogue(updatedItem);

                    if (success) {
                      setState(() {
                        int idx = myShopItems.indexWhere((x) => x.id == item.id);
                        if (idx != -1) myShopItems[idx] = updatedItem;
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Article mis a jour en ligne !"), backgroundColor: Colors.green));
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de la modification en ligne"), backgroundColor: Colors.red));
                    }

                    setModalState(() => isProcessing = false);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text("Enregistrer les modifications"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showShopFiltersSheet() {
    List<String> availableBrands = myShopItems.map((item) => item.brand).where((b) => b.isNotEmpty).toSet().toList();
    availableBrands.sort();

    List<String> availableColors = myShopItems
        .where((item) => item.colorValue != 0)
        .map((item) => _getColorFamily(Color(item.colorValue)))
        .toSet()
        .toList();
    availableColors.sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filtrer les articles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedShopBrandFilter = null;
                        _selectedShopColorFilter = null;
                        _maxPriceFilter = 500.0;
                      });
                      setModalState(() {
                        _selectedShopBrandFilter = null;
                        _selectedShopColorFilter = null;
                        _maxPriceFilter = 500.0;
                      });
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text("Reinitialiser"),
                  )
                ],
              ),
              const Divider(),
              Text("Prix maximum : ${_maxPriceFilter.toInt()} e", style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _maxPriceFilter,
                min: 0.0,
                max: 500.0,
                divisions: 50,
                label: "${_maxPriceFilter.toInt()} e",
                onChanged: (v) {
                  setModalState(() => _maxPriceFilter = v);
                  setState(() {});
                },
              ),
              const SizedBox(height: 15),
              if (availableBrands.isNotEmpty) ...[
                const Text("Marques", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableBrands.length,
                    itemBuilder: (context, idx) {
                      String brand = availableBrands[idx];
                      bool isSelected = _selectedShopBrandFilter == brand;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(brand),
                          selected: isSelected,
                          selectedColor: Colors.indigo,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                          onSelected: (selected) {
                            setModalState(() => _selectedShopBrandFilter = selected ? brand : null);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
              ],
              if (availableColors.isNotEmpty) ...[
                const Text("Couleurs", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 55,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableColors.length,
                    itemBuilder: (context, idx) {
                      String family = availableColors[idx];
                      bool isSelected = _selectedShopColorFilter == family;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedShopColorFilter = isSelected ? null : family);
                          setState(() {});
                        },
                        child: Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 35, height: 35,
                              decoration: BoxDecoration(
                                color: _getFamilyDisplayColor(family),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.indigo : Colors.grey.shade300, 
                                  width: isSelected ? 3 : 1
                                ),
                              ),
                            ),
                            Text(family, style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.pop(context),
                child: const Text("Voir les articles"),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- ACTIONS DE SYNCHRONISATION DRESSING ---
  Future<void> _addShopItemToWardrobe(ShopItem item) async {
    if (myOwnedItemIds.contains(item.id)) return;

    // OPTIMISATION : Mise à jour visuelle instantanée de l'interface graphique
    setState(() {
      myOwnedItemIds.add(item.id);
    });

    try {
      File localImage;
      if (item.imagePath.startsWith('http')) {
        final response = await http.get(Uri.parse(item.imagePath));
        if (response.statusCode != 200) throw Exception('Erreur reseau');
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/wardrobe_${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        localImage = await File(path).writeAsBytes(response.bodyBytes);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/wardrobe_${item.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        localImage = await File(item.imagePath).copy(path);
      }

      // OPTIMISATION TRÈS FORTE : On supprime l'extraction PaletteGenerator qui gelait l'écran.
      // On récupère directement la couleur pré-calculée en ligne ou on extrait en secours si elle vaut 0.
      int finalColorValue = item.colorValue;
      if (finalColorValue == 0) {
        Color extractedColor = await _extractColor(localImage);
        finalColorValue = extractedColor.value;
      }

      setState(() {
        myWardrobe.add(Cloth(
          id: item.id,
          imagePath: localImage.path,
          mainCategory: item.mainCategory,
          subCategory: item.subCategory,
          brand: item.brand,
          colorValue: finalColorValue,
        ));
      });
      
      // Sauvegarde asynchrone sans bloquer le thread principal
      _saveData();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${item.name} ajoute !"), backgroundColor: Colors.green));
    } catch (e) {
      // En cas d'échec de téléchargement, on réactive le bouton proprement
      setState(() {
        myOwnedItemIds.remove(item.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildShopImage(String path) {
    if (path.startsWith('http')) return Image.network(path, fit: BoxFit.contain);
    return Image.file(File(path), fit: BoxFit.contain);
  }

  // ==========================================
  // --- UI : COMPOSANTS ONGLET SHOP ---
  // ==========================================
  Widget _buildShopItemCard(ShopItem item, {bool isLarge = false}) {
    bool isLiked = myWishlistIds.contains(item.id);
    bool isOwned = myOwnedItemIds.contains(item.id);

    return Container(
      width: isLarge ? 250 : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.all(12),
                    child: _buildShopImage(item.imagePath),
                  ),
                ),
                if (item.colorValue != 0)
                  Positioned(
                    left: 8, bottom: 8,
                    child: Container(
                      width: 15, height: 15,
                      decoration: BoxDecoration(color: Color(item.colorValue), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                Positioned(
                  top: 5, right: 5,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 20),
                      onPressed: () {
                        setState(() {
                          if (isLiked) {
                            myWishlistIds.remove(item.id);
                          } else {
                            myWishlistIds.add(item.id);
                          }
                        });
                        _saveData();
                      },
                    ),
                  ),
                ),
                if (item.isSponsor)
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
                      child: const Text("SPONSOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (_isAdminMode) ...[
                  Positioned(
                    top: 5, left: 5,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.indigo, size: 20),
                        onPressed: () => _showEditShopEntrySheet(item),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50, left: 5,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () async {
                          final itemToDelete = item;
                          setState(() {
                            myShopItems.removeWhere((x) => x.id == itemToDelete.id);
                          });
                          _saveData();
                          await _deleteItemFromGitHub(itemToDelete);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${itemToDelete.name} supprime de GitHub"), backgroundColor: Colors.orange)
                          );
                        },
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.brand, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${item.price} e", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: isOwned ? null : () => _addShopItemToWardrobe(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOwned ? Colors.green : Colors.indigo,
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwned) const Icon(Icons.check, color: Colors.white, size: 14),
                            if (isOwned) const SizedBox(width: 4),
                            Text(isOwned ? "Possede" : "J'ai", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildShopTab() {
    var filteredItems = myShopItems.where((item) {
      bool catMatch = _selectedShopCategory == "Tout" || item.mainCategory == _selectedShopCategory;
      bool wishMatch = !_showOnlyWishlist || myWishlistIds.contains(item.id);
      bool brandMatch = _selectedShopBrandFilter == null || item.brand == _selectedShopBrandFilter;
      bool priceMatch = item.price <= _maxPriceFilter;
      bool colorMatch = _selectedShopColorFilter == null || 
                        (item.colorValue != 0 && _getColorFamily(Color(item.colorValue)) == _selectedShopColorFilter);
      return catMatch && wishMatch && brandMatch && priceMatch && colorMatch;
    }).toList();

    final sponsors = filteredItems.where((item) => item.isSponsor).toList();
    final standards = filteredItems.where((item) => !item.isSponsor).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: GestureDetector(
            onLongPress: _toggleAdminMode,
            child: Text(
              _isAdminMode ? "Admin Mode" : (_showOnlyWishlist ? "Ma Wishlist" : "Shop"),
              style: TextStyle(color: _isAdminMode ? Colors.amber : Colors.black),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showShopFiltersSheet,
            ),
            IconButton(
              icon: Icon(_showOnlyWishlist ? Icons.favorite : Icons.favorite_border, color: Colors.red),
              onPressed: () => setState(() => _showOnlyWishlist = !_showOnlyWishlist),
            )
          ],
          floating: true,
          centerTitle: true,
        ),
        if (!_showOnlyWishlist)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: ["Tout", "Haut", "Bas", "Chaussures"].map((cat) {
                  bool isSel = _selectedShopCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: Colors.indigo,
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                      onSelected: (s) => setState(() => _selectedShopCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        if (sponsors.isNotEmpty && !_showOnlyWishlist)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 15, top: 10, bottom: 10),
                  child: Text("Tendances du moment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: sponsors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _buildShopItemCard(sponsors[index], isLarge: true),
                    ),
                  ),
                ),
                const Divider(height: 30),
              ],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          sliver: SliverToBoxAdapter(
            child: Text(
              filteredItems.isEmpty ? "Aucun article" : (_showOnlyWishlist ? "Vos articles preferes" : "Nouveautes"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(15),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildShopItemCard(standards[index]),
              childCount: standards.length,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // --- UI : ONGLET DRESSING ---
  // ==========================================
  Widget _buildDressingContent() {
    if (_openedCategory == null) {
      var activeCategories = myCategories.where((cat) => myWardrobe.any((cloth) => cloth.mainCategory == cat.name)).toList();
      return GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, 
          crossAxisSpacing: 15, 
          mainAxisSpacing: 15
        ),
        itemCount: activeCategories.length,
        itemBuilder: (context, index) {
          final cat = activeCategories[index];
          final count = myWardrobe.where((c) => c.mainCategory == cat.name).length;
          return InkWell(
            onTap: () => setState(() {
              _openedCategory = cat.name;
              _searchQuery = "";
              _selectedSubFilter = null;
              _selectedFamilyFilter = null;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(20)
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 60),
                  Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("$count habits")
                ],
              ),
            ),
          );
        },
      );
    } else {
      var itemsInCategory = myWardrobe.where((c) => c.mainCategory == _openedCategory).toList();
      var presentFamilies = itemsInCategory.map((c) => _getColorFamily(Color(c.colorValue))).toSet().toList();
      presentFamilies.sort();
      
      var itemsToDisplay = itemsInCategory;
      if (_selectedSubFilter != null) itemsToDisplay = itemsToDisplay.where((c) => c.subCategory == _selectedSubFilter).toList();
      if (_searchQuery.isNotEmpty) itemsToDisplay = itemsToDisplay.where((c) => c.subCategory.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      if (_selectedFamilyFilter != null) itemsToDisplay = itemsToDisplay.where((c) => _getColorFamily(Color(c.colorValue)) == _selectedFamilyFilter).toList();
      
      var subCats = itemsInCategory.map((c) => c.subCategory).toSet().toList();
      
      // OPTIMISATION GESTES : On enveloppe tout le dossier dans un PopScope
      return PopScope(
        canPop: false, // Bloque le retour système par défaut pour éviter de fermer l'appli
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // Si un dossier est ouvert, le geste retour ferme le dossier au lieu de quitter l'app
          setState(() {
            _openedCategory = null;
          });
        },
        child: Column(
          children: [
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back), 
                onPressed: () => setState(() => _openedCategory = null)
              ),
              title: Text(_openedCategory!),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  FilterChip(label: const Text("Tout"), selected: _selectedSubFilter == null, onSelected: (v) => setState(() => _selectedSubFilter = null)),
                  ...subCats.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: FilterChip(label: Text(s), selected: _selectedSubFilter == s, onSelected: (v) => setState(() => _selectedSubFilter = v ? s : null)),
                  ))
                ],
              ),
            ),
            if (presentFamilies.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedFamilyFilter = null),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _selectedFamilyFilter == null ? Colors.indigo : Colors.grey)),
                        child: const Icon(Icons.filter_alt_off, size: 20),
                      ),
                    ),
                    ...presentFamilies.map((family) => GestureDetector(
                      onTap: () => setState(() => _selectedFamilyFilter = family),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 35, height: 35,
                            decoration: BoxDecoration(
                              color: _getFamilyDisplayColor(family),
                              shape: BoxShape.circle,
                              border: Border.all(color: _selectedFamilyFilter == family ? Colors.indigo : Colors.grey.shade300, width: _selectedFamilyFilter == family ? 3 : 1),
                            ),
                          ),
                          Text(family, style: TextStyle(fontSize: 9, fontWeight: _selectedFamilyFilter == family ? FontWeight.bold : FontWeight.normal))
                        ],
                      ),
                    ))
                  ],
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  crossAxisSpacing: 10, 
                  mainAxisSpacing: 10, 
                  childAspectRatio: 0.75
                ),
                itemCount: itemsToDisplay.length,
                itemBuilder: (context, index) {
                  final item = itemsToDisplay[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.grey.shade50,
                                padding: const EdgeInsets.all(12),
                                child: Image.file(File(item.imagePath), fit: BoxFit.contain),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text(item.subCategory, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (item.brand.isNotEmpty) Text(item.brand, style: const TextStyle(fontSize: 10, color: Colors.grey))
                                ],
                              ),
                            )
                          ],
                        ),
                        if (item.colorValue != 0)
                          Positioned(
                            left: 8, bottom: 8,
                            child: Container(
                              width: 15, height: 15,
                              decoration: BoxDecoration(color: Color(item.colorValue), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            ),
                          ),
                        Positioned(
                          right: 0, top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                myWardrobe.removeWhere((c) => c.id == item.id);
                                myOwnedItemIds.remove(item.id);
                                if (!myWardrobe.any((c) => c.mainCategory == _openedCategory)) _openedCategory = null;
                              });
                              _saveData();
                            },
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      );
    }
  }

  // ==========================================
  // --- UI : CONFIGURATION DES AUTRES ONGLETS ---
  // ==========================================
  Widget _buildCanvas(List<ClothPosition> positions, {bool interactive = true, Function? onUpdate, String? selectedClothId, Function(String)? onSelect}) {
    return Stack(
      children: positions.map((pos) {
        final cloth = myWardrobe.firstWhere((c) => c.id == pos.clothId, orElse: () => Cloth(id: '', imagePath: '', mainCategory: '', subCategory: ''));
        if (cloth.id.isEmpty) return const SizedBox();
        bool isSelected = pos.clothId == selectedClothId;
        return Positioned(
          left: pos.x, top: pos.y,
          child: GestureDetector(
            onTap: interactive ? () {
              positions.remove(pos);
              positions.add(pos);
              if (onSelect != null) onSelect(pos.clothId);
              if (onUpdate != null) onUpdate();
            } : null,
            onPanUpdate: interactive ? (details) {
              pos.x += details.delta.dx;
              pos.y += details.delta.dy;
              if (onSelect != null && !isSelected) onSelect(pos.clothId);
              if (onUpdate != null) onUpdate();
            } : null,
            onLongPress: interactive ? () {
              positions.remove(pos);
              if (onSelect != null && isSelected) onSelect('');
              if (onUpdate != null) onUpdate();
            } : null,
            child: Transform.scale(
              scale: pos.scale,
              child: Container(
                width: 150, height: 150,
                decoration: interactive && isSelected ? BoxDecoration(border: Border.all(color: Colors.indigo, width: 2)) : null,
                child: Image.file(File(cloth.imagePath), fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _viewOutfit(Outfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(outfit.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_for_offline, color: Colors.blue, size: 30),
                      onPressed: () async {
                        final image = await _screenshotController.capture();
                        if (image != null) {
                          final directory = Directory.systemTemp;
                          final path = '${directory.path}/outfit_${DateTime.now().millisecondsSinceEpoch}.png';
                          final file = await File(path).writeAsBytes(image);
                          await Gal.putImage(file.path);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enregistre !")));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, size: 30),
                      onPressed: () {
                        Navigator.pop(context);
                        _openOutfitEditor(existingOutfit: outfit);
                      },
                    )
                  ],
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      color: Colors.white,
                      child: _buildCanvas(outfit.clothesPositions, interactive: false),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))
          ],
        ),
      ),
    );
  }

  void _openOutfitEditor({Outfit? existingOutfit}) {
    TextEditingController nameController = TextEditingController(text: existingOutfit?.name ?? "");
    List<ClothPosition> currentPositions = existingOutfit != null ? List.from(existingOutfit.clothesPositions.map((p) => ClothPosition(clothId: p.clothId, x: p.x, y: p.y, scale: p.scale))) : [];
    String activeClothId = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          ClothPosition? activePos;
          try {
            activePos = currentPositions.firstWhere((p) => p.clothId == activeClothId);
          } catch (e) {
            activePos = null;
          }
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => Navigator.pop(context)),
                    Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom du look"))),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                      onPressed: () {
                        final random = Random();
                        List<ClothPosition> generated = [];
                        void pick(String cat, double x, double y, double s) {
                          var items = myWardrobe.where((c) => c.mainCategory == cat).toList();
                          if (items.isNotEmpty) generated.add(ClothPosition(clothId: items[random.nextInt(items.length)].id, x: x, y: y, scale: s));
                        }
                        pick('Haut', 100.0, 20.0, 1.2);
                        pick('Bas', 100.0, 180.0, 1.2);
                        pick('Chaussures', 100.0, 350.0, 0.9);
                        if (generated.isNotEmpty) {
                          setModalState(() {
                            currentPositions.clear();
                            currentPositions.addAll(generated);
                            activeClothId = "";
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_for_offline, color: Colors.blue, size: 30),
                      onPressed: () async {
                        if (currentPositions.isEmpty) return;
                        setModalState(() => activeClothId = "");
                        final image = await _screenshotController.capture();
                        if (image != null) {
                          final directory = Directory.systemTemp;
                          final path = '${directory.path}/outfit_${DateTime.now().millisecondsSinceEpoch}.png';
                          final file = await File(path).writeAsBytes(image);
                          await Gal.putImage(file.path);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enregistre !")));
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green, size: 30),
                      onPressed: () {
                        if (nameController.text.isNotEmpty && currentPositions.isNotEmpty) {
                          setState(() {
                            if (existingOutfit != null) {
                              existingOutfit.name = nameController.text;
                              existingOutfit.clothesPositions = currentPositions;
                            } else {
                              myOutfits.add(Outfit(id: DateTime.now().toString(), name: nameController.text, clothesPositions: currentPositions));
                            }
                          });
                          _saveData();
                          Navigator.pop(context);
                        }
                      },
                    )
                  ],
                ),
                const Text("Ajustez vos habits"),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setModalState(() => activeClothId = ""),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            color: Colors.white,
                            child: _buildCanvas(currentPositions, onUpdate: () => setModalState(() {}), selectedClothId: activeClothId, onSelect: (id) => setModalState(() => activeClothId = id)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (activePos != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_out),
                        Expanded(child: Slider(value: activePos.scale, min: 0.3, max: 3.0, onChanged: (v) => setModalState(() => activePos!.scale = v))),
                        const Icon(Icons.zoom_in)
                      ],
                    ),
                  ),
                if (activePos == null) const SizedBox(height: 48),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: myWardrobe.length,
                    itemBuilder: (context, index) {
                      final item = myWardrobe[index];
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          currentPositions.add(ClothPosition(clothId: item.id));
                          activeClothId = item.id;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(item.imagePath), width: 60, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutfitsTab() {
    if (myOutfits.isEmpty) return const Center(child: Text("Aucun montage."));
    List<Outfit> sorted = List.from(myOutfits)..sort((a, b) => b.isFavorite ? 1 : -1);
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final outfit = sorted[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: outfit.isFavorite ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)] : [],
          ),
          child: Card(
            elevation: outfit.isFavorite ? 5 : 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: outfit.isFavorite ? Colors.amber : Colors.transparent, width: 2)),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _viewOutfit(outfit),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (outfit.isFavorite) const Icon(Icons.stars, color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text(outfit.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(outfit.isFavorite ? Icons.favorite : Icons.favorite_border, color: outfit.isFavorite ? Colors.red : Colors.grey),
                              onPressed: () {
                                setState(() => outfit.isFavorite = !outfit.isFavorite);
                                _saveData();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() => myOutfits.removeWhere((o) => o.id == outfit.id));
                                _saveData();
                              },
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: outfit.clothesPositions.length,
                        itemBuilder: (context, cIdx) {
                          final clothId = outfit.clothesPositions[cIdx].clothId;
                          final cloth = myWardrobe.firstWhere((c) => c.id == clothId, orElse: () => Cloth(id: '', imagePath: '', mainCategory: '', subCategory: ''));
                          if (cloth.imagePath.isEmpty) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(cloth.imagePath), width: 80, height: 100, fit: BoxFit.cover),
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    if (myWardrobe.isEmpty) return const Center(child: Text("Ajoutez des habits !"));
    Map<String, int> counts = {};
    for (var cloth in myWardrobe) {
      counts[cloth.mainCategory] = (counts[cloth.mainCategory] ?? 0) + 1;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.inventory_2), Text("${myWardrobe.length}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const Text("Habits")])))),
              Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Icon(Icons.auto_awesome), Text("${myOutfits.length}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const Text("Tenues")])))),
            ],
          ),
          const SizedBox(height: 30),
          ...counts.entries.map((entry) {
            double percent = entry.value / myWardrobe.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(entry.key), Text("${(percent * 100).toInt()}%")]),
                  LinearProgressIndicator(value: percent, borderRadius: BorderRadius.circular(10), minHeight: 8)
                ],
              ),
            );
          })
        ],
      ),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Appareil Photo"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("Galerie Photos"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource s) async {
    final f = await _picker.pickImage(source: s, imageQuality: 50);
    if (f != null) {
      if (!mounted) return;
      _showAddEntrySheet(File(f.path));
    }
  }

  void _showAddEntrySheet(File img) {
    String sCat = myCategories[0].name;
    String sSub = myCategories[0].subCategories[0];
    String sBrand = "";
    bool shouldRemoveBg = false;
    bool isProcessing = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isProcessing ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())) : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(img, height: 150)),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.psychology),
                label: const Text("Auto-detection IA"),
                onPressed: isProcessing ? null : () async {
                  setModalState(() => isProcessing = true);
                  final detection = await _analyzeImageLabels(img);
                  if (detection != null) {
                    setModalState(() {
                      sCat = detection["main"]!;
                      sSub = detection["sub"]!;
                    });
                  }
                  setModalState(() => isProcessing = false);
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(title: const Text("Detourer"), value: shouldRemoveBg, onChanged: (v) => setModalState(() => shouldRemoveBg = v)),
              TextField(decoration: const InputDecoration(labelText: "Marque"), onChanged: (v) => sBrand = v),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true, value: sCat,
                      items: myCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                      onChanged: (v) => setModalState(() {
                        sCat = v!;
                        sSub = myCategories.firstWhere((c) => c.name == v).subCategories[0];
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true, value: sSub,
                      items: myCategories.firstWhere((c) => c.name == sCat).subCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setModalState(() => sSub = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setModalState(() => isProcessing = true);
                  File finalImage = img;
                  if (shouldRemoveBg) {
                    Uint8List? data = await _removeBackground(img);
                    if (data != null) {
                      final String path = img.path.replaceAll(RegExp(r'\.(jpg|jpeg|png)$'), '_nobg.webp');
                      finalImage = await File(path).writeAsBytes(data);
                    }
                  }
                  Color color = await _extractColor(finalImage);
                  int val = color.value;
                  
                  setState(() {
                    myWardrobe.add(Cloth(
                      id: DateTime.now().toString(),
                      imagePath: finalImage.path,
                      mainCategory: sCat,
                      subCategory: sSub,
                      brand: sBrand.trim(),
                      colorValue: val,
                    ));
                  });
                  await _saveData();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text("Ajouter au dressing"),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // On cache l'AppBar uniquement si on est sur le Shop ou dans un dossier ouvert
      appBar: (_selectedIndex != 3 && _openedCategory == null) 
          ? AppBar(title: const Text('My Dressing'), centerTitle: true) 
          : null,
      
      // --- LE COEUR DE L'ANIMATION : PAGEVIEW ---
      body: PageView(
        controller: _pageController,
        // Cette fonction met à jour l'icône de la barre quand tu swipes
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
            // On ferme les dossiers si on change d'onglet en swipant
            if (_openedCategory != null) _openedCategory = null;
          });
        },
        // Liste des pages
        children: [
          _buildDressingContent(),
          _buildOutfitsTab(),
          _buildStatsTab(),
          _buildShopTab(),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          // Quand on clique, on demande au PageView de défiler vers la page i
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 400), // Vitesse de transition
            curve: Curves.easeInOutQuart, // Style d'accélération "Premium"
          );
          // Le setState sera fait automatiquement par onPageChanged du PageView
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom), label: 'Dressing'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Tenues'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Shop'),
        ],
      ),

      floatingActionButton: (_selectedIndex == 2 || (_selectedIndex == 3 && !_isAdminMode))
          ? null
          : FloatingActionButton(
              onPressed: _selectedIndex == 0
                  ? _showImageSourceOptions
                  : _selectedIndex == 1
                      ? () => _openOutfitEditor()
                      : _showShopImageSourceOptions,
              child: const Icon(Icons.add),
            ),
    );
  }
}