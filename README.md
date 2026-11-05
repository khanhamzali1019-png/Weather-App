V-Weather - Advanced Live Weather & Radar App

V-Weather is a modern, feature-rich Flutter application designed to provide real-time weather updates, interactive live precipitation maps, dynamic audio feedback, interactive temperature trend charts, and smart lifestyle insights.

**Key Features**

GPS & City Search Integration: Fetch live weather data automatically using GPS location or search for any city globally.

Live Rain Radar: Interactive live weather radar map powered by OpenStreetMap and RainViewer API.

24-Hour Temperature Trends: High-performance hourly temperature forecasting with smooth line charts (fl_chart).

6-Day Extended Forecast: Detailed day-by-day weather forecasts with custom vector-like weather icons.

Smart Lifestyle & Road Safety Insights: AI-style recommendations for outdoor activities and driving safety based on temperature, precipitation, and wind speeds.

Ambient Weather Sounds: Background audio effects (audioplayers) tailored to current weather conditions (Rain, Night, Breeze, Daylight).

Local Notifications: Automatic morning and real-time weather condition updates using flutter_local_notifications.

Favorite Cities Management: Save and quickly access your frequently searched locations using persistent storage (shared_preferences).

Sunrise & Sunset Visualization: Graphical representation of daylight cycles.

Smooth Custom Performance: Smooth UI scrolling with CustomScrollView and optimized layout boundaries.

**Tech Stack & Packages**

Framework: Flutter (Material 3 UI)

API Provider: OpenWeatherMap API & RainViewer Tile API

State Management & Lifecycle: Native StatefulWidget with WidgetsBindingObserver

**Dependencies Used:**

http: REST API calls for weather and air pollution data.

geolocator: High-accuracy device GPS location retrieval.

flutter_map & latlong2: OpenStreetMap tile rendering.

fl_chart: Interactive charts for temperature trends and daylight cycles.

audioplayers: Ambient sound playback based on weather conditions.

shared_preferences: Persistent local storage for favorite cities.

flutter_local_notifications: Local system alerts and notifications.

intl: Date and time formatting.

Required Project Assets

To ensure all visual and sound effects work properly, make sure your pubspec.yaml contains the following asset definitions:

flutter:
  assets:
    - assets/images/sunny.jpg
    - assets/images/cloudy.jpg
    - assets/images/rainy.jpg
    - assets/images/snowy.jpg
    - assets/images/night.jpg
    - assets/sounds/day.mp3
    - assets/sounds/rain.mp3
    - assets/sounds/night.mp3
    - assets/sounds/wind.mp3


**Getting Started**

Prerequisites

Flutter SDK installed (>=3.0.0)

Android Studio / VS Code configured with Flutter extension

An active OpenWeatherMap API Key

Installation & Run
Clone the repository:

git clone https://github.com/your-username/v-weather.git
cd v-weather


Install dependencies:

flutter pub get


API Key Setup:
Open lib/main.dart and ensure your OpenWeatherMap API key is assigned to apiKey:

final String apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';


Run the app:

flutter run


**Application Permissions**

Ensure the following permissions are granted in android/app/src/main/AndroidManifest.xml for GPS and audio functionalities:

<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>


**Contributing**
Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

License

This project is licensed under the MIT License - see the LICENSE file for details.
