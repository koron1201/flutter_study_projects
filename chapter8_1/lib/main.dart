import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<List<String>> items = [
    ['Flutter解説', 'https://zenn.dev/nyarufoy/articles/e0bc5442e887ac'],
    ['Goggle', 'https://www.google.com'],
    ['Youtube', 'https://www.youtube.com'],
    [
      '電大ユニパ',
      'https://portal.sa.dendai.ac.jp/uprx/up/pk/pky001/Pky00101.xhtml',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ブックマーク')),
      body: ListView.builder(
        itemBuilder: (context, index) {
          final item = items[index];
          final title = item[0] ?? ''; //nullだったら空白
          final url = item[1] ?? '';
          return ListTile(
            title: Text(title),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return WebViewPage(title: title, url: url);
                  },
                ),
              );
            },
          );
        },
        itemCount: items.length,
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({required this.title, required this.url, super.key});

  final String title;
  final String url;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: controller),
    );
  }
}
