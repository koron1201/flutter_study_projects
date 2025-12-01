import 'package:flutter/material.dart';

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

  double  height = 0.0;
  double  weight = 0.0;
  double  BMI = 0.0;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,

        title: Text(widget.title),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('身長(cm)'),
            TextField(
              onChanged: (value) {
                height = (double.tryParse(value) ?? 0);
                height /= 100;
              },
            ),
            SizedBox(height: 16,),
            Text('体重(kg)'),
            TextField(
              onChanged: (value) {
                weight = (double.tryParse(value) ?? 0);
              },
            ),
            SizedBox(height: 16,),
            ElevatedButton(onPressed: () {
              if(height <=0 || weight <= 0){
                setState(() {
                  BMI = 0;
                });
                return;
              }
              setState(() {
                BMI = weight / (height * height);
              });
            }, child: Text('計算する'),),
            SizedBox(height: 16,),
            Text('BMIは${BMI}です。'),


          ],
        ),
      ),
    );
  }
}
