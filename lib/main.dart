import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WardrobeApp());

// --- MODÈLES ---

class Category {
  String name;
  List<String> subCategories;
  Category({required this.name, required this.subCategories});

  Map<String, dynamic> toJson() => {'name': name, 'subCategories': subCategories};
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

  Cloth({required this.id, required this.imagePath, required this.mainCategory, required this.subCategory});

  Map<String, dynamic> toJson() => {'id': id, 'imagePath': imagePath, 'mainCategory': mainCategory, 'subCategory': subCategory};
  factory Cloth.fromJson(Map<String, dynamic> json) => Cloth(
    id: json['id'],
    imagePath: json['imagePath'],
    mainCategory: json['mainCategory'],
    subCategory: json['subCategory'],
  );
}

class Outfit {
  final String id;
  final String name;
  final List<String> clothesIds;
  bool isFavorite; // NOUVEAU

  Outfit({
    required this.id, 
    required this.name, 
    required this.clothesIds, 
    this.isFavorite = false // Par défaut non favori
  });

  Map<String, dynamic> toJson() => {
    'id': id, 
    'name': name, 
    'clothesIds': clothesIds,
    'isFavorite': isFavorite,
  };

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
    id: json['id'],
    name: json['name'],
    clothesIds: List<String>.from(json['clothesIds']),
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

  // --- PERSISTANCE ---

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wardrobe', jsonEncode(myWardrobe.map((e) => e.toJson()).toList()));
    await prefs.setString('categories', jsonEncode(myCategories.map((e) => e.toJson()).toList()));
    await prefs.setString('outfits', jsonEncode(myOutfits.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String? wS = prefs.getString('wardrobe');
      if (wS != null) myWardrobe = List<Cloth>.from(jsonDecode(wS).map((m) => Cloth.fromJson(m)));
      String? cS = prefs.getString('categories');
      if (cS != null) myCategories = List<Category>.from(jsonDecode(cS).map((m) => Category.fromJson(m)));
      String? oS = prefs.getString('outfits');
      if (oS != null) myOutfits = List<Outfit>.from(jsonDecode(oS).map((m) => Outfit.fromJson(m)));
    });
  }

  // --- VUES DRESSING (DOSSIERS + RECHERCHE) ---

  Widget _buildDressingContent() {
    if (_openedCategory == null) {
      var activeCategories = myCategories.where((cat) => myWardrobe.any((cloth) => cloth.mainCategory == cat.name)).toList();
      if (myWardrobe.isEmpty) return const Center(child: Text("Dressing vide.\nAjoutez votre premier habit !", textAlign: TextAlign.center));

      return GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15),
        itemCount: activeCategories.length,
        itemBuilder: (context, index) {
          final cat = activeCategories[index];
          final count = myWardrobe.where((c) => c.mainCategory == cat.name).length;
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
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 60, color: Colors.indigo),
                  const SizedBox(height: 10),
                  Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("$count habits", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      );
    } else {
      var items = myWardrobe.where((c) => c.mainCategory == _openedCategory).toList();
      if (_selectedSubFilter != null) items = items.where((c) => c.subCategory == _selectedSubFilter).toList();
      if (_searchQuery.isNotEmpty) items = items.where((c) => c.subCategory.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

      var subCatsInFolder = myWardrobe.where((c) => c.mainCategory == _openedCategory).map((c) => c.subCategory).toSet().toList();

      return Column(
        children: [
          AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _openedCategory = null)),
            title: Text(_openedCategory!),
            centerTitle: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Rechercher...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                FilterChip(
                  label: const Text("Tout"),
                  selected: _selectedSubFilter == null,
                  onSelected: (val) => setState(() => _selectedSubFilter = null),
                ),
                ...subCatsInFolder.map((sub) => Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: FilterChip(
                    label: Text(sub),
                    selected: _selectedSubFilter == sub,
                    onSelected: (val) => setState(() => _selectedSubFilter = val ? sub : null),
                  ),
                )).toList(),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: Image.file(File(item.imagePath), fit: BoxFit.cover)),
                      Padding(padding: const EdgeInsets.all(8), child: Text(item.subCategory, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ]),
                    Positioned(right: 0, child: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () {
                      setState(() {
                        myWardrobe.removeWhere((c) => c.id == item.id);
                        if (!myWardrobe.any((c) => c.mainCategory == _openedCategory)) _openedCategory = null;
                      });
                      _saveData();
                    })),
                  ]),
                );
              },
            ),
          ),
        ],
      );
    }
  }

  // --- VUE TENUES (AVEC FAVORIS) ---

  Widget _buildOutfitsTab() {
    if (myOutfits.isEmpty) return const Center(child: Text("Aucune tenue.\nCréez votre premier ensemble !", textAlign: TextAlign.center));

    // TRI : Favoris en premier
    List<Outfit> sortedOutfits = List.from(myOutfits);
    sortedOutfits.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });

    return ListView.builder(
      itemCount: sortedOutfits.length,
      itemBuilder: (context, index) {
        final outfit = sortedOutfits[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          elevation: outfit.isFavorite ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: outfit.isFavorite ? Colors.amber.withValues(alpha: 0.5) : Colors.transparent, 
              width: 2
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (outfit.isFavorite) const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 5),
                        Text(outfit.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            outfit.isFavorite ? Icons.favorite : Icons.favorite_border, 
                            color: outfit.isFavorite ? Colors.red : Colors.grey
                          ),
                          onPressed: () {
                            setState(() {
                              // On retrouve l'index réel dans la liste originale pour modifier la valeur
                              final originalIndex = myOutfits.indexWhere((o) => o.id == outfit.id);
                              myOutfits[originalIndex].isFavorite = !myOutfits[originalIndex].isFavorite;
                            });
                            _saveData();
                          },
                        ),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
                          setState(() => myOutfits.removeWhere((o) => o.id == outfit.id)); _saveData();
                        }),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: outfit.clothesIds.length,
                    itemBuilder: (context, cIndex) {
                      final clothId = outfit.clothesIds[cIndex];
                      final cloth = myWardrobe.firstWhere((c) => c.id == clothId, orElse: () => Cloth(id: '', imagePath: '', mainCategory: '', subCategory: ''));
                      if (cloth.id.isEmpty) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(cloth.imagePath), width: 90, height: 110, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- LOGIQUE STATS, AJOUT, etc. (INCHANGÉ) ---
  // ... [Les méthodes _buildStatsTab, _showImageSourceOptions, _pickImage, _showAddEntrySheet, etc. restent les mêmes]
  
  // (Note: Remets ici les fonctions manquantes du code précédent pour que l'app soit complète)

  @override
  Widget build(BuildContext context) {
    // Liste des pages pour le corps
    final List<Widget> _pages = [
      _buildDressingContent(),
      _buildOutfitsTab(),
      _buildStatsTab(),
    ];

    return Scaffold(
      appBar: _openedCategory == null 
        ? AppBar(title: const Text('My Dressing'), centerTitle: true)
        : null,
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
          _openedCategory = null; 
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: 'Dressing'),
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Tenues'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
      floatingActionButton: _selectedIndex == 2 ? null : FloatingActionButton.extended(
        onPressed: _selectedIndex == 0 ? _showImageSourceOptions : _showCreateOutfitSheet,
        label: Text(_selectedIndex == 0 ? "Ajouter" : "Nouvelle tenue"),
        icon: Icon(_selectedIndex == 0 ? Icons.add : Icons.auto_awesome),
      ),
    );
  }

  // --- MÉTHODES REQUISES (COPIÉES DES VERSIONS PRÉCÉDENTES) ---

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Icon(icon, size: 30, color: Colors.indigo), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12))])));
  }

  Widget _buildStatsTab() {
    if (myWardrobe.isEmpty) return const Center(child: Text("Ajoutez des habits pour voir vos stats !"));
    Map<String, int> counts = {};
    for (var cloth in myWardrobe) counts[cloth.mainCategory] = (counts[cloth.mainCategory] ?? 0) + 1;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: _buildStatCard("Habits", "${myWardrobe.length}", Icons.inventory_2)), Expanded(child: _buildStatCard("Tenues", "${myOutfits.length}", Icons.auto_awesome))]), const SizedBox(height: 30), const Text("Répartition", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 15), ...counts.entries.map((entry) { double percent = entry.value / myWardrobe.length; return Padding(padding: const EdgeInsets.only(bottom: 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(entry.key), Text("${(percent * 100).toInt()}%")]), const SizedBox(height: 5), LinearProgressIndicator(value: percent, borderRadius: BorderRadius.circular(10), minHeight: 8)])); }).toList()]));
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Appareil Photo"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }), ListTile(leading: const Icon(Icons.photo_library), title: const Text("Galerie Photos"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); })])));
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 50);
    if (file != null) _showAddEntrySheet(File(file.path));
  }

  void _showAddEntrySheet(File image) {
    String sCat = myCategories[0].name;
    String sSub = myCategories[0].subCategories[0];
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => StatefulBuilder(builder: (context, setModalState) => SafeArea(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(image, height: 150, width: 150, fit: BoxFit.cover)), const SizedBox(height: 20), DropdownButtonFormField<String>(value: sCat, decoration: const InputDecoration(labelText: "Catégorie", border: OutlineInputBorder()), items: [...myCategories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))), const DropdownMenuItem(value: "NEW", child: Text("+ Créer"))], onChanged: (v) => v == "NEW" ? _addNewMainCategory(setModalState) : setModalState(() { sCat = v!; sSub = myCategories.firstWhere((c) => c.name == v).subCategories[0]; })), const SizedBox(height: 15), DropdownButtonFormField<String>(value: sSub, decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()), items: [...myCategories.firstWhere((c) => c.name == sCat).subCategories.map((s) => DropdownMenuItem(value: s, child: Text(s))), const DropdownMenuItem(value: "NEW_S", child: Text("+ Créer"))], onChanged: (v) => v == "NEW_S" ? _addNewSubCategory(sCat, setModalState) : setModalState(() => sSub = v!)), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () { setState(() => myWardrobe.add(Cloth(id: DateTime.now().toString(), imagePath: image.path, mainCategory: sCat, subCategory: sSub))); _saveData(); Navigator.pop(context); }, child: const Text("Enregistrer l'habit"))])))));
  }

  void _addNewMainCategory(Function modalSetState) {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Nouvelle catégorie"), content: TextField(controller: c, autofocus: true), actions: [ElevatedButton(onPressed: () { setState(() => myCategories.add(Category(name: c.text, subCategories: ['Général']))); _saveData(); modalSetState(() {}); Navigator.pop(context); }, child: const Text("Ajouter"))]));
  }

  void _addNewSubCategory(String mainCat, Function modalSetState) {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: Text("Nouveau type de $mainCat"), content: TextField(controller: c, autofocus: true), actions: [ElevatedButton(onPressed: () { setState(() => myCategories.firstWhere((cat) => cat.name == mainCat).subCategories.add(c.text)); _saveData(); modalSetState(() {}); Navigator.pop(context); }, child: const Text("Ajouter"))]));
  }

  void _showCreateOutfitSheet() {
    List<String> selectedIds = [];
    TextEditingController nameController = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => StatefulBuilder(builder: (context, setModalState) => SafeArea(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Créer une tenue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom de la tenue")), const SizedBox(height: 15), SizedBox(height: 300, child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5), itemCount: myWardrobe.length, itemBuilder: (context, index) { final item = myWardrobe[index]; final isSelected = selectedIds.contains(item.id); return GestureDetector(onTap: () => setModalState(() => isSelected ? selectedIds.remove(item.id) : selectedIds.add(item.id)), child: Container(decoration: BoxDecoration(border: Border.all(color: isSelected ? Colors.indigo : Colors.transparent, width: 3), borderRadius: BorderRadius.circular(10)), child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.file(File(item.imagePath), fit: BoxFit.cover)))); })), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () { if (nameController.text.isNotEmpty && selectedIds.isNotEmpty) { setState(() => myOutfits.add(Outfit(id: DateTime.now().toString(), name: nameController.text, clothesIds: selectedIds))); _saveData(); Navigator.pop(context); } }, child: const Text("Enregistrer la tenue"))])))));
  }
}