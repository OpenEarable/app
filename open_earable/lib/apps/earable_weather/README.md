# Earable Weather Application

The Earable Weather application is a feature-rich Flutter application designed to provide real-time weather updates. It is an integral part of the OpenEarable project by TECO, utilizing a combination of sensor data and external weather services to deliver a comprehensive weather experience.

## Key Features

- **Real-time Weather Updates**: Retrieves current weather conditions and forecasts using the OpenWeather API.
- **Sensor Integration**: Leverages the OpenEarable device's barometer sensor to measure air pressure, enhancing weather predictions.
- **Audio Feedback**: Utilizes text-to-speech technology to audibly deliver weather updates.
- **Interactive UI**: Offers a dynamic user interface with animations for different weather conditions and a toggle for horizontal and vertical views.
- **Battery Level Monitoring**: Displays the battery level of the Earable device.
- **Pull-to-Refresh Functionality**: Allows users to update weather information with a simple gesture.

## Key Packages and APIs

- `http`: Enables network requests to fetch data from the OpenWeather API.
- `geolocator` and `geocoding`: Facilitate location services to determine the current city for weather updates.
- `lottie`: Provides fluid animations corresponding to different weather conditions.
- `flutter_tts`: Converts text weather updates into speech for audio feedback.
- `flutter_ffmpeg`: Used for audio processing tasks.

## Getting Started

1. **Clone the Repository**: Obtain the source code from the project's repository.
2. **Install Dependencies**: Run `flutter pub get` in the project directory to install the required packages.
3. **API Key Configuration**: Ensure that the OpenWeather API key is correctly set in the `config.dart` file.
4. **Build and Run**: Compile the app for your target device and run it.

## Extensions

- **Extended Weather Metrics**: Incorporate additional weather parameters like humidity, wind speed, and visibility.
- **Localization Support**: Add support for multiple languages for a broader user base.
- **Customizable Themes**: Implement theme options for personalized UI experiences.

## Limitations

- **Dependency on External Services**: The app relies on external APIs for weather data, which may lead to service interruptions.
- **Device Compatibility**: Currently tailored for OpenEarable devices; compatibility with other devices may require additional development.
- **Network Requirement**: A stable internet connection is needed to fetch weather data and updates.

## License

MIT License
