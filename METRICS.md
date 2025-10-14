# Matrix Health Metrics Reference

This document lists all 60+ health metrics available in the Matrix app from Apple HealthKit. You can view these metrics in the app's Metrics Overview screen and configure which ones to display using the Metrics Settings.

## Metric Format

All metrics follow the pattern:
```
healthkit_<metric_name>{instance="<device_name>", job="my_health_data", ...labels}
```

## Counter Metrics (Cumulative Totals)

These metrics represent cumulative values that only increase. They reset daily at midnight.

### Activity Metrics

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_steps_total` | Total number of steps taken today | count | `instance` |
| `healthkit_distance_walking_running_meters_total` | Total distance walked or run today | meters | `instance` |
| `healthkit_active_energy_burned_calories_total` | Total active calories burned today (from movement) | kilocalories | `instance` |
| `healthkit_basal_energy_burned_calories_total` | Total resting/basal calories burned today | kilocalories | `instance` |

### Sleep Metrics

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_sleep_minutes_total` | Total minutes of sleep recorded today | minutes | `instance` |

### Workout Metrics

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_workout_minutes_total` | Total workout duration by activity type | minutes | `instance`, `activity`* |
| `healthkit_workout_calories_total` | Total calories burned during workouts by activity type | kilocalories | `instance`, `activity`* |

*Activity labels include: `running`, `walking`, `cycling`, `swimming`, `yoga`, `strength_training`, `hiit`, `other`

## Gauge Metrics (Point-in-Time Values)

These metrics represent the most recent measurement and can go up or down.

### Vital Signs

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_heart_rate_bpm` | Most recent heart rate measurement | beats/minute | `instance`, `source`** |
| `healthkit_resting_heart_rate_bpm` | Most recent resting heart rate | beats/minute | `instance`, `source`** |
| `healthkit_oxygen_saturation_percent` | Most recent blood oxygen level | percentage | `instance`, `source`** |
| `healthkit_blood_pressure_systolic_mmhg` | Most recent systolic blood pressure | mmHg | `instance`, `source`** |
| `healthkit_blood_pressure_diastolic_mmhg` | Most recent diastolic blood pressure | mmHg | `instance`, `source`** |

### Body Measurements

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_body_weight_kg` | Most recent body weight | kilograms | `instance`, `source`** |
| `healthkit_body_mass_index` | Most recent BMI calculation | index | `instance`, `source`** |
| `healthkit_body_fat_percent` | Most recent body fat percentage | percentage | `instance`, `source`** |

### Other Health Metrics

| Metric Name | Description | Unit | Labels |
|------------|-------------|------|--------|
| `healthkit_blood_glucose_mg_dl` | Most recent blood glucose level | mg/dL | `instance`, `source`** |

**Source labels indicate the device that recorded the measurement (e.g., `iPhone`, `Apple Watch`, or third-party app names)

## Example Prometheus Queries

### Daily Totals
```promql
# Total steps today
healthkit_steps_total{job="my_health_data"}

# Total active calories burned today
healthkit_active_energy_burned_calories_total{job="my_health_data"}

# Total workout minutes by activity
sum by (activity) (healthkit_workout_minutes_total{job="my_health_data"})
```

### Rate Calculations
```promql
# Steps per minute (5-minute average)
rate(healthkit_steps_total{job="my_health_data"}[5m]) * 60

# Calories burned per hour
rate(healthkit_active_energy_burned_calories_total{job="my_health_data"}[1h]) * 3600
```

### Time-Based Aggregations
```promql
# Daily step increase
increase(healthkit_steps_total{job="my_health_data"}[1d])

# Average heart rate over last hour
avg_over_time(healthkit_heart_rate_bpm{job="my_health_data"}[1h])
```

### Comparisons
```promql
# Heart rate from different sources
healthkit_heart_rate_bpm{job="my_health_data"} by (source)

# Workout calories by activity type
healthkit_workout_calories_total{job="my_health_data"} by (activity)
```

## Data Collection Notes

1. **Update Frequency**: Metrics are pushed approximately every 5 minutes (configurable)
2. **Historical Data**: Only current or daily cumulative values are exported, not full history
3. **Data Availability**: Depends on what data is recorded in HealthKit by your devices
4. **Time Zone**: All daily resets occur at midnight in the device's local time zone

## Grafana Dashboard Tips

### Recommended Visualizations

1. **Steps/Distance**: Time series graph with daily annotations
2. **Heart Rate**: Gauge with min/max thresholds
3. **Calories**: Stacked bar chart (active vs basal)
4. **Workouts**: Pie chart by activity type
5. **Body Metrics**: Stat panels with sparklines

### Useful Transformations

- Use `increase()` for daily totals from counter metrics
- Use `rate()` for per-minute or per-hour calculations
- Use `avg_over_time()` for averaging gauge metrics
- Group by `activity` label for workout breakdowns
- Group by `source` label to compare devices

## All Available Metrics

### Activity & Movement (6 metrics)
- **Steps** - Total steps taken
- **Walking/Running Distance** - Distance covered walking or running
- **Cycling Distance** - Distance covered cycling
- **Flights Climbed** - Number of flights of stairs climbed
- **Exercise Time** - Active exercise minutes (Apple Watch Exercise Ring)
- **Stand Time** - Active standing minutes (Apple Watch Stand Ring)

### Heart Metrics (4 metrics)
- **Heart Rate** - Current heart rate
- **Resting Heart Rate** - Resting heart rate
- **Walking Heart Rate** - Average heart rate during walking
- **Heart Rate Variability (HRV)** - Heart rate variability measurement

### Energy & Calories (2 metrics)
- **Active Energy** - Calories burned through activity
- **Basal Energy** - Resting metabolic rate calories

### Sleep (1 metric)
- **Sleep Analysis** - Total sleep duration

### Respiratory & Vitals (7 metrics)
- **Respiratory Rate** - Breaths per minute
- **Blood Oxygen** - Oxygen saturation percentage
- **Body Temperature** - Body temperature
- **Blood Pressure (Systolic)** - Systolic blood pressure
- **Blood Pressure (Diastolic)** - Diastolic blood pressure
- **Blood Glucose** - Blood glucose levels

### Body Measurements (5 metrics)
- **Body Mass** - Body weight
- **Body Mass Index (BMI)** - BMI calculation
- **Body Fat %** - Body fat percentage
- **Height** - Height measurement
- **Waist Circumference** - Waist circumference

### Metabolic (1 metric)
- **VO2 Max** - Maximum oxygen consumption

### Mobility & Gait (9 metrics)
- **Walking Speed** - Average walking speed
- **Walking Step Length** - Step length during walking
- **Walking Double Support %** - Percentage of time both feet on ground
- **Walking Asymmetry %** - Gait asymmetry percentage
- **Walking Steadiness** - Walking stability score
- **Stair Ascent Speed** - Speed climbing stairs
- **Stair Descent Speed** - Speed descending stairs
- **Six-Minute Walk Distance** - Distance covered in 6-minute walk test
- **Physical Effort** - Physical effort rating (iOS 17+)

### Audio & Environment (3 metrics)
- **Environmental Audio Exposure** - Ambient sound exposure
- **Headphone Audio Exposure** - Headphone volume exposure
- **Environmental Sound Reduction** - Active noise reduction

### Category Types (7 metrics)
- **Stand Hour** - Stand hour events
- **Mindful Session** - Mindfulness minutes
- **High Heart Rate Event** - High heart rate alerts
- **Low Heart Rate Event** - Low heart rate alerts
- **Irregular Heart Rhythm** - Irregular rhythm notifications
- **Toothbrushing** - Toothbrushing events
- **Audio Exposure Events** - Audio exposure limit events

### Workout Types (15+ metrics)
- **Walking Workout** - Walking workout sessions
- **Running Workout** - Running workout sessions
- **Cycling Workout** - Cycling workout sessions
- **Swimming Workout** - Swimming workout sessions
- **Strength Training** - Traditional strength training
- **Functional Training** - Functional strength training
- **HIIT Workout** - High-intensity interval training
- **Yoga** - Yoga sessions
- **Core Training** - Core workout sessions
- **Flexibility** - Flexibility/stretching sessions
- **Cooldown** - Cooldown sessions
- **Elliptical** - Elliptical machine workouts
- **Rowing** - Rowing machine workouts
- **Stair Climbing** - Stair stepper workouts
- **Other Workouts** - Other activity types

### Activity Summary (3 metrics)
- **Move Ring Progress** - Daily move goal progress
- **Exercise Ring Progress** - Daily exercise goal progress
- **Stand Ring Progress** - Daily stand goal progress

## Metrics Overview Screen

The app includes a visual metrics dashboard accessible by tapping the center button on the main screen:

- **Individual Metric Cards**: Each metric displays:
  - Current value with unit
  - Percentage change indicator (green for improvement, red for decrease)
  - Mini sparkline chart showing trend
  - Time since last update

- **Summary Statistics**: Shows count of improving vs tracked metrics
- **Real-time Sync**: Displays last sync time with HealthKit
- **Customization**: Tap gear icon to configure which metrics to display

## Metrics Configuration

Access via gear icon in Metrics Overview screen:

- **Select Metrics**: Choose from 60+ available metrics
- **Select All / Deselect All**: Bulk selection options
- **Visual Preview**: See sparklines and percentage changes for each metric
- **Organized Categories**: Metrics grouped by type for easy navigation
- **Persistent Settings**: Selections saved between app launches

## Using Babble AI Assistant

Ask natural language questions about your health data:
- "What's my average heart rate this week?"
- "Correlate my sleep and exercise"
- "How can I improve my sleep?"
- "Analyze my exercise patterns"

Babble has access to 30 days of historical data and can identify trends, correlations, and provide insights.