# Matrix Health Monitoring Stack

This directory contains the Docker Compose setup for the Prometheus monitoring stack used with the Matrix iOS health app.

## Components

- **Prometheus** (port 9090): Time-series database that scrapes metrics from Pushgateway
- **Pushgateway** (port 9091): Receives metrics pushed from the Matrix iOS app
- **Grafana** (port 3000): Visualization dashboard for health metrics

## Quick Start

1. **Start the monitoring stack**:
   ```bash
   cd monitoring
   docker-compose up -d
   ```

2. **Check services are running**:
   ```bash
   docker-compose ps
   ```

3. **Access the services**:
   - Prometheus: http://localhost:9090
   - Pushgateway: http://localhost:9091
   - Grafana: http://localhost:3000 (admin/admin)

4. **Configure Matrix iOS app**:
   - Use `http://YOUR_LOCAL_IP:9091` as Pushgateway URL
   - Find your IP: `ipconfig getifaddr en0`

## Configuration

### Prometheus
- Configuration: `prometheus.yml`
- Scrapes Pushgateway every 5 seconds
- Data retention: 200 hours
- Persistent storage in Docker volume

### Grafana
- Auto-configured Prometheus datasource
- Admin password: `admin` (change after first login)
- Persistent storage in Docker volume
- Dashboard provisioning enabled

### Pushgateway
- Receives metrics from Matrix iOS app
- No authentication (configure as needed)
- Metrics available at `/metrics` endpoint

## Health Metrics

The Matrix app pushes these metric types:

### Counter Metrics (Daily Totals)
- `healthkit_steps_total`
- `healthkit_distance_walking_running_meters_total`
- `healthkit_active_energy_burned_calories_total`
- `healthkit_sleep_minutes_total`
- `healthkit_workout_minutes_total`
- `healthkit_workout_calories_total`

### Gauge Metrics (Latest Values)
- `healthkit_heart_rate_bpm`
- `healthkit_body_weight_kg`
- `healthkit_body_mass_index`
- `healthkit_blood_pressure_systolic_mmhg`

All metrics include:
- `instance` label: Your device name
- `job` label: `my_health_data`
- `source` label: Data source device (iPhone, Apple Watch, etc.)

## Grafana Dashboard Examples

### Steps Dashboard
```promql
# Total steps today
healthkit_steps_total{job="my_health_data"}

# Steps per hour rate
rate(healthkit_steps_total{job="my_health_data"}[1h]) * 3600
```

### Heart Rate Dashboard
```promql
# Current heart rate
healthkit_heart_rate_bpm{job="my_health_data"}

# Heart rate by source
healthkit_heart_rate_bpm{job="my_health_data"} by (source)
```

### Activity Dashboard
```promql
# Daily calories burned
healthkit_active_energy_burned_calories_total{job="my_health_data"}

# Workout time by activity
sum by (activity) (healthkit_workout_minutes_total{job="my_health_data"})
```

## Troubleshooting

### No Data in Grafana
1. Check Pushgateway has metrics: http://localhost:9091
2. Check Prometheus targets: http://localhost:9090/targets
3. Verify Matrix app is pushing (check app logs)

### Matrix App Cannot Connect
1. Ensure Docker services are running: `docker-compose ps`
2. Use correct IP address in Matrix app configuration
3. Check firewall settings

### Container Issues
```bash
# View logs
docker-compose logs prometheus
docker-compose logs pushgateway
docker-compose logs grafana

# Restart services
docker-compose restart

# Reset everything
docker-compose down -v
docker-compose up -d
```

## Data Persistence

- Prometheus data: `prometheus_data` Docker volume
- Grafana data: `grafana_data` Docker volume
- Data survives container restarts
- To reset: `docker-compose down -v`

## Security Notes

- **No authentication** on Pushgateway (add if needed)
- **Default Grafana password** (change after setup)
- **HTTP only** (configure HTTPS for production)
- **Local network only** (configure firewall as needed)