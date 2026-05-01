import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const WardrobeApp());

// --- MODÈLES ---
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

  Cloth({
    required this.id,
    required this.imagePath,
    required this.mainCategory,
    required this.subCategory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'mainCategory': mainCategory,
        'subCategory': subCategory,
      };

  factory Cloth.fromJson(Map<String, dynamic> json) => Cloth(
        id: json['id'],
        imagePath: json['imagePath'],
        mainCategory: json['mainCategory'],
        subCategory: json['subCategory'],
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

// --- APPLICATION ---
class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
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
  final ImagePicker _picker = ImagePicker();

  List<Cloth> myWardrobe = [];
  List<Outfit> myOutfits = [];
  List<Category> myCategories = [
    Category(name: 'Haut', subCategories: ['T-shirt', 'Pull', 'Chemise']),
    Category(name: 'Bas', subCategories: ['Jean', 'Pantalon', 'Short', 'Jogging']),
    Category(name: 'Chaussures', subCategories: ['Baskets', 'Ville']),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'wardrobe', jsonEncode(myWardrobe.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'categories', jsonEncode(myCategories.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'outfits', jsonEncode(myOutfits.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? wS = prefs.getString('wardrobe');
      if (wS != null) {
        myWardrobe = List<Cloth>.from(
            jsonDecode(wS).map((m) => Cloth.fromJson(m)));
      }

      String? cS = prefs.getString('categories');
      if (cS != null) {
        myCategories = List<Category>.from(
            jsonDecode(cS).map((m) => Category.fromJson(m)));
      }

      String? oS = prefs.getString('outfits');
      if (oS != null) {
        myOutfits = List<Outfit>.from(
            jsonDecode(oS).map((m) => Outfit.fromJson(m)));
      }
    });
  }

  // ==========================================
  // --- LOGIQUE API DÉTOURAGE ---
  // ==========================================
  Future<Uint8List?> _removeBackground(File imageFile) async {
    const String apiKey = "f7a127bc67msh305c85913d9ffecp16cd53jsn7942f8ca8270";
    const String apiHost = "remove-background18.p.rapidapi.com";
    const String apiUrl =
        "https://remove-background18.p.rapidapi.com/public/remove-background/file";

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      request.headers.addAll({
        'x-rapidapi-key': apiKey,
        'x-rapidapi-host': apiHost,
      });

      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();
      var responseString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseString);
        String? imageUrl = jsonResponse['url'];

        if (imageUrl != null) {
          var imageResponse = await http.get(Uri.parse(imageUrl));

          if (imageResponse.statusCode == 200) {
            return imageResponse.bodyBytes;
          } else {
            debugPrint(
                "Erreur téléchargement image. Code: ${imageResponse.statusCode}");
          }
        }
      } else {
        debugPrint("Erreur détourage API. Code : ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception réseau lors du détourage : $e");
    }
    return null;
  }
  // ==========================================

  // --- CANEVAS ---
  Widget _buildCanvas(
    List<ClothPosition> positions, {
    bool interactive = true,
    Function? onUpdate,
    String? selectedClothId,
    Function(String)? onSelect,
  }) {
    return Stack(
      children: positions.map((pos) {
        final cloth = myWardrobe.firstWhere(
          (c) => c.id == pos.clothId,
          orElse: () => Cloth(
              id: '', imagePath: '', mainCategory: '', subCategory: ''),
        );
        if (cloth.id.isEmpty) {
          return const SizedBox();
        }

        bool isSelected = pos.clothId == selectedClothId;

        return Positioned(
          left: pos.x,
          top: pos.y,
          child: GestureDetector(
            onTap: interactive
                ? () {
                    positions.remove(pos);
                    positions.add(pos);
                    if (onSelect != null) {
                      onSelect(pos.clothId);
                    }
                    if (onUpdate != null) {
                      onUpdate();
                    }
                  }
                : null,
            onPanUpdate: interactive
                ? (details) {
                    pos.x += details.delta.dx;
                    pos.y += details.delta.dy;
                    if (onSelect != null && !isSelected) {
                      onSelect(pos.clothId);
                    }
                    if (onUpdate != null) {
                      onUpdate();
                    }
                  }
                : null,
            onLongPress: interactive
                ? () {
                    positions.remove(pos);
                    if (onSelect != null && isSelected) {
                      onSelect('');
                    }
                    if (onUpdate != null) {
                      onUpdate();
                    }
                  }
                : null,
            child: Transform.scale(
              scale: pos.scale,
              child: Container(
                width: 150,
                height: 150,
                decoration: interactive && isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.indigo, width: 2))
                    : null,
                child: Image.file(File(cloth.imagePath), fit: BoxFit.contain),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- VUE LOOKBOOK (VISUALISATION SEULE) ---
  void _viewOutfit(Outfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(outfit.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 30),
                  onPressed: () {
                    Navigator.pop(context);
                    _openOutfitEditor(existingOutfit: outfit);
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20)),
                child: _buildCanvas(outfit.clothesPositions, interactive: false),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        ),
      ),
    );
  }

  // --- ÉDITEUR (AVEC SLIDER) ---
  void _openOutfitEditor({Outfit? existingOutfit}) {
    TextEditingController nameController =
        TextEditingController(text: existingOutfit?.name ?? "");
    List<ClothPosition> currentPositions = existingOutfit != null
        ? List.from(existingOutfit.clothesPositions.map((p) => ClothPosition(
            clothId: p.clothId, x: p.x, y: p.y, scale: p.scale)))
        : [];

    String activeClothId = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        ClothPosition? activePos;
        try {
          activePos = currentPositions
              .firstWhere((p) => p.clothId == activeClothId);
        } catch (e) {
          activePos = null;
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(children: [
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.pop(context)),
                Expanded(
                    child: TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: "Nom du look"))),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green, size: 30),
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        currentPositions.isNotEmpty) {
                      setState(() {
                        if (existingOutfit != null) {
                          existingOutfit.name = nameController.text;
                          existingOutfit.clothesPositions = currentPositions;
                        } else {
                          myOutfits.add(Outfit(
                              id: DateTime.now().toString(),
                              name: nameController.text,
                              clothesPositions: currentPositions));
                        }
                      });
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                )
              ]),
              const Text(
                  "Toucher un habit pour le régler | Appui long pour supprimer",
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              Expanded(
                child: GestureDetector(
                  onTap: () => setModalState(() => activeClothId = ""),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildCanvas(
                        currentPositions,
                        onUpdate: () => setModalState(() {}),
                        selectedClothId: activeClothId,
                        onSelect: (id) =>
                            setModalState(() => activeClothId = id),
                      ),
                    ),
                  ),
                ),
              ),
              if (activePos != null) // Pas besoin d'accolades pour cette syntaxe UI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, size: 20),
                      Expanded(
                        child: Slider(
                          value: activePos.scale,
                          min: 0.3,
                          max: 3.0,
                          onChanged: (value) =>
                              setModalState(() => activePos!.scale = value),
                        ),
                      ),
                      const Icon(Icons.zoom_in, size: 20),
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
                        currentPositions
                            .add(ClothPosition(clothId: item.id));
                        activeClothId = item.id;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(item.imagePath),
                              width: 60, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // --- ONGLET TENUES ---
  Widget _buildOutfitsTab() {
    if (myOutfits.isEmpty) {
      return const Center(child: Text("Aucun montage."));
    }
    List<Outfit> sorted = List.from(myOutfits)
      ..sort((a, b) => b.isFavorite ? 1 : -1);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final outfit = sorted[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: outfit.isFavorite
                ? [
                    BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2)
                  ]
                : [],
          ),
          child: Card(
            elevation: outfit.isFavorite ? 5 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                  color:
                      outfit.isFavorite ? Colors.amber : Colors.transparent,
                  width: 2),
            ),
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
                        Row(children: [
                          if (outfit.isFavorite)
                            const Icon(Icons.stars,
                                color: Colors.amber, size: 20),
                          const SizedBox(width: 5),
                          Text(outfit.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17))
                        ]),
                        Row(children: [
                          IconButton(
                              icon: Icon(
                                  outfit.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: outfit.isFavorite
                                      ? Colors.red
                                      : Colors.grey),
                              onPressed: () {
                                setState(() =>
                                    outfit.isFavorite = !outfit.isFavorite);
                                _saveData();
                              }),
                          IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() => myOutfits
                                    .removeWhere((o) => o.id == outfit.id));
                                _saveData();
                              })
                        ])
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: outfit.clothesPositions.length,
                        itemBuilder: (context, cIdx) {
                          final clothId =
                              outfit.clothesPositions[cIdx].clothId;
                          final cloth = myWardrobe.firstWhere(
                              (c) => c.id == clothId,
                              orElse: () => Cloth(
                                  id: '',
                                  imagePath: '',
                                  mainCategory: '',
                                  subCategory: ''));
                          if (cloth.imagePath.isEmpty) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(cloth.imagePath),
                                    width: 80,
                                    height: 100,
                                    fit: BoxFit.cover)),
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

  // --- STATISTIQUES ---
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Icon(icon, size: 30, color: Colors.indigo),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))
        ]),
      ),
    );
  }

  Widget _buildStatsTab() {
    if (myWardrobe.isEmpty) {
      return const Center(
          child: Text("Ajoutez des habits pour voir vos stats !"));
    }

    Map<String, int> counts = {};
    for (var cloth in myWardrobe) {
      counts[cloth.mainCategory] = (counts[cloth.mainCategory] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: _buildStatCard(
                    "Habits", "${myWardrobe.length}", Icons.inventory_2)),
            Expanded(
                child: _buildStatCard(
                    "Tenues", "${myOutfits.length}", Icons.auto_awesome))
          ]),
          const SizedBox(height: 30),
          const Text("Répartition",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ...counts.entries.map((entry) {
            double percent = entry.value / myWardrobe.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text("${(percent * 100).toInt()}%")
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                      value: percent,
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 8)
                ],
              ),
            );
          })
        ],
      ),
    );
  }

  // --- DRESSING ---
  Widget _buildDressingContent() {
    if (_openedCategory == null) {
      var activeCategories = myCategories
          .where((cat) => myWardrobe.any((cloth) => cloth.mainCategory == cat.name))
          .toList();
      if (myWardrobe.isEmpty) {
        return const Center(child: Text("Dressing vide."));
      }
      return GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15),
        itemCount: activeCategories.length,
        itemBuilder: (context, index) {
          final cat = activeCategories[index];
          final count =
              myWardrobe.where((c) => c.mainCategory == cat.name).length;
          return InkWell(
            onTap: () => setState(() {
              _openedCategory = cat.name;
              _searchQuery = "";
              _selectedSubFilter = null;
            }),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.indigo.withValues(alpha: 0.3))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 60, color: Colors.indigo),
                  const SizedBox(height: 10),
                  Text(cat.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("$count habits",
                      style: const TextStyle(color: Colors.grey))
                ],
              ),
            ),
          );
        },
      );
    } else {
      var items = myWardrobe
          .where((c) => c.mainCategory == _openedCategory)
          .toList();
      if (_selectedSubFilter != null) {
        items = items
            .where((c) => c.subCategory == _selectedSubFilter)
            .toList();
      }
      if (_searchQuery.isNotEmpty) {
        items = items
            .where((c) => c.subCategory
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();
      }
      var subCats = myWardrobe
          .where((c) => c.mainCategory == _openedCategory)
          .map((c) => c.subCategory)
          .toSet()
          .toList();

      return Column(children: [
        AppBar(
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _openedCategory = null)),
            title: Text(_openedCategory!)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: TextField(
              decoration: InputDecoration(
                  hintText: "Rechercher...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30)),
                  contentPadding: EdgeInsets.zero),
              onChanged: (v) => setState(() => _searchQuery = v)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            FilterChip(
                label: const Text("Tout"),
                selected: _selectedSubFilter == null,
                onSelected: (v) => setState(() => _selectedSubFilter = null)),
            ...subCats.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: FilterChip(
                      label: Text(s),
                      selected: _selectedSubFilter == s,
                      onSelected: (v) => setState(
                          () => _selectedSubFilter = v ? s : null)),
                ))
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: Image.file(File(item.imagePath),
                                fit: BoxFit.cover)),
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(item.subCategory,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center))
                      ]),
                  Positioned(
                      right: 0,
                      child: IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              myWardrobe.removeWhere((c) => c.id == item.id);
                              if (!myWardrobe.any((c) =>
                                  c.mainCategory == _openedCategory)) {
                                _openedCategory = null;
                              }
                            });
                            _saveData();
                          }))
                ]),
              );
            },
          ),
        )
      ]);
    }
  }

  // ==========================================
  // --- AJOUTER HABIT (AVEC OPTION DÉTOURAGE) ---
  // ==========================================
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Appareil Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                }),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Galerie Photos"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                })
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
    bool shouldRemoveBg = false;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isProcessing
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Colors.indigo)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(img, height: 150)),

              const SizedBox(height: 15),

              Container(
                decoration: BoxDecoration(
                  color: shouldRemoveBg
                      ? Colors.indigo.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: Border.all(
                      color: shouldRemoveBg
                          ? Colors.indigo
                          : Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SwitchListTile(
                  title: const Text("Détourer l'image",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text("Retire l'arrière-plan via IA",
                      style: TextStyle(fontSize: 12)),
                  value: shouldRemoveBg,
                  activeThumbColor: Colors.indigo, // CORRIGÉ : Utilisation de activeThumbColor
                  onChanged: isProcessing
                      ? null
                      : (val) => setModalState(() => shouldRemoveBg = val),
                ),
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5)),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  value: sCat,
                  items: [
                    ...myCategories.map((c) => DropdownMenuItem(
                        value: c.name, child: Text(c.name))),
                    const DropdownMenuItem(
                        value: "NEW",
                        child: Text("+ Créer une catégorie",
                            style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold)))
                  ],
                  onChanged: (v) {
                    if (v == "NEW") {
                      _addNewMainCategory(setModalState);
                    } else {
                      setModalState(() {
                        sCat = v!;
                        sSub = myCategories
                            .firstWhere((c) => c.name == v)
                            .subCategories[0];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5)),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  value: sSub,
                  items: [
                    ...myCategories
                        .firstWhere((c) => c.name == sCat)
                        .subCategories
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s))),
                    const DropdownMenuItem(
                        value: "NEW_S",
                        child: Text("+ Créer un type",
                            style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold)))
                  ],
                  onChanged: (v) {
                    if (v == "NEW_S") {
                      _addNewSubCategory(sCat, setModalState);
                    } else {
                      setModalState(() => sSub = v!);
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: isProcessing
                    ? null
                    : () async {
                        File finalImage = img;

                        if (shouldRemoveBg) {
                          setModalState(() => isProcessing = true);

                          Uint8List? processedData =
                              await _removeBackground(img);

                          if (processedData != null) {
                            final String newPath = img.path.replaceAll(
                                RegExp(r'\.(jpg|jpeg|png)$'), '_nobg.webp');
                            finalImage = await File(newPath)
                                .writeAsBytes(processedData);
                          } else {
                            debugPrint(
                                "Échec du détourage, sauvegarde de l'image originale.");
                          }

                          setModalState(() => isProcessing = false);
                        }

                        setState(() => myWardrobe.add(Cloth(
                            id: DateTime.now().toString(),
                            imagePath: finalImage.path,
                            mainCategory: sCat,
                            subCategory: sSub)));

                        await _saveData(); // Ajout du await pour sécuriser la sauvegarde
                        if (!context.mounted) return; // CORRIGÉ : Vérification avant utilisation de Navigator
                        Navigator.pop(context);
                      },
                child: Text(isProcessing
                    ? "Traitement IA en cours..."
                    : "Ajouter à mon dressing"),
              )
            ],
          ),
        ),
      ),
    );
  }
  // ==========================================

  void _addNewMainCategory(Function m) {
    TextEditingController c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Catégorie"),
        content: TextField(controller: c, autofocus: true),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => myCategories
                  .add(Category(name: c.text, subCategories: ['Général'])));
              _saveData();
              m(() {});
              Navigator.pop(ctx);
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  void _addNewSubCategory(String cat, Function m) {
    TextEditingController c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Type de $cat"),
        content: TextField(controller: c, autofocus: true),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => myCategories
                  .firstWhere((c) => c.name == cat)
                  .subCategories
                  .add(c.text));
              _saveData();
              m(() {});
              Navigator.pop(ctx);
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _openedCategory == null
          ? AppBar(title: const Text('My Dressing'), centerTitle: true)
          : null,
      body: [
        _buildDressingContent(),
        _buildOutfitsTab(),
        _buildStatsTab()
      ][_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() {
          _selectedIndex = i;
          _openedCategory = null;
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.checkroom), label: 'Dressing'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Tenues'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Stats')
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? null
          : FloatingActionButton(
              onPressed: _selectedIndex == 0
                  ? _showImageSourceOptions
                  : () => _openOutfitEditor(),
              child: const Icon(Icons.add),
            ),
    );
  }
}