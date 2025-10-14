# Matrix - iOS Health Metrics Exporter

Matrix is an iOS app that exports health metrics from Apple HealthKit to Prometheus via Pushgateway, enabling you to visualize your personal health data in Grafana.

## Overview

This app runs silently in the background on your iPhone, collecting health and activity data from HealthKit and pushing it to a Prometheus Pushgateway. This push-based architecture eliminates the need for inbound connections to your iPhone, providing a secure way to export your health data for visualization and analysis.

## Architecture

```
iPhone (Matrix App) → Pushgateway → Prometheus → Grafana
```

- **Matrix App**: Collects HealthKit data and formats it as Prometheus metrics
- **Pushgateway**: Receives and temporarily stores metrics from the iPhone
- **Prometheus**: Scrapes metrics from Pushgateway and stores time-series data
- **Grafana**: Visualizes the health metrics with dashboards

## Features

### Core Features
- **Comprehensive HealthKit Integration**: Collects 60+ health metrics including:
  - Activity & Movement (steps, distance, flights climbed, exercise time, stand time)
  - Heart Metrics (heart rate, resting HR, walking HR, HRV)
  - Energy & Calories (active energy, basal energy)
  - Sleep Analysis
  - Body Measurements (weight, BMI, body fat %)
  - Vitals (blood oxygen, blood pressure, respiratory rate, body temperature)
  - Mobility Metrics (walking speed, step length, walking steadiness, stair speed)
  - Audio Exposure (environmental audio, headphone audio)
  - Workouts (15+ activity types)
  - Activity Rings (Move, Exercise, Stand)

- **Push Model Architecture**: Sends metrics to Prometheus Pushgateway or InfluxDB (no inbound connections required)
- **Background Operation**: Runs silently in the background with configurable push intervals
- **Secure Credential Storage**: Credentials stored in iOS Keychain

### New UI Features
- **Metrics Overview Screen**: Visual dashboard showing all your health metrics
  - Individual metric cards with values, units, and timestamps
  - Percentage change indicators (green/red)
  - Sparkline charts for each metric
  - Real-time sync status
  - Customizable metric selection

- **Metrics Configuration**: Choose which metrics to display
  - 60+ available metrics to select from
  - Select all / Deselect all option
  - Organized by category (quantity, category, workout, activity)
  - Visual checkboxes and sparklines

- **Babble AI Assistant**: Chat with your health data
  - Ask questions about your metrics
  - Get correlations and insights
  - 30-day historical data analysis
  - Powered by Claude AI

### Additional Features
- **Built-in Logging**: Debug logs viewable within the app
- **Status Notifications**: Periodic notifications about push status
- **InfluxDB Support**: Alternative to Prometheus for time-series storage

## Setup Instructions

### Prerequisites

1. **Docker Setup** (for Prometheus stack):
```bash
# Create docker-compose.yml with:
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
  
  pushgateway:
    image: prom/pushgateway:latest
    ports:
      - "9091:9091"
  
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

2. **Prometheus Configuration** (`prometheus.yml`):
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pushgateway'
    static_configs:
      - targets: ['pushgateway:9091']
    honor_labels: true
```

### iOS App Installation

1. **Open in Xcode**
   - Open `Matrix.xcodeproj` in Xcode
   - Update the Development Team in project settings
   - Ensure HealthKit capability is enabled

2. **Build and Install**
   - Connect your iPhone via USB
   - Select your device as the build target
   - Click Run (⌘R)
   - Trust the developer certificate on your iPhone if prompted

3. **Initial Configuration**
   - Tap "Authorize" button
   - Grant all requested HealthKit permissions
   - Tap "Configure" to access settings
   - Choose between Prometheus or InfluxDB
   - Enter your Pushgateway URL (e.g., `http://192.168.1.100:9091`) or InfluxDB credentials
   - Configure authentication if required
   - Select which metrics to track in Metrics Configuration

4. **Start Service**
   - After successful setup, the service will auto-start
   - The app will begin pushing metrics every 5 minutes (configurable)
   - Disconnect USB cable - the app continues running in background

5. **Using the App**
   - **Main Screen**: Shows connection status and sync information
   - **Metrics Overview**: Tap the center button to view all your health metrics
   - **Metrics Settings**: Tap the gear icon in metrics view to configure which metrics to display
   - **Babble Chat**: Tap "Babble" to chat with AI about your health data
   - **Configuration**: Tap "Configure" to change settings
   - **Logs**: Tap the log indicators to view system logs

### Grafana Setup

1. **Add Prometheus Data Source**:
   - URL: `http://prometheus:9090`
   - Access: Server (default)
   - Save & Test

2. **Import Dashboard** or create custom panels with queries like:
   ```promql
   healthkit_steps_total{job="my_health_data"}
   rate(healthkit_heart_rate_bpm{job="my_health_data"}[5m])
   increase(healthkit_active_energy_burned_calories_total{job="my_health_data"}[1d])
   ```

## Configuration

### App Settings
- **Push Interval**: Configurable from 1-60 minutes (default: 5 minutes)
- **Instance Name**: Automatically uses device name
- **Job Name**: Fixed as `my_health_data`

### Background Execution
The app uses iOS background capabilities:
- Background App Refresh
- HealthKit Background Delivery
- Background Processing Tasks

**Note**: iOS manages background execution based on usage patterns and battery optimization. Actual push intervals may vary.

## Metrics

See [METRICS.md](METRICS.md) for a complete list of health metrics exported by the app.

## Security Considerations

- **No Inbound Connections**: The app only makes outbound HTTPS/HTTP connections
- **Local Processing**: All health data processing happens on-device
- **Secure Storage**: Pushgateway credentials stored in iOS Keychain
- **Data in Transit**: Support for HTTPS connections to Pushgateway

## Troubleshooting

### Common Issues

1. **Metrics not appearing**:
   - Check in-app logs via the "Logs" button
   - Verify Pushgateway URL includes `http://` or `https://`
   - Ensure iPhone and Pushgateway are on same network
   - Check Prometheus targets page (http://localhost:9090/targets)

2. **Background execution issues**:
   - Ensure Background App Refresh is enabled in iOS Settings
   - Don't force-quit the app from app switcher
   - Check battery settings aren't restricting the app

3. **HealthKit permissions**:
   - Go to Settings → Privacy & Security → Health → Matrix
   - Ensure all desired health types are enabled

### Viewing Logs
- In-app: Tap "Logs" button on main screen
- Filter by log level (Info, Warning, Error)
- Auto-scroll toggle for real-time monitoring

## Privacy

This app is designed for personal use only. Your health data:
- Remains under your control
- Is only sent to your specified Pushgateway
- Is not stored persistently on the device (except by HealthKit itself)
- Is not sent to any third-party services

## Requirements

- iOS 16.0+
- iPhone only (iPad not supported)
- Active network connection
- Prometheus Pushgateway instance

## Development

Built with:
- Swift 5.0
- SwiftUI
- HealthKit
- iOS Background Tasks

## License

This project is for personal use. See LICENSE file for details.