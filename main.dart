import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'V-Weather',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const WeatherHomeScreen(),
    );
  }
}

class WeatherHomeScreen extends StatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  State<WeatherHomeScreen> createState() => _WeatherHomeScreenState();
}

class _WeatherHomeScreenState extends State<WeatherHomeScreen> with WidgetsBindingObserver {
  final String apiKey = '2637de5b3153853d35ded18c45e8ffaf';
  final TextEditingController _cityController = TextEditingController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  String _cityName = 'Swabi';
  String _temperature = '--';
  String _highLowTemp = 'High: --° / Low: --°';
  String _description = 'Loading weather...';
  String _humidity = '--';
  String _windSpeed = '--';
  String _iconCode = '01d';
  String _precipitation = '0 mm';
  String _pressure = '--';
  String _airQuality = 'Good';
  String _uvIndex = '3.0';
  
  String _sunriseTime = '--:--';
  String _sunsetTime = '--:--';
  double _lat = 34.1439;
  double _lon = 72.4693;

  bool _isLoading = false;

  List<dynamic> _hourlyList = [];
  List<dynamic> _dailyList = [];
  List<String> _savedCities = [];

  String _outdoorActivityInsight = 'Analyzing outdoor activity suitability...';
  String _roadConditionInsight = 'Analyzing road conditions and visibility...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedCities();
    
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchWeather('Swabi');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_isPlayingAudio) {
        _audioPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPlayingAudio) {
        _audioPlayer.resume();
      }
    }
  }

  Future<void> _showWeatherNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'weather_channel_id',
      'Weather Alerts',
      channelDescription: 'Daily morning and weather condition alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> _playWeatherDataSound(String weatherCondition, bool isNight) async {
    try {
      String soundFile = 'sounds/day.mp3';
      String condition = weatherCondition.toLowerCase();

      if (condition.contains('rain') || condition.contains('drizzle') || condition.contains('thunderstorm')) {
        soundFile = 'sounds/rain.mp3';
      } else if (isNight || condition.contains('night')) {
        soundFile = 'sounds/night.mp3';
      } else if (condition.contains('wind')) {
        soundFile = 'sounds/wind.mp3';
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(soundFile));
      setState(() {
        _isPlayingAudio = true;
      });
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
      });
    } catch (e) {
      debugPrint("Audio stop error: $e");
    }
  }

  Future<void> _loadSavedCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedCities = prefs.getStringList('saved_cities') ?? ['Swabi', 'Islamabad', 'Peshawar'];
      });
    } catch (e) {
      debugPrint("Error loading saved cities: $e");
    }
  }

  Future<void> _removeCity(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedCities.remove(city);
      });
      await prefs.setStringList('saved_cities', _savedCities);
    } catch (e) {
      debugPrint("Error removing city: $e");
    }
  }

  void _generateSmartInsight(String condition, double temp, double wind) {
    String lowerCond = condition.toLowerCase();

    if (lowerCond.contains('rain') || lowerCond.contains('drizzle') || lowerCond.contains('thunderstorm')) {
      _outdoorActivityInsight = 'Outdoor Activities: Not recommended to play outside due to active rainfall.';
    } else if (lowerCond.contains('snow')) {
      _outdoorActivityInsight = 'Outdoor Activities: Wear warm clothing if going outside to play in the snow.';
    } else if (temp > 38) {
      _outdoorActivityInsight = 'Outdoor Activities: Unfavorable for daytime sports due to extreme heat.';
    } else if (temp < 5) {
      _outdoorActivityInsight = 'Outdoor Activities: Cold weather; bundle up properly before going outdoors.';
    } else if (lowerCond.contains('clear') || lowerCond.contains('cloud')) {
      _outdoorActivityInsight = 'Outdoor Activities: Excellent weather conditions to go outside and play sports.';
    } else {
      _outdoorActivityInsight = 'Outdoor Activities: Weather is generally acceptable for outdoor outings.';
    }

    if (lowerCond.contains('rain') || lowerCond.contains('drizzle')) {
      _roadConditionInsight = 'Road Safety: Slippery road surfaces and wet asphalt. Reduce driving speed.';
    } else if (lowerCond.contains('snow')) {
      _roadConditionInsight = 'Road Safety: Highly treacherous roads with poor tire traction. Use winter tires.';
    } else if (lowerCond.contains('fog') || lowerCond.contains('mist') || lowerCond.contains('haze')) {
      _roadConditionInsight = 'Road Safety: Low visibility ahead. Turn on fog lights and drive cautiously.';
    } else if (wind > 12) {
      _roadConditionInsight = 'Road Safety: High wind gusts on open highways. Maintain firm grip on steering.';
    } else {
      _roadConditionInsight = 'Road Safety: Dry road surfaces with clear visibility for safe driving.';
    }
  }

  Future<void> fetchAirQuality(double lat, double lon) async {
    try {
      final aqiUrl = 'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey';
      final response = await http.get(Uri.parse(aqiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int aqi = data['list'][0]['main']['aqi'];
        String aqiText = 'Good';
        if (aqi == 2) aqiText = 'Fair';
        else if (aqi == 3) aqiText = 'Average';
        else if (aqi == 4) aqiText = 'Poor';
        else if (aqi == 5) aqiText = 'Bad';

        setState(() {
          _airQuality = aqiText;
        });
      }
    } catch (e) {
      debugPrint("AQI fetch error: $e");
    }
  }

  Future<void> fetchWeather(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentWeatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';
      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric';

      final currentResponse = await http.get(Uri.parse(currentWeatherUrl));
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (currentResponse.statusCode == 200 && forecastResponse.statusCode == 200) {
        final currentData = json.decode(currentResponse.body);
        final forecastData = json.decode(forecastResponse.body);

        String icon = currentData['weather'][0]['icon'];
        bool isNightTime = icon.endsWith('n');
        double tempVal = (currentData['main']['temp'] as num).toDouble();
        double windVal = (currentData['wind']['speed'] as num).toDouble();
        String desc = currentData['weather'][0]['description'];
        String cityNameFetched = currentData['name'];

        double latVal = (currentData['coord']['lat'] as num).toDouble();
        double lonVal = (currentData['coord']['lon'] as num).toDouble();

        int sunriseTimestamp = currentData['sys']['sunrise'];
        int sunsetTimestamp = currentData['sys']['sunset'];
        
        String sunriseFormatted = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(sunriseTimestamp * 1000));
        String sunsetFormatted = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(sunsetTimestamp * 1000));

        List<dynamic> list = forecastData['list'];
        double highVal = tempVal;
        double lowVal = tempVal;
        for (int i = 0; i < 8 && i < list.length; i++) {
          double t = (list[i]['main']['temp'] as num).toDouble();
          if (t > highVal) highVal = t;
          if (t < lowVal) lowVal = t;
        }

        setState(() {
          _cityName = cityNameFetched;
          _temperature = '${tempVal.round()}°C';
          _highLowTemp = 'High: ${highVal.round()}° / Low: ${lowVal.round()}°';
          _description = desc;
          _humidity = '${currentData['main']['humidity']}%';
          _windSpeed = '$windVal m/s';
          _iconCode = icon;
          _pressure = '${currentData['main']['pressure']} hPa';
          _lat = latVal;
          _lon = lonVal;

          _sunriseTime = sunriseFormatted;
          _sunsetTime = sunsetFormatted;

          if (currentData.containsKey('rain') && currentData['rain'].containsKey('1h')) {
            _precipitation = '${currentData['rain']['1h']} mm';
          } else {
            _precipitation = '0 mm';
          }

          _hourlyList = list.take(8).toList();

          Map<String, dynamic> dailyMap = {};
          for (var item in list) {
            String date = item['dt_txt'].toString().split(' ')[0];
            if (!dailyMap.containsKey(date)) {
              dailyMap[date] = item;
            }
          }
          _dailyList = dailyMap.values.take(6).toList();

          _generateSmartInsight(desc, tempVal, windVal);
          _isLoading = false;
        });

        fetchAirQuality(latVal, lonVal);
        _playWeatherDataSound(desc, isNightTime);

        _showWeatherNotification(
          'Weather Update: $cityNameFetched',
          'Temperature is ${tempVal.round()}°C with $desc. Have a safe journey!',
        );
      } else {
        setState(() {
          _description = 'City not found!';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _description = 'Connection Error!';
        _isLoading = false;
      });
    }
  }

  Future<void> fetchWeatherByLocation() async {
    setState(() {
      _isLoading = true;
      _description = 'Fetching GPS location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _description = 'GPS is disabled';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _description = 'Permission denied';
            _isLoading = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final currentWeatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';
      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric';

      final currentResponse = await http.get(Uri.parse(currentWeatherUrl));
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (currentResponse.statusCode == 200 && forecastResponse.statusCode == 200) {
        final currentData = json.decode(currentResponse.body);
        final forecastData = json.decode(forecastResponse.body);

        String icon = currentData['weather'][0]['icon'];
        bool isNightTime = icon.endsWith('n');
        double tempVal = (currentData['main']['temp'] as num).toDouble();
        double windVal = (currentData['wind']['speed'] as num).toDouble();
        String desc = currentData['weather'][0]['description'];
        String cityNameFetched = currentData['name'];

        double latVal = (currentData['coord']['lat'] as num).toDouble();
        double lonVal = (currentData['coord']['lon'] as num).toDouble();

        int sunriseTimestamp = currentData['sys']['sunrise'];
        int sunsetTimestamp = currentData['sys']['sunset'];
        
        String sunriseFormatted = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(sunriseTimestamp * 1000));
        String sunsetFormatted = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(sunsetTimestamp * 1000));

        List<dynamic> list = forecastData['list'];
        double highVal = tempVal;
        double lowVal = tempVal;
        for (int i = 0; i < 8 && i < list.length; i++) {
          double t = (list[i]['main']['temp'] as num).toDouble();
          if (t > highVal) highVal = t;
          if (t < lowVal) lowVal = t;
        }

        setState(() {
          _cityName = cityNameFetched;
          _temperature = '${tempVal.round()}°C';
          _highLowTemp = 'High: ${highVal.round()}° / Low: ${lowVal.round()}°';
          _description = desc;
          _humidity = '${currentData['main']['humidity']}%';
          _windSpeed = '$windVal m/s';
          _iconCode = icon;
          _pressure = '${currentData['main']['pressure']} hPa';
          _lat = latVal;
          _lon = lonVal;

          _sunriseTime = sunriseFormatted;
          _sunsetTime = sunsetFormatted;

          _hourlyList = list.take(8).toList();

          Map<String, dynamic> dailyMap = {};
          for (var item in list) {
            String date = item['dt_txt'].toString().split(' ')[0];
            if (!dailyMap.containsKey(date)) {
              dailyMap[date] = item;
            }
          }
          _dailyList = dailyMap.values.take(6).toList();

          _generateSmartInsight(desc, tempVal, windVal);
          _isLoading = false;
        });

        fetchAirQuality(latVal, lonVal);
        _playWeatherDataSound(desc, isNightTime);

        _showWeatherNotification(
          'Current Location: $cityNameFetched',
          'Current temp is ${tempVal.round()}°C with $desc.',
        );
      }
    } catch (e) {
      setState(() {
        _description = 'Location Error!';
        _isLoading = false;
      });
    }
  }

  String _getBackgroundImage() {
    bool isNight = _iconCode.endsWith('n');
    String condition = _description.toLowerCase();

    if (condition.contains('rain') || condition.contains('drizzle') || condition.contains('thunderstorm')) {
      return 'assets/images/rainy.jpg';
    } else if (condition.contains('snow')) {
      return 'assets/images/snowy.jpg';
    } else if (isNight) {
      return 'assets/images/night.jpg';
    } else if (condition.contains('cloud')) {
      return 'assets/images/cloudy.jpg';
    } else {
      return 'assets/images/sunny.jpg';
    }
  }

  Widget _getWeatherVectorIcon(String iconCode, {double size = 32}) {
    bool isNight = iconCode.endsWith('n');

    if (isNight) {
      if (iconCode.startsWith('01')) {
        return Icon(Icons.nightlight_round, color: const Color(0xFFFFD54F), size: size);
      } else {
        return Icon(Icons.cloud, color: const Color(0xFFB0BEC5), size: size);
      }
    } else {
      if (iconCode.startsWith('01')) {
        return Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFFB300), size: size);
      } 
      else if (iconCode.startsWith('09') || iconCode.startsWith('10') || iconCode.startsWith('11')) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Icon(Icons.cloud, color: Colors.grey.shade300, size: size * 0.85),
              ),
              Positioned(
                bottom: 0,
                left: size * 0.15,
                right: size * 0.15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(Icons.water_drop, color: const Color(0xFF29B6F6), size: size * 0.35),
                    Icon(Icons.water_drop, color: const Color(0xFF29B6F6), size: size * 0.35),
                  ],
                ),
              ),
            ],
          ),
        );
      } 
      else if (iconCode.startsWith('02') || iconCode.startsWith('03') || iconCode.startsWith('04')) {
        return SizedBox(
          width: size * 1.2,
          height: size,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Icon(Icons.cloud, color: Colors.blueGrey.shade200, size: size * 0.75),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.cloud, color: Colors.white, size: size * 0.85),
              ),
            ],
          ),
        );
      } else if (iconCode.startsWith('13')) {
        return Icon(Icons.ac_unit, color: Colors.white, size: size);
      } else {
        return Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFFB300), size: size);
      }
    }
  }

  // Optimized Radar Map with RepaintBoundary for smooth scroll
  Widget _buildWeatherRadarMap() {
    LatLng currentCenter = LatLng(_lat, _lon);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.radar, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Live Rain Radar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Radar Intensity Guide:',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _LegendItem(color: Colors.lightBlueAccent, label: 'Light Rain'),
                      _LegendItem(color: Colors.green, label: 'Moderate'),
                      _LegendItem(color: Colors.amber, label: 'Heavy'),
                      _LegendItem(color: Colors.redAccent, label: 'Storm'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: currentCenter,
                    initialZoom: 6.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.viki.vweather',
                      retinaMode: true,
                    ),
                    TileLayer(
                      urlTemplate: 'https://tile.rainviewer.com/v2/weather/nowcast_120/{z}/{x}/{y}/256/3_1.png',
                      userAgentPackageName: 'com.viki.vweather',
                      tileBuilder: (context, child, tile) {
                        return Opacity(
                          opacity: 0.75,
                          child: child,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSunriseSunsetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.wb_twilight, color: Colors.amberAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Sunrise & Sunset',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 2,
                minY: 0,
                maxY: 1.5,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0),
                      FlSpot(1, 1.2),
                      FlSpot(2, 0),
                    ],
                    isCurved: true,
                    color: Colors.amberAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sunrise', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_sunriseTime, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.normal)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Sunset', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_sunsetTime, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.normal)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Optimized Chart with RepaintBoundary
  Widget _buildTemperatureTrendChart() {
    if (_hourlyList.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    for (int i = 0; i < _hourlyList.length; i++) {
      double temp = (_hourlyList[i]['main']['temp'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), temp));
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.access_time, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Next 24 Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < _hourlyList.length) {
                            String timeStr = index == 0 ? 'Now' : _hourlyList[index]['dt_txt'].toString().split(' ')[1].substring(0, 5);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                timeStr,
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.normal),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFFFFD54F),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '$_cityName $_temperature',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isPlayingAudio ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            onPressed: _isPlayingAudio ? _stopAudio : () => _playWeatherDataSound(_description, _iconCode.endsWith('n')),
            tooltip: _isPlayingAudio ? 'Mute Audio' : 'Play Weather Audio',
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_getBackgroundImage()),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search City...',
                          hintStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF1E2235).withValues(alpha: 0.85),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () => fetchWeather(_cityController.text),
                          ),
                        ),
                        onSubmitted: (value) => fetchWeather(value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.white),
                        tooltip: 'Use GPS Location',
                        onPressed: fetchWeatherByLocation,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        _temperature,
                                        style: const TextStyle(
                                          fontSize: 72,
                                          color: Colors.white,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _highLowTemp,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _description.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          letterSpacing: 2.0,
                                          color: Colors.white60,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            if (_savedCities.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.star_rounded, color: Colors.amberAccent, size: 20),
                                        SizedBox(width: 6),
                                        Text(
                                          'Favorite Cities',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 40,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _savedCities.length,
                                        itemBuilder: (context, index) {
                                          final city = _savedCities[index];
                                          final isSelected = city == _cityName;

                                          return Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            child: InkWell(
                                              onTap: () {
                                                _cityController.text = city;
                                                fetchWeather(city);
                                              },
                                              onLongPress: () => _removeCity(city),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white.withValues(alpha: 0.3)
                                                      : const Color(0xFF1E2235).withValues(alpha: 0.85),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(city, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                    const SizedBox(width: 6),
                                                    GestureDetector(
                                                      onTap: () => _removeCity(city),
                                                      child: const Icon(Icons.close, color: Colors.white60, size: 14),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),

                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2235).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.lightbulb_rounded, color: Colors.amberAccent, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Smart Weather Insight',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.sports_soccer, color: Colors.white70, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _outdoorActivityInsight,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.minor_crash, color: Colors.white70, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _roadConditionInsight,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            SliverToBoxAdapter(child: _buildTemperatureTrendChart()),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),
                            
                            SliverToBoxAdapter(child: _buildSunriseSunsetCard()),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2235).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.calendar_month, color: Colors.white70, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Next 6 Days',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _dailyList.length,
                                      itemBuilder: (context, index) {
                                        var dayData = _dailyList[index];
                                        String dtTxt = index == 0 ? 'Today' : dayData['dt_txt'].toString().split(' ')[0];
                                        double temp = (dayData['main']['temp'] as num).toDouble();
                                        String desc = dayData['weather'][0]['description'];
                                        String icon = dayData['weather'][0]['icon'];

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: 70,
                                                child: Text(
                                                  dtTxt,
                                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  _getWeatherVectorIcon(icon, size: 24),
                                                  const SizedBox(width: 10),
                                                  SizedBox(
                                                    width: 100,
                                                    child: Text(
                                                      desc.toUpperCase(),
                                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${temp.round()}° / ${(temp + 8).round()}°',
                                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.normal),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2235).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Detailed Weather Metrics',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 12),
                                    GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.95,
                                      children: [
                                        _buildDetailedMetricCard(
                                          Icons.water_drop,
                                          'Precipitation',
                                          _precipitation,
                                          'mm',
                                          _precipitation == '0 mm' ? 'No rainfall expected' : 'Active rainfall detected',
                                        ),
                                        _buildDetailedMetricCard(
                                          Icons.air,
                                          'Wind Speed',
                                          _windSpeed,
                                          'm/s',
                                          ((double.tryParse(_windSpeed.replaceAll(' m/s', '')) ?? 0) > 10) ? 'High wind gusts' : 'Calm breeze flow',
                                        ),
                                        _buildDetailedMetricCard(
                                          Icons.opacity,
                                          'Humidity',
                                          _humidity,
                                          '%',
                                          ((int.tryParse(_humidity.replaceAll('%', '')) ?? 0) > 70) ? 'High moisture in air' : 'Comfortable humidity level',
                                        ),
                                        _buildDetailedMetricCard(
                                          Icons.speed,
                                          'Pressure',
                                          _pressure,
                                          'hPa',
                                          'Normal atmospheric range',
                                        ),
                                        _buildDetailedMetricCard(
                                          Icons.air_rounded,
                                          'Air Quality',
                                          _airQuality,
                                          '',
                                          _airQuality.contains('Good') ? 'Healthy air conditions' : 'Moderate pollutant levels',
                                        ),
                                        _buildDetailedMetricCard(
                                          Icons.wb_sunny,
                                          'UV Index',
                                          _uvIndex,
                                          '',
                                          'Moderate sun exposure',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            SliverToBoxAdapter(child: _buildWeatherRadarMap()),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedMetricCard(IconData icon, String title, String rawValue, String unit, String subtitle) {
    String numericPart = rawValue;
    String cleanValue = rawValue.trim();
    
    if (unit.isNotEmpty && cleanValue.endsWith(unit)) {
      numericPart = cleanValue.substring(0, cleanValue.length - unit.length).trim();
    } else if (cleanValue.endsWith('%')) {
      numericPart = cleanValue.substring(0, cleanValue.length - 1).trim();
      unit = '%';
    } else if (cleanValue.endsWith('mm')) {
      numericPart = cleanValue.substring(0, cleanValue.length - 2).trim();
      unit = 'mm';
    } else if (cleanValue.endsWith('hPa')) {
      numericPart = cleanValue.substring(0, cleanValue.length - 3).trim();
      unit = 'hPa';
    } else if (cleanValue.endsWith('m/s')) {
      numericPart = cleanValue.substring(0, cleanValue.length - 3).trim();
      unit = 'm/s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    numericPart,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 9.5, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}