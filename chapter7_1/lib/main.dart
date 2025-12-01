import 'package:flutter/material.dart';
import 'dart:async';

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
        useMaterial3: true,
      ),
      home: const StopWatch(),
    );
  }
}

class StopWatch extends StatefulWidget {
  const StopWatch({Key? key}) : super(key: key);

  @override
  State<StopWatch> createState() => _StopWatchState();
}

class _StopWatchState extends State<StopWatch> {
  Timer _timer = Timer(Duration.zero, () {});
  final Stopwatch _stopwatch = Stopwatch();
  String _time = "00:00:000";

  void startTimer() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _timer = Timer.periodic(Duration(milliseconds: 1), (timer) {
        setState(() {
          final Duration elapsed = _stopwatch.elapsed;
          final String minute = elapsed.inMinutes.toString().padLeft(2, '0');
          final String sec = (elapsed.inSeconds % 60).toString().padLeft(
            2,
            '0',
          );
          final String milliSec = (elapsed.inMilliseconds % 1000)
              .toString()
              .padLeft(3, '0');
          _time = '$minute:$sec:$milliSec';
        });
      });
    }
  }

  void stopTimer() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer.cancel();
    }
  }

  void resetTimer() {
    _stopwatch.reset();
    setState(() {
      _time = '00:00:000';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('StopWatch')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('経過時間:'),
            Text('$_time', style: Theme.of(context).textTheme.headlineMedium),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: startTimer,
                  child: const Text('スタート'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: stopTimer, child: const Text('ストップ')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: resetTimer,
                  child: const Text('リセット'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
