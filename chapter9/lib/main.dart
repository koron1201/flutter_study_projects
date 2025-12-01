import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //Firebaseの非同期処理を安全に行うための処理
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

const collectionKey = 'hamano_kanta';

class _MyHomePageState extends State<MyHomePage> {
  List<Item> items = [];
  final TextEditingController textEditingController = TextEditingController();
  late FirebaseFirestore firestore;

  @override
  void initState() {
    super.initState();
    firestore =FirebaseFirestore.instance;
    watch();
  }

  //データ更新監視
  //watch関数はFirebaseFirestoreの特定のコレクション(collectionKeyで指定)からデータをリアルタイムで監視。Firestoreのコレクションから
  //スナップショット(データの瞬間的な状態)を取得し、そのデータに変更があった場合にlistenメソッドの中の処理を行う。データが変更されると、その新しい
  //データをitemsリストに格納し、setStateを用いてUIを自動的に子苦心する。ドキュメントは(event.docs.reversedによって)逆順に表示。各ドキュメントはitemオブジェクトに変換
  Future<void> watch() async {
    firestore.collection(collectionKey).snapshots().listen((event) {
      setState(() {
        items = event.docs.reversed
            .map(
              (document) =>
              Item.fromSnapshot(
                document.id,
                document.data(),
              ),
        )
            .toList(growable: false);
      });
    });
  }

  //保存する
  //save関数はFirebase　Firestoreにデータを非同期で保存する。まず、現在の日時を取得してユニークなドキュメントID(now.millisecondsSinceEpoch.toString())
  //を生成。DateTime.now().millsecondsSinceEpochは1970年1月1日00:00:00 UTC(協定世界時)から現在までのミリ秒数を整数で返す。
  //次に、そのIDを使用して新しいドキュメントをFirestoreの指定されたコレクションに保存。保存するデータは、現在の日時とテキストフィールドの内容
  //保存後はテキストフィールドをリセット。非同期処理でasyncとawaitが使われているが、awaitの部分で、Firestoreへの書き込み操作が完了するまで次の処理に進まないようになっている。

  Future<void> save() async {
    final collection = firestore.collection(collectionKey);
    final now = DateTime.now();
    await collection.doc(now.millisecondsSinceEpoch.toString()).set({
      'date': now,
      'text': textEditingController.text,
    });
    textEditingController.text = '';
  }

  //完了・未完了に変更する
  Future<void> complete(Item item) async {
    final collection = firestore.collection(collectionKey);
    await collection.doc(item.id).set({
      'completed': !item.completed, //! = 反転
    }, SetOptions(merge: true));
  }

  //削除する
  Future<void> delete(String id) async {
    final collection = firestore.collection(collectionKey);
    await collection.doc(id).delete();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ToDo')),
      body: ListView.builder(
        itemBuilder: (context, index) {
          if (index == 0) {
            return ListTile(
              title: TextField(
                controller: textEditingController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,

              ),
              trailing: ElevatedButton(
                onPressed: () {
                  save();
                },
                child: Text('保存'),
              ),
            );
          }
          final item = items[index - 1];
          return Dismissible(
            key: Key(item.id),
            onDismissed: (direction) {
              delete(item.id);
            },
            child: ListTile(
              leading: Icon(
                item.completed ? Icons.check_box :
                Icons.check_box_outline_blank,
              ),
              onTap: () {
                complete(item);
              },
              title: Text(item.text),
              subtitle: Text(
                item.date.toString().replaceAll('-', '/').substring(0, 19),
              ),
            ),
          );
        },
        itemCount: items.length + 1,
      ),
    );
  }
}

class Item {
  const Item({
    required this.id,
    required this.text,
    required this.completed,
    required this.delete,
    required this.date,
  });

  final String id;
  final String text;
  final bool completed;
  final bool delete;
  final DateTime date;

  factory Item.fromSnapshot(String id,
      Map<String, dynamic> document) {
    return Item(
      id: id,
      text: document['text'].toString() ?? '',
      completed: document['completed'] ?? false,
      delete: document['delete'] ?? false,
      date:(document['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}