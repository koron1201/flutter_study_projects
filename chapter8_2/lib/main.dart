import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart'as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

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

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  TextEditingController controller = TextEditingController();
  String areaName = '';
  String weather = '';
  double temperature = 0;
  int humidity = 0;
  double temperatureMax = 0;
  double temperatureMin = 0;
  String weatherIcon = '';

  List<String> favoriteAreas = [];
  List<Map<String, dynamic>> weeklyForecast = [];
  List<Map<String, dynamic>> commuteWeather = [];
  String healthAdvice = '';

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteAreas = prefs.getStringList('favoriteAreas') ?? [];
    });
  }

  Future<void> addFavorite(String area) async {
    if (area.isEmpty || favoriteAreas.contains(area)) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteAreas.add(area);
      prefs.setStringList('favoriteAreas', favoriteAreas);
    });
  }

  Future<void> removeFavorite(String area) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteAreas.remove(area);
      prefs.setStringList('favoriteAreas', favoriteAreas);
    });
  }

  // 週間予報取得
  Future<void> loadWeeklyForecast(double lat, double lon) async {
    final response = await http.get(Uri.parse(
      'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=e23698bd91c71b4e9b02283f3474646f&lang=ja&units=metric',
    ));
    if (response.statusCode != 200) {
      setState(() {
        weeklyForecast = [];
        commuteWeather = [];
        healthAdvice = '';
      });
      return;
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> list = body['list'] ?? [];
    // 日付ごとにまとめる（1日1件のみ表示）
    final Map<String, Map<String, dynamic>> daily = {};
    // 通学時間帯抽出用
    List<Map<String, dynamic>> commuteList = [];
    final now = DateTime.now();
    final today = now.toLocal().toString().split(' ')[0];
    final tomorrow = now.add(Duration(days: 1)).toLocal().toString().split(' ')[0];
    // 気温・気圧リスト
    List<double> temps = [];
    List<double> pressures = [];
    for (var item in list) {
      final dtTxt = item['dt_txt'] as String?;
      if (dtTxt == null) continue;
      final date = dtTxt.split(' ')[0];
      if (!daily.containsKey(date)) {
        daily[date] = item;
      }
      // 通学時間帯（7-9時、17-19時）抽出
      final hour = int.tryParse(dtTxt.split(' ')[1].split(':')[0]) ?? -1;
      if ((date == today || date == tomorrow) &&
          ((7 <= hour && hour <= 9) || (17 <= hour && hour <= 19))) {
        commuteList.add(item);
      }
      // 気温・気圧収集
      final main = item['main'] ?? {};
      if (main['temp'] != null) temps.add((main['temp'] as num).toDouble());
      if (main['pressure'] != null) pressures.add((main['pressure'] as num).toDouble());
    }
    // アドバイス生成
    String advice = '';
    if (temps.isNotEmpty) {
      final tempMax = temps.reduce((a, b) => a > b ? a : b);
      final tempMin = temps.reduce((a, b) => a < b ? a : b);
      final tempDiff = (tempMax - tempMin).abs();
      if (tempDiff >= 8) {
        advice += '気温差が大きい日が続きます。体調管理に注意しましょう。\n';
      } else if (tempDiff >= 5) {
        advice += 'やや気温差があります。服装で調整しましょう。\n';
      }
    }
    if (pressures.length >= 2) {
      final pressureDiff = pressures.last - pressures.first;
      if (pressureDiff < -5) {
        advice += '気圧が下がる傾向です。頭痛や体調不良に注意。\n';
      } else if (pressureDiff > 5) {
        advice += '気圧が上昇傾向です。体調は安定しやすいです。\n';
      }
    }
    if (advice.isEmpty) advice = '体調管理に気をつけてお過ごしください。';
    setState(() {
      weeklyForecast = daily.values.take(7).toList();
      commuteWeather = commuteList;
      healthAdvice = advice;
    });
  }

  Future<void> loadWeather(String query) async {
    print('loadWeather: $query');
    final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?appid=e23698bd91c71b4e9b02283f3474646f&lang=ja&units=metric&q=$query'));
    if (response.statusCode != 200) {
      //失敗
      setState(() {
        weeklyForecast = [];
      });
      return;
    } else {
      //成功
      print(response.body);
      final body = json.decode(response.body) as Map<String, dynamic>;
      final main = (body['main'] ?? {}) as Map<String, dynamic>;
      setState(() {
        areaName = body['name'];
        weather = (body['weather']?[0]?['description'] ?? '') as String;
        humidity = (main['humidity'] ?? 0) as int;
        temperature = (main['temp'] ?? 0) as double;
        temperatureMax = (main['temp_max'] ?? 0) as double;
        temperatureMin = (main['temp_min'] ?? 0) as double;
        weatherIcon = (body['weather']?[0]?['icon'] ?? '') as String;
      });
      // 緯度・経度を取得して週間予報も取得
      final coord = body['coord'] as Map<String, dynamic>?;
      if (coord != null) {
        final lat = coord['lat']?.toDouble();
        final lon = coord['lon']?.toDouble();
        if (lat != null && lon != null) {
          await loadWeeklyForecast(lat, lon);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: '地域名を入力',
              border: InputBorder.none,
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                loadWeather(value);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.star),
              tooltip: 'お気に入りに追加',
              onPressed: () {
                addFavorite(controller.text);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.wb_sunny), text: '現在'),
              Tab(icon: Icon(Icons.calendar_today), text: '週間'),
              Tab(icon: Icon(Icons.directions_bus), text: '通学'),
              Tab(icon: Icon(Icons.favorite), text: 'お気に入り'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 現在の天気
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (weatherIcon.isNotEmpty)
                  Center(
                    child: Image.network(
                      'https://openweathermap.org/img/wn/' + weatherIcon + '@2x.png',
                      width: 100,
                      height: 100,
                      semanticLabel: '天気アイコン',
                    ),
                  ),
                Card(
                  child: ListTile(title: const Text('地域'), subtitle: Text(areaName)),
                ),
                Card(
                  child: ListTile(title: const Text('天気'), subtitle: Text(weather)),
                ),
                Card(
                  child: ListTile(title: const Text('温度'), subtitle: Text(temperature.toString())),
                ),
                Card(
                  child: ListTile(title: const Text('最高温度'), subtitle: Text(temperatureMax.toString())),
                ),
                Card(
                  child: ListTile(title: const Text('最低温度'), subtitle: Text(temperatureMin.toString())),
                ),
                Card(
                  child: ListTile(title: const Text('湿度'), subtitle: Text(humidity.toString())),
                ),
                if (healthAdvice.isNotEmpty)
                  Card(
                    color: Colors.red[50],
                    child: ListTile(
                      title: const Text('体調管理アドバイス'),
                      subtitle: Text(healthAdvice, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ),
              ],
            ),
            // 週間天気予報
            Padding(
              padding: const EdgeInsets.all(16),
              child: weeklyForecast.isNotEmpty
                  ? Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('週間天気予報', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: weeklyForecast.map((item) {
                                    final date = (item['dt_txt'] ?? '').toString().split(' ')[0];
                                    final main = item['main'] ?? {};
                                    final weather = (item['weather']?[0]?['description'] ?? '').toString();
                                    final temp = main['temp']?.toString() ?? '';
                                    final icon = (item['weather']?[0]?['icon'] ?? '').toString();
                                    return Card(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Container(
                                        width: 120,
                                        height: 180,
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (icon.isNotEmpty)
                                              Image.network('https://openweathermap.org/img/wn/' + icon + '@4x.png', width: 72, height: 72),
                                            const SizedBox(height: 6),
                                            Text(date, style: const TextStyle(fontSize: 13)),
                                            Flexible(
                                              child: Text(
                                                weather,
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text('$temp°C', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('気温グラフ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 260,
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx < 0 || idx >= weeklyForecast.length) return const SizedBox.shrink();
                                            final date = (weeklyForecast[idx]['dt_txt'] ?? '').toString().split(' ')[0].substring(5);
                                            return Text(date, style: const TextStyle(fontSize: 10));
                                          },
                                          reservedSize: 32,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    minX: 0,
                                    maxX: (weeklyForecast.length - 1).toDouble(),
                                    minY: weeklyForecast.map((e) => (e['main']?['temp'] as num?)?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b) - 2,
                                    maxY: weeklyForecast.map((e) => (e['main']?['temp'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b) + 2,
                                    lineBarsData: [
                                      LineChartBarData(
                                        isCurved: true,
                                        color: Colors.blue,
                                        barWidth: 4,
                                        dotData: FlDotData(show: true),
                                        spots: [
                                          for (int i = 0; i < weeklyForecast.length; i++)
                                            FlSpot(i.toDouble(), (weeklyForecast[i]['main']?['temp'] as num?)?.toDouble() ?? 0),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Center(child: Text('週間天気予報データがありません')),
            ),
            // 通学時間帯の天気
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (commuteWeather.isNotEmpty) ...[
                  const Text('通学時間帯の天気（今日・明日）', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...commuteWeather.map((item) {
                    final dtTxt = (item['dt_txt'] ?? '').toString();
                    final date = dtTxt.split(' ')[0];
                    final hour = dtTxt.split(' ')[1].substring(0, 5);
                    final main = item['main'] ?? {};
                    final weather = (item['weather']?[0]?['description'] ?? '').toString();
                    final temp = main['temp']?.toString() ?? '';
                    final icon = (item['weather']?[0]?['icon'] ?? '').toString();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: icon.isNotEmpty
                            ? Image.network('https://openweathermap.org/img/wn/' + icon + '@2x.png', width: 40, height: 40)
                            : null,
                        title: Text('$date $hour'),
                        subtitle: Text('$weather / $temp°C'),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
            // お気に入り地域
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('お気に入り地域', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...favoriteAreas.map((area) => Card(
                  child: ListTile(
                    title: Text(area),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => removeFavorite(area),
                    ),
                    onTap: () async {
                      setState(() {
                        controller.text = area;
                      });
                      await loadWeather(area);
                    },
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
