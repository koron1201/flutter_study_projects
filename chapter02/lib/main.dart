import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// firebase_options.dart はご自身のプロジェクトのものを使用してください
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ブックマークアプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'お気に入りサイト'),
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
  List<Map<String, String>> items = [
    {
      'title': '情報システムデザイン学系講義資料ページ',
      'url': 'https://lms.rd.dendai.ac.jp/mod/forum/view.php?id=1',
      'username': '',
      'password': '',
    },
    {
      'title': 'Web Class',
      'url': 'https://els.sa.dendai.ac.jp',
      'username': '',
      'password': '',
    },
    {
      'title': '電大コピー機_印刷サイト',
      'url':
          'https://ppcsvr01.prt.ms.dendai.ac.jp:9192/app?service=page/UserWebPrint',
      'username': '',
      'password': '',
    },
    {
      'title': '電大ユニパ',
      'url': 'https://portal.sa.dendai.ac.jp/uprx/up/pk/pky001/Pky00101.xhtml',
      'username': '',
      'password': '',
    },
  ];

  Future<void> saveCredentialsToFirestore(
    String title,
    String username,
    String password,
  ) async {
    final docId = title.replaceAll(RegExp(r'[/*?\[\]]'), '_');
    final docRef = FirebaseFirestore.instance
        .collection('credentials')
        .doc(docId);
    try {
      await docRef.set({'username': username, 'password': password});
      print(
        'Saved to Firestore: title=$title, username=$username, password=$password',
      );
    } catch (e) {
      print('Error saving to Firestore: $e');
      throw Exception('Failed to save credentials to Firestore');
    }
  }

  Future<Map<String, String>> loadCredentialsFromFirestore(String title) async {
    final docId = title.replaceAll(RegExp(r'[/*?\[\]]'), '_');
    final docRef = FirebaseFirestore.instance
        .collection('credentials')
        .doc(docId);
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      return {
        'username': data['username'] ?? '',
        'password': data['password'] ?? '',
      };
    }
    return {'username': '', 'password': ''};
  }

  @override
  void initState() {
    super.initState();
    _loadAllCredentialsFromFirestore();
  }

  Future<void> _loadAllCredentialsFromFirestore() async {
    List<Map<String, String>> updatedItems = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final title = item['title'] ?? '';
      if (title.isNotEmpty) {
        final credentials = await loadCredentialsFromFirestore(title);
        Map<String, String> updatedItem = Map.from(item);
        updatedItem['username'] = credentials['username'] ?? '';
        updatedItem['password'] = credentials['password'] ?? '';
        updatedItems.add(updatedItem);
      } else {
        updatedItems.add(item);
      }
    }
    if (mounted) {
      setState(() {
        items = updatedItems;
      });
    }
  }

  Future<void> _showEditDialog(Map<String, String> item, int index) async {
    final String currentTitle = item['title'] ?? '認証情報の編集';
    final TextEditingController usernameController = TextEditingController(
      text: item['username'],
    );
    final TextEditingController passwordController = TextEditingController(
      text: item['password'],
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('「$currentTitle」の認証情報'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'ユーザー名',
                    icon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    icon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                const Text(
                  '⚠️ 注意: パスワードは暗号化されずに保存されます。取り扱いにご注意ください。',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('保存'),
              onPressed: () async {
                print('「保存」ボタンが押されました！');

                final newUsername = usernameController.text;
                final newPassword = passwordController.text;

                print('Saving credentials for "$currentTitle":');
                print('Username from controller: "$newUsername"');
                print('Password from controller: "$newPassword"');

                await saveCredentialsToFirestore(
                  currentTitle,
                  newUsername,
                  newPassword,
                );
                final updatedCredentials = await loadCredentialsFromFirestore(
                  currentTitle,
                );
                if (mounted) {
                  setState(() {
                    items[index]['username'] =
                        updatedCredentials['username'] ?? '';
                    items[index]['password'] =
                        updatedCredentials['password'] ?? '';
                  });
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('「$currentTitle」の認証情報を保存しました')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final title = item['title'] ?? '';
          final url = item['url'] ?? '';
          final username = item['username'] ?? '';
          final password = item['password'] ?? '';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(title),
              // ★★★ UI改善: 未設定の場合の表示を明確化 ★★★
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isNotEmpty ? 'ユーザー名: $username' : 'ユーザー名: (未設定)',
                  ),
                  Text(
                    password.isNotEmpty
                        ? 'パスワード: ${'*' * password.length}'
                        : 'パスワード: (未設定)',
                  ),
                ],
              ),
              // ★★★ ここまで ★★★
              leading: const Icon(Icons.link),
              trailing: IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: '認証情報を編集',
                onPressed: () {
                  _showEditDialog(item, index);
                },
              ),
              onTap: () async {
                if (url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return WebViewPage(
                          title: title,
                          url: url,
                          username: username,
                          password: password,
                        );
                      },
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('URLが無効です')));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    required this.title,
    required this.url,
    required this.username,
    required this.password,
    super.key,
  });

  final String title;
  final String url;
  final String username;
  final String password;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool _isLoadingPage = true;
  bool _isAutoFilling = false;

  @override
  void initState() {
    super.initState();
    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoadingPage = true;
                  });
                }
              },
              onPageFinished: (String url) async {
                if (mounted) {
                  setState(() {
                    _isLoadingPage = false;
                  });
                }
                if (widget.username.isNotEmpty || widget.password.isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _isAutoFilling = true;
                    });
                  }

                  final String usernameSelectorString = "input[id='username']";
                  final String passwordSelectorString = "input[id='password']";
                  final String loginButtonSelectorString =
                      "button[id='loginbtn']";

                  String script = """
                    var uField = document.querySelector("$usernameSelectorString");
                    var pField = document.querySelector("$passwordSelectorString");
                    var loginButton = document.querySelector("$loginButtonSelectorString");

                    if (uField) {
                      uField.value = '${widget.username}';
                      var uInputEvent = new Event('input', { bubbles: true, cancelable: true });
                      uField.dispatchEvent(uInputEvent);
                      var uChangeEvent = new Event('change', { bubbles: true, cancelable: true });
                      uField.dispatchEvent(uChangeEvent);
                    }

                    if (pField) {
                      setTimeout(function() {
                        // pField.focus(); 
                        pField.value = '${widget.password}';

                        var pInputEvent = new Event('input', { bubbles: true, cancelable: true });
                        pField.dispatchEvent(pInputEvent);
                        var pChangeEvent = new Event('change', { bubbles: true, cancelable: true });
                        pField.dispatchEvent(pChangeEvent);
                        // pField.blur(); 

                        if (loginButton) {
                          if (uField && uField.value !== '' && pField.value !== '') {
                             loginButton.click();
                          }
                        }
                      }, 200); 

                    } else {
                      // pField が見つからない場合、デバッグ用にユーザー名フィールドにメッセージを表示しても良い
                      // if (uField) {
                      //   uField.value = '${widget.username}' + ' / pField_not_found';
                      // }
                    }
                  """;

                  try {
                    await controller.runJavaScript(script);
                  } catch (e) {
                    print("JavaScript実行エラー（Dart側）: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('自動入力スクリプト実行に失敗しました: $e')),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isAutoFilling = false;
                      });
                    }
                  }
                }
              },
              onWebResourceError: (WebResourceError error) {
                if (mounted) {
                  setState(() {
                    _isLoadingPage = false;
                  });
                }
                print(
                  "WebResourceError: code=${error.errorCode} description=${error.description} url=${error.url}",
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'ページ読み込みエラー: ${error.description} (Code: ${error.errorCode})',
                    ),
                  ),
                );
              },
              onNavigationRequest: (NavigationRequest request) {
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isLoadingPage || _isAutoFilling)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
