import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: false);
  runApp(const DarlingCloudApp());
}

class DarlingCloudApp extends StatelessWidget {
  const DarlingCloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darling Cloud',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _savedUrl;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedUrl = prefs.getString('server_url');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_savedUrl == null) {
      return const SetupPage();
    }
    return WebViewPage(url: _savedUrl!);
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Darling Cloud')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud, size: 80),
            const SizedBox(height: 24),
            const Text('输入网盘服务端地址', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '',
                labelText: '服务端地址',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final url = _controller.text.trim();
                if (url.isEmpty) return;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_url', url);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WebViewPage(url: url),
                    ),
                  );
                }
              },
              child: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _error = null; }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (e) => setState(() {
          _loading = false;
          _error = '网页加载失败：${e.description}';
        }),
        onNavigationRequest: (req) {
          // 拦截非 http/https 的链接，用外部浏览器打开
          if (req.url.startsWith('http://') || req.url.startsWith('https://')) {
            return NavigationDecision.navigate;
          }
          launchUrl(Uri.parse(req.url));
          return NavigationDecision.prevent;
        },
      ))
      ..setOnShowFileSelectorCallback(_onShowFileSelector)
      ..loadRequest(Uri.parse(widget.url));

    // 下载监听（Android）
    if (Platform.isAndroid) {
      _enableDownloadListener();
    }
  }

  void _enableDownloadListener() {
    _controller.setDownloadListener((DownloadRequest request) async {
      final status = await Permission.storage.request();
      if (!status.isGranted) return;

      final dir = await getExternalStorageDirectory();
      if (dir == null) return;

      final fileName = request.url.split('/').last.split('?').first;
      await FlutterDownloader.enqueue(
        url: request.url,
        savedDir: dir.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始下载：$fileName')),
        );
      }
    });
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: params.acceptMultiple,
      type: FileType.any,
    );
    if (result == null) return [];
    return result.files.map((f) => f.path!).where((p) => p.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Darling Cloud'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('server_url');
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
