import 'package:flutter/material.dart';
import 'package:myapp/models/masail.dart';
import 'package:myapp/screens/masail_detail_screen.dart';
import 'package:myapp/data/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const IslamicMasailApp());
}

class IslamicMasailApp extends StatelessWidget {
  const IslamicMasailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: Colors.teal[400],
        hintColor: Colors.grey[600],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20.0, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 16.0, color: Colors.black54),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[400],
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSearchVisible = false;
  List<Masail> _masails = [];
  String _searchQuery = '';
  final dbHelper = DatabaseHelper();
  int _page = 1;
  bool _isLoading = false;
  final int _pageSize = 30;
  DocumentSnapshot? _lastDocument;
  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'Hindi', 'Gujarati'];


  @override
  void initState() {
    super.initState();
    _loadMasails();
  }

  Future<void> _loadMasails() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      print('Fetching data from Firestore...');
      QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore.instance
          .collection('masail')
          .where('language', isEqualTo: _selectedLanguage)
          .get();
      print('Firestore query complete. Number of documents: ${query.docs.length}');

      if (query.docs.isEmpty) {
        print('No documents found in Firestore.');
        return; // Handle empty Firestore collection
      }

      await dbHelper.deleteAllMasail();
      print('Deleted existing data from SQLite.');

      for (var doc in query.docs) {
        Masail masail = Masail.fromMap(doc.data());
        final result = await dbHelper.saveMasail(masail);
        print('Inserted Masail into SQLite. Result: $result');
      }

      _masails = await dbHelper.getMasailByLanguage(_selectedLanguage);
      print('Fetched ${_masails.length} Masail from SQLite.');
    } catch (error) {
      print('Error fetching or saving data: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $error')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _loadMoreMasails() async {
    if (_isLoading) return; // Prevent multiple calls while loading
    setState(() => _isLoading = true);
    _page++;
    _loadMasails();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMasails = _masails
        .where((masail) =>
            masail.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            masail.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Islamic Masail',
          style: TextStyle(color: Colors.teal[700]),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[700]),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
              });
            },
          ),
          const SizedBox(width: 16), // Add some spacing
         DropdownButton<String>(
  value: _selectedLanguage,
  items: _languages.map((language) {
    return DropdownMenuItem<String>(
      value: language,
      child: Text(language),
    );
  }).toList(),
  onChanged: (value) {
    setState(() {
      _selectedLanguage = value!;
      _loadMasails();
    });
  },
),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search masails...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  prefixIcon: Icon(Icons.search, color: theme.hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: filteredMasails.length,
              itemBuilder: (context, index) {
                if (index == filteredMasails.length - 1 && !_isLoading && _lastDocument != null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final masail = filteredMasails[index];
                return QuestionCard(masail: masail);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_isLoading && _lastDocument != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _loadMoreMasails,
                child: const Text('Load More'),
              ),
            ),
        ],
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Masail masail;

  const QuestionCard({super.key, required this.masail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              masail.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              masail.description,
              style: TextStyle(color: theme.hintColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MasailDetailScreen(masail: masail),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Read more',
                    style: TextStyle(color: theme.primaryColor),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
