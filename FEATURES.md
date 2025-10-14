# Matrix App Features Guide

## Overview

Matrix is a comprehensive health tracking iOS app that combines HealthKit data export with an intuitive UI for visualizing and managing your health metrics. This guide covers all the features available in the app.

---

## Main Features

### 1. Metrics Overview Screen

Access by tapping the **center button** on the main screen.

#### What It Shows
- **Individual Metric Cards**: Each metric displays in its own card with:
  - **Metric Name**: Clear label (e.g., "Steps", "Heart Rate")
  - **Current Value**: Live data from HealthKit with appropriate units
  - **Percentage Change**: Color-coded indicator showing improvement (green) or decline (red)
  - **Sparkline Chart**: Mini trend graph showing recent changes
  - **Last Update**: Time since last HealthKit sync

#### Summary Header
- **Today's Overview**: "X improving • Y tracked"
- **Last Sync Time**: Shows when data was last refreshed from HealthKit

#### Actions
- **Swipe Down**: Pull to dismiss
- **Gear Icon**: Opens Metrics Configuration
- **Back Arrow**: Return to main screen

#### Example Metrics Display
```
┌─────────────────────────────────────┐
│ • steps                      +15%   │
│ 12,847 steps                 ╱╲╱╲   │
│ 2m ago                              │
└─────────────────────────────────────┘
```

---

### 2. Metrics Configuration Screen

Access via **gear icon** in Metrics Overview screen.

#### Features

**Metric Selection**
- Browse 60+ available health metrics
- Visual checkboxes (yellow when selected, hollow when not)
- Each metric shows:
  - Name and category
  - Mini sparkline preview
  - Sample percentage change

**Bulk Actions**
- **Select All**: Enable all 60+ metrics at once
- **Deselect All**: Clear all selections
- Button text updates dynamically

**Selection Counter**
- "X of Y selected" displays current selection
- Updates in real-time as you toggle metrics

**Categories Include**
- Activity & Movement (6 metrics)
- Heart Metrics (4 metrics)
- Energy & Calories (2 metrics)
- Sleep (1 metric)
- Respiratory & Vitals (7 metrics)
- Body Measurements (5 metrics)
- Metabolic (1 metric)
- Mobility & Gait (9 metrics)
- Audio & Environment (3 metrics)
- Category Types (7 metrics)
- Workout Types (15+ metrics)
- Activity Summary (3 metrics)

**Settings Persistence**
- Selections are saved automatically
- Persist across app restarts
- Applied immediately when you return to Metrics Overview

#### Example Configuration Screen
```
┌─────────────────────────────────────┐
│ ← metric settings                   │
│                                     │
│ select metrics to display           │
│ 8 of 63 selected • select all       │
│                                     │
│ ☑ steps              ╱╲╱  +15%     │
│ ☑ heart rate         ╲╱╲   -4%     │
│ ☑ sleep              ╱╲╲   -2%     │
│ ☑ calories           ╱╲╱   +3%     │
│ ☐ blood oxygen       ╲╱╱    0%     │
│ ☐ vo2 max            ╱╲╲   +2%     │
│                                     │
│ ┌──────────────────────────────┐   │
│ │          Done                │   │
│ └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

### 3. Babble AI Chat Assistant

Access via **Babble button** on main screen.

#### Capabilities
- **Natural Language Queries**: Ask questions about your health data in plain English
- **30-Day Historical Analysis**: Access to your last 30 days of metrics
- **Correlation Detection**: Find relationships between different metrics
- **Trend Analysis**: Identify patterns in your health data
- **Personalized Insights**: Get suggestions based on your data

#### Example Questions
- "What's my average heart rate this week?"
- "Correlate my sleep and exercise patterns"
- "How can I improve my sleep quality?"
- "Analyze my exercise patterns over the last month"
- "When am I most active during the day?"

#### Chat Interface
- **Blue Background**: Distinctive Babble chat theme
- **Message Bubbles**: User messages (right, yellow tint) vs Assistant messages (left, white tint)
- **Quick Actions**: Pre-made question buttons for common queries
- **Real-time Processing**: Answers stream in as they're generated
- **Yellow Status Dot**: Indicates active Babble configuration

#### Backend Setup
- Requires backend URL configuration (Vercel/Cloud Run)
- Settings accessible via yellow status dot in chat
- Backend handles Claude AI API integration

---

### 4. Health Data Export

#### Prometheus/Pushgateway
- Exports metrics in Prometheus format
- Configurable push intervals (1-60 minutes)
- Basic authentication support
- Background delivery enabled for key metrics

#### InfluxDB
- Alternative to Prometheus
- Line protocol format
- Organization, bucket, and token configuration
- Same background operation capabilities

#### Configuration Options
- **Push Gateway URL** or **InfluxDB Endpoint**
- **Push Interval**: How often to sync (default 5 minutes)
- **Instance Name**: Device identifier (auto-populated)
- **Job Name**: Metric grouping label
- **Authentication**: HTTP Basic Auth or InfluxDB token

---

### 5. Main Screen

#### Status Display
- **Connection Status**: Connected / Disconnected / Not Configured
- **Metrics Count**: "X metrics in 24 hours"
- **Last Sync Time**: Time since last successful push

#### Interactive Sphere
- **3D Rotation**: Drag to spin
- **Status Dots**: 8 dots showing activity (fill based on metric count)
- **Central Button**: Tap to open Metrics Overview
- **Swipe Animation**: Momentum-based physics

#### Bottom Controls
- **Log Indicators**: Green (info) and Red (error) counts
  - Tap to open log viewer
- **Babble Button**: Opens AI chat interface
  - Disabled until HealthKit authorized
- **Configure/Authorize Button**:
  - "Authorize" - Grant HealthKit permissions
  - "Configure" - Adjust settings

---

### 6. Configuration Screen

#### Prometheus/InfluxDB Toggle
- Switch between data export backends
- Different settings for each option

#### Metrics Selection
- Choose which metrics to export
- Search and filter capabilities
- Category-based organization

#### InfluxDB Settings
- URL, Organization, Bucket
- Token stored in Keychain
- Connection test button

#### Prometheus Settings
- Pushgateway URL
- Basic Auth credentials (Keychain)
- Job and instance labels

---

### 7. Logging System

#### Log Viewer
- **Filter by Level**: Info, Warning, Error
- **Real-time Updates**: Auto-scroll toggle
- **Timestamp**: Precise timing for debugging
- **Export**: Share logs for troubleshooting

#### Log Categories
- HealthKit authorization
- Metric collection
- Network requests
- Background task execution
- Error tracking

---

## Tips & Best Practices

### Optimizing Metric Selection
- Start with default 8 metrics
- Add more as needed based on your tracking goals
- Use "Select All" to see everything, then narrow down
- Check sparklines to see which metrics have active data

### Using Babble Effectively
- Ask specific questions about timeframes
- Request correlations between 2-3 metrics
- Follow up questions work best for deeper insights
- Historical context helps with trend analysis

### Battery Optimization
- Reduce push interval if battery life is a concern
- Limit selected metrics in configuration
- iOS manages background execution automatically

### Data Accuracy
- Ensure Apple Watch is synced regularly
- Keep HealthKit permissions up to date
- Check "Last Sync" time in metrics overview
- Verify data sources in HealthKit app

---

## Keyboard Shortcuts & Gestures

### Main Screen
- **Drag Sphere**: Rotate with momentum
- **Tap Sphere**: Trigger spin animation
- **Tap Center**: Open Metrics Overview

### Metrics Overview
- **Swipe Down**: Dismiss screen
- **Tap Gear**: Open Configuration
- **Tap Metric Card**: (Future: Detailed view)

### Configuration
- **Tap Checkbox**: Toggle metric selection
- **Tap "Select All"**: Bulk toggle all metrics

---

## Troubleshooting

### Metrics Not Updating
1. Check HealthKit permissions (Settings → Health → Matrix)
2. Force sync from Metrics Overview (refresh icon)
3. Verify data exists in Health app
4. Check logs for error messages

### Babble Not Responding
1. Verify backend URL in Babble settings
2. Check internet connection
3. Ensure backend is deployed and running
4. Review logs for API errors

### Export Issues
1. Test connection in Configuration
2. Verify URL format (http:// or https://)
3. Check authentication credentials
4. Ensure Pushgateway/InfluxDB is accessible

---

## Privacy & Security

- **Local Processing**: All data analysis happens on-device
- **Keychain Storage**: Credentials encrypted in iOS Keychain
- **No Cloud Storage**: Health data never stored on remote servers
- **Export Control**: You choose what data to export and where
- **HealthKit Permissions**: Granular control over which data types to access

---

## Future Features

Potential upcoming additions:
- Detailed metric drill-down views
- Custom metric groupings
- Export scheduling
- Historical data charts
- Health goal tracking
- Metric correlations visualization
- Apple Watch companion app
