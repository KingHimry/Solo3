import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokemonExplorerApp());
}

class PokemonExplorerApp extends StatefulWidget {
  const PokemonExplorerApp({super.key});

  @override
  State<PokemonExplorerApp> createState() => _PokemonExplorerAppState();
}

class _PokemonExplorerAppState extends State<PokemonExplorerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _themeKey = 'themeMode';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTheme();
    });
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey) ?? 'system';
    setState(() {
      _themeMode = switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  } catch(_){

    }
}

  Future<void> _setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pokémon Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: HomeScreen(
        themeMode: _themeMode,
        onThemeChanged: _setTheme,
      ),
    );
  }
}

class Pokemon {
  final int id;
  final String name;
  final String spriteUrl;
  final int order;

  const Pokemon({
    required this.id,
    required this.name,
    required this.spriteUrl,
    required this.order,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'] as Map<String, dynamic>?;
    final other = sprites?['other'] as Map<String, dynamic>?;
    final official = other?['official-artwork'] as Map<String, dynamic>?;
    final image = official?['front_default'] as String? ?? sprites?['front_default'] as String? ?? '';

    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      spriteUrl: image,
      order: (json['order'] as int?) ?? json['id'] as int,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'spriteUrl': spriteUrl,
    'orderValue': order,
  };

  factory Pokemon.fromMap(Map<String, Object?> map) {
    return Pokemon(
      id: map['id'] as int,
      name: map['name'] as String,
      spriteUrl: map['spriteUrl'] as String,
      order: map['orderValue'] as int,
    );
  }
}

class SavedPokemon {
  final int? dbId;
  final int pokemonId;
  final String name;
  final String spriteUrl;
  final String note;
  final DateTime savedAt;

  const SavedPokemon({
    this.dbId,
    required this.pokemonId,
    required this.name,
    required this.spriteUrl,
    required this.note,
    required this.savedAt,
  });

  Map<String, Object?> toMap() => {
    'dbId': dbId,
    'pokemonId': pokemonId,
    'name': name,
    'spriteUrl': spriteUrl,
    'note': note,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedPokemon.fromMap(Map<String, Object?> map) {
    return SavedPokemon(
      dbId: map['dbId'] as int?,
      pokemonId: map['pokemonId'] as int,
      name: map['name'] as String,
      spriteUrl: map['spriteUrl'] as String,
      note: (map['note'] as String?) ?? '',
      savedAt: DateTime.parse(map['savedAt'] as String),
    );
  }
}

class PokemonApi {
  static const String baseUrl = 'https://pokeapi.co/api/v2';

  Future<List<Pokemon>> fetchPokemonList({required String query, int limit = 30}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      final response = await http.get(Uri.parse('$baseUrl/pokemon?limit=$limit&offset=0'));
      if (response.statusCode != 200) {
        throw Exception('Failed to load Pokémon list');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];
      final items = <Pokemon>[];
      for (final item in results) {
        final itemMap = item as Map<String, dynamic>;
        final detail = await http.get(Uri.parse(itemMap['url'] as String));
        if (detail.statusCode == 200) {
          items.add(Pokemon.fromJson(jsonDecode(detail.body) as Map<String, dynamic>));
        }
      }
      return items;
    }

    final response = await http.get(Uri.parse('$baseUrl/pokemon/${normalized.replaceAll(' ', '')}'));
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load Pokémon');
    }
    return [Pokemon.fromJson(jsonDecode(response.body) as Map<String, dynamic>)];
  }
}

class PokemonDatabase {
  static const _dbName = 'pokemon_explorer.db';
  static const _dbVersion = 1;
  static const _table = 'saved_pokemon';
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            dbId INTEGER PRIMARY KEY AUTOINCREMENT,
            pokemonId INTEGER NOT NULL UNIQUE,
            name TEXT NOT NULL,
            spriteUrl TEXT NOT NULL,
            note TEXT NOT NULL,
            savedAt TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<SavedPokemon>> getAll() async {
    final db = await database;
    final rows = await db.query(_table, orderBy: 'savedAt DESC');
    return rows.map((row) => SavedPokemon.fromMap(row)).toList();
  }

  Future<bool> isSaved(int pokemonId) async {
    final db = await database;
    final rows = await db.query(_table, where: 'pokemonId = ?', whereArgs: [pokemonId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> insert(SavedPokemon pokemon) async {
    final db = await database;
    return db.insert(
      _table,
      {
        'pokemonId': pokemon.pokemonId,
        'name': pokemon.name,
        'spriteUrl': pokemon.spriteUrl,
        'note': pokemon.note,
        'savedAt': pokemon.savedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(int pokemonId) async {
    final db = await database;
    return db.delete(_table, where: 'pokemonId = ?', whereArgs: [pokemonId]);
  }

  Future<int> clearAll() async {
    final db = await database;
    return db.delete(_table);
  }
}

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = PokemonApi();
  final _db = PokemonDatabase();
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final _prefsKey = 'lastPokemonQuery';

  bool _loading = false;
  String? _error;
  List<Pokemon> _results = [];
  List<SavedPokemon> _saved = [];
  String _lastQuery = '';
  int _tabIndex = 0;



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreState();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQuery = prefs.getString(_prefsKey) ?? '';
      _searchController.text = savedQuery;
      _lastQuery = savedQuery;

      await _loadSavedPokemon();
      if (savedQuery.isNotEmpty) {
        await _fetchPokemon(savedQuery, showSnack: false);
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Startup failed: $e';
      });
    }
  }

  Future<void> _loadSavedPokemon() async {
    final items = await _db.getAll();
    if (!mounted) return;
    setState(() => _saved = items);
  }

  Future<void> _saveQuery(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value);
  }

  Future<void> _fetchPokemon(String query, {bool showSnack = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final items = await _api.fetchPokemonList(query: query);
      if (!mounted) return;
      setState(() {
        _results = items;
        _loading = false;
        _lastQuery = query;
      });
      await _saveQuery(query);
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(items.isEmpty ? 'No Pokémon found' : 'Loaded ${items.length} Pokémon')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refresh() async {
    if (_lastQuery.isEmpty) {
      await _fetchPokemon('', showSnack: false);
    } else {
      await _fetchPokemon(_lastQuery, showSnack: false);
    }
  }

  Future<void> _savePokemon(Pokemon pokemon) async {
    final note = _noteController.text.trim();
    final inserted = await _db.insert(
      SavedPokemon(
        pokemonId: pokemon.id,
        name: pokemon.name,
        spriteUrl: pokemon.spriteUrl,
        note: note,
        savedAt: DateTime.now(),
      ),
    );
    await _loadSavedPokemon();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(inserted > 0 ? '${pokemon.name} saved' : '${pokemon.name} updated')),
    );
    _noteController.clear();
    setState(() => _tabIndex = 1);
  }

  Future<void> _deleteSaved(int pokemonId) async {
    await _db.delete(pokemonId);
    await _loadSavedPokemon();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted')),
    );
  }

  Future<void> _clearAll() async {
    await _db.clearAll();
    await _loadSavedPokemon();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All saved Pokémon cleared')),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon Explorer'),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            initialValue: widget.themeMode,
            onSelected: widget.onThemeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('System theme')),
              PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tabIndex,
          children: [
            _buildBrowseTab(),
            _buildSavedTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.travel_explore_outlined), label: 'Browse'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Saved'),
        ],
      ),
    );
  }

  Widget _buildBrowseTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Pokémon by name',
              hintText: 'pikachu',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => _fetchPokemon(value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Optional note to save with favorite',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _fetchPokemon(_searchController.text),
            icon: const Icon(Icons.search),
            label: const Text('Fetch Pokémon'),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorState(
              message: _error!,
              onRetry: () => _fetchPokemon(_searchController.text),
            )
          else if (_results.isEmpty)
              _EmptyState(
                title: _searchController.text.trim().isEmpty ? 'No search yet' : 'No Pokémon found',
                message: _searchController.text.trim().isEmpty
                    ? 'Search for a Pokémon to load live API data.'
                    : 'Try another name or tap Retry after checking your connection.',
              )
            else
              ..._results.map((pokemon) => _PokemonCard(
                pokemon: pokemon,
                isSaved: _saved.any((item) => item.pokemonId == pokemon.id),
                onSave: () => _savePokemon(pokemon),
              )),
          const SizedBox(height: 24),
          Text(
            'Tip: use the Saved tab to verify persistence after closing and reopening the app.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    if (_saved.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EmptyState(
            title: 'No saved Pokémon yet',
            message: 'Save at least 5 favorites here to prove SQLite persistence.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Saved Pokémon (${_saved.length})', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._saved.map(
              (item) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: item.spriteUrl.isNotEmpty ? NetworkImage(item.spriteUrl) : null,
                child: item.spriteUrl.isEmpty ? const Icon(Icons.catching_pokemon) : null,
              ),
              title: Text('${item.name} #${item.pokemonId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.note.isNotEmpty) Text('Note: ${item.note}'),
                  Text('Saved ${item.savedAt}'),
                ],
              ),
              trailing: IconButton(
                onPressed: () => _deleteSaved(item.pokemonId),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PokemonCard extends StatelessWidget {
  final Pokemon pokemon;
  final bool isSaved;
  final VoidCallback onSave;

  const _PokemonCard({
    required this.pokemon,
    required this.isSaved,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: pokemon.spriteUrl.isNotEmpty ? NetworkImage(pokemon.spriteUrl) : null,
              child: pokemon.spriteUrl.isEmpty ? const Icon(Icons.catching_pokemon) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pokemon.name.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Pokédex #${pokemon.id}'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: isSaved ? null : onSave,
              icon: Icon(isSaved ? Icons.check : Icons.favorite_border),
              label: Text(isSaved ? 'Saved' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
