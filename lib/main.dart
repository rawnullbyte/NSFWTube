import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.black, // Navigation bar color
    statusBarColor: Colors.black, // Status bar color
  ));
  runApp(NsfwTubeApp());
}

class NsfwTubeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSFWTube',
      theme: ThemeData.dark(), // Dark theme
      home: VideoScrollPage(),
    );
  }
}

class VideoScrollPage extends StatefulWidget {
  @override
  _VideoScrollPageState createState() => _VideoScrollPageState();
}

class _VideoScrollPageState extends State<VideoScrollPage> with WidgetsBindingObserver {
  late PageController _pageController;
  late List<String> _videoUrls; // List of video/photo URLs
  bool _isLoading = false;
  bool _isRefreshing = false;
  int _currentIndex = 0;
  List<String> _lastSearches = [];
  int _videosWatched = 0;
  int _totalTimeSpent = 0;
  int _currentPage = 1;
  int _failedLoads = 0;
  DateTime? _lastVideoStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _videoUrls = []; // Initialize empty video list
    _loadPreferences(); // Load preferences
    _loadVideos();

    _pageController.addListener(() {
      if (_pageController.position.pixels == _pageController.position.maxScrollExtent) {
        _loadVideos(page: _currentPage + 1); // Load more videos when reaching the end
      }
      _prefetchImages(_pageController.page?.toInt() ?? 0); // Prefetch images ahead
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App is in the background
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black, // Navigation bar color
        statusBarColor: Colors.black, // Status bar color
      ));
    } else if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent, // Navigation bar color
        statusBarColor: Colors.transparent, // Status bar color
      ));
    }
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSearches = prefs.getStringList('lastSearches') ?? [];
      _videosWatched = prefs.getInt('videosWatched') ?? 0;
      _totalTimeSpent = prefs.getInt('totalTimeSpent') ?? 0;
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lastSearches', _lastSearches);
    await prefs.setInt('videosWatched', _videosWatched);
    await prefs.setInt('totalTimeSpent', _totalTimeSpent);
  }

  Future<void> _loadVideos({int page = 1}) async {
    if (_isLoading) return; // Prevent multiple loads at the same time
    setState(() {
      _isLoading = true;
    });

    try {
      // Example Rule34 API request for fetching videos/photos
      final response = await http.get(Uri.parse('https://rule34.xxx/index.php?page=dapi&s=post&q=index&json=1&limit=20&pid=$page'));
      print('API Response: ${response.body}'); // Debugging: Print the API response

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed Data: $data'); // Debugging: Print the parsed data

        setState(() {
          _videoUrls.addAll(data.map((item) => item['file_url'] ?? '').toList().cast<String>());
          _currentPage = page;
        });
      } else {
        print('Failed to load videos: ${response.statusCode}'); // Debugging: Print the error status code
        throw Exception('Failed to load videos');
      }
    } catch (e) {
      print('Error: $e'); // Debugging: Print any errors that occur
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshVideos() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final response = await http.get(Uri.parse('https://rule34.xxx/index.php?page=dapi&s=post&q=index&json=1&limit=20&pid=1'));
      print('API Response: ${response.body}'); // Debugging: Print the API response

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed Data: $data'); // Debugging: Print the parsed data

        setState(() {
          _videoUrls = data.map((item) => item['file_url'] ?? '').toList().cast<String>();
          _currentPage = 1;
        });
      } else {
        print('Failed to refresh videos: ${response.statusCode}'); // Debugging: Print the error status code
        throw Exception('Failed to refresh videos');
      }
    } catch (e) {
      print('Error: $e'); // Debugging: Print any errors that occur
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  void _searchVideos(String query) async {
    setState(() {
      _isLoading = true;
    });

    // Store the search query
    _lastSearches.insert(0, query);
    if (_lastSearches.length > 5) _lastSearches.removeLast();

    // Save the search preferences
    await _savePreferences();

    try {
      // Call the API to search videos based on the tag
      final response = await http.get(Uri.parse('https://rule34.xxx/index.php?page=dapi&s=post&q=index&tags=$query&json=1'));
      print('API Response: ${response.body}'); // Debugging: Print the API response

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Parsed Data: $data'); // Debugging: Print the parsed data

        setState(() {
          _videoUrls = data.map((item) => item['file_url'] ?? '').toList().cast<String>();
          _currentPage = 1;
        });
      } else {
        print('Failed to search videos: ${response.statusCode}'); // Debugging: Print the error status code
      }
    } catch (e) {
      print('Error: $e'); // Debugging: Print any errors that occur
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _prefetchImages(int currentIndex) {
    for (int i = currentIndex + 1; i <= currentIndex + 5 && i < _videoUrls.length; i++) {
      CachedNetworkImageProvider(_videoUrls[i]).resolve(ImageConfiguration());
    }
  }

  void _showVideoDetails(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 10),
            Text('URL: $url'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _incrementVideoWatchCount() {
    setState(() {
      _videosWatched++;
      if (_lastVideoStartTime != null) {
        final duration = DateTime.now().difference(_lastVideoStartTime!);
        _totalTimeSpent += duration.inMinutes;
      }
      _lastVideoStartTime = DateTime.now();
      _savePreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NSFWTube'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _refreshVideos(),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: () => _showStatsDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onSubmitted: (query) => _searchVideos(query),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading && _videoUrls.isEmpty
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshVideos,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videoUrls.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _incrementVideoWatchCount();
                      _showVideoDetails(_videoUrls[index]);
                    },
                    child: CachedNetworkImage(
                      imageUrl: _videoUrls[index],
                      fit: BoxFit.contain, // Ensure the entire image is visible
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) {
                        // Skip the image if it fails to load
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _videoUrls.removeAt(index);
                            _failedLoads++;
                          });
                        });
                        return Container();
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Videos Watched: $_videosWatched'),
            Text('Total Time Spent: $_totalTimeSpent minutes'),
            Text('Last 5 Searches:'),
            for (var search in _lastSearches) Text(search),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

