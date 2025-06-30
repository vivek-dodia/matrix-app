# Matrix Health Metrics Reference

This document lists all health metrics currently exported by the Matrix app from Apple HealthKit to Prometheus.

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

## Future Metrics

The following HealthKit data types are available but not yet implemented:
- Heart Rate Variability (HRV)
- Respiratory Rate
- Body Temperature
- Flights Climbed
- Mindfulness Minutes
- Stand Hours
- Exercise Minutes
- Nutrition Data
- Water Intake

These can be added by extending the HealthKitManager class.