import 'package:flutter/material.dart';
import 'dart:math';
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
      home: const NumberGuessGame(),
    );
  }
}

class NumberGuessGame extends StatefulWidget {
  const NumberGuessGame({super.key});

  @override
  State<NumberGuessGame> createState() => _NumberGuessGameState();
}

class _NumberGuessGameState extends State<NumberGuessGame> {
  int _numberToGuess = Random().nextInt(100) + 1; //nextInt(100)だけだと０から９９になってしまう
  String _message = '私が思い浮かべている数字はなんでしょう(1～100)';
  final TextEditingController _controller = TextEditingController();
  int _count = 0;

  void _guessNumber() {
    int? userGuess = int.tryParse(_controller.text); //?はnullの可能性もあるという意味
    if (userGuess == null || userGuess > 100 || userGuess < 0) {
      _message = '1から100の数値を入力してください';
      setState(() {
        _controller.clear();
      });
    } else if (userGuess == _numberToGuess) {
      _count++;
      _message =
      'おめでとうございます！「$_numberToGuess」で正解です！\n${_count}回目で当てました。新しい数字を当ててください';
      _numberToGuess = Random().nextInt(100) + 1;
      _count = 0;
    } else if (userGuess > _numberToGuess) {
      _count++;
      _message = '「$userGuess」は大きすぎます！もう一度試してみてください。';
    } else if (userGuess < _numberToGuess) {
      _count++;
      _message = '「$userGuess」は小さすぎます！もう一度試してみてください。';
    }
    setState(() {
      _controller.clear();
    });
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('数字当てゲーム'),
        ),

        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  _message,
                  style: TextStyle(fontSize: 15),
              ),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'あなたの予想を入力してください',
                ),
              ),
              ElevatedButton(
                onPressed: _guessNumber,
                child: Text('予想を回答する'),
              ),
            ],
          ),
        ),

      );
    }

}

