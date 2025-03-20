import 'package:flutter/material.dart';
import 'package:myapp/models/masail.dart';
import 'package:myapp/screens/masail_detail_screen.dart';
import 'package:myapp/data/database_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:share_plus/share_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      home: const HomePage(), // Add the 'home' parameter here
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
  final int _pageSize = 5;
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

  // Step 1: Load data from SQLite first
  List<Masail> localMasails = await dbHelper.getMasailByLanguage(_selectedLanguage);
  if (localMasails.isNotEmpty) {
    setState(() {
      _masails = localMasails;
    });
    print('Loaded ${_masails.length} Masails from SQLite.');
  }

  // Step 2: Check internet connection
  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('No internet. Displaying offline data.');
    setState(() => _isLoading = false);
    return; // Stop here, SQLite data is already loaded
  }

  // Step 3: Fetch new data from Firestore
  try {
    print('Fetching data from Firestore...');
    QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore.instance
        .collection('masail')
        .where('language', isEqualTo: _selectedLanguage)
        .orderBy('title')
        .limit(_pageSize)
        .get();

    if (query.docs.isEmpty) {
      print('No new documents found in Firestore.');
      return;
    }

    _lastDocument = query.docs.last;

    // Step 4: Clear old SQLite data and save new data
    await dbHelper.deleteAllMasail();
    print('Deleted existing SQLite data.');

    for (var doc in query.docs) {
      Masail masail = Masail.fromMap(doc.data());
      await dbHelper.saveMasail(masail);
    }

    // Step 5: Load updated data from SQLite
    _masails = await dbHelper.getMasailByLanguage(_selectedLanguage);
    print('Updated SQLite and loaded ${_masails.length} Masails.');

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
  if (_isLoading) return;
  setState(() => _isLoading = true);

  try {
    print('Checking SQLite for more Masails...');
    List<Masail> localMasails = await dbHelper.getPaginatedMasail(_selectedLanguage, _masails.length, _pageSize);

    if (localMasails.isNotEmpty) {
      print('Loaded more Masails from SQLite.');
      setState(() {
        _masails.addAll(localMasails);
      });
    } else {
      print('No more data in SQLite. Fetching from Firestore...');
      if (_lastDocument == null) {
        print('No more data available.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No more masails found.'), duration: Duration(seconds: 2)),
        );
        return;
      }

      QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore.instance
          .collection('masail')
          .where('language', isEqualTo: _selectedLanguage)
          .orderBy('title')
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (query.docs.isEmpty) {
        print('No more documents found in Firestore.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No more masails found.'), duration: Duration(seconds: 2)),
        );
        return;
      }

      _lastDocument = query.docs.last;

      for (var doc in query.docs) {
        Masail masail = Masail.fromMap(doc.data());
        await dbHelper.saveMasail(masail);
      }

      _masails = await dbHelper.getMasailByLanguage(_selectedLanguage);
      print('Fetched and stored ${query.docs.length} new Masails from Firestore.');
    }
  } catch (error) {
    print('Error fetching more data: $error');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading more data: $error')));
  } finally {
    setState(() => _isLoading = false);
  }
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
              itemCount: filteredMasails.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredMasails.length) {
                  return _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _lastDocument != null
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton(
                                onPressed: _loadMoreMasails,
                                child: const Text('Load More'),
                              ),
                            )
                          : const SizedBox.shrink();
                }
                final masail = filteredMasails[index];
                return QuestionCard(masail: masail);
              },
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    masail.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.share, color: theme.primaryColor),
                  onPressed: () {
                    // Share functionality
                    Share.share(
                      '${masail.title}\n\n${masail.description}',
                      subject: 'Islamic Masail',
                    );
                  },
                ),
              ],
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