Here's a comprehensive prompt for Claude to recreate your iOS app in Swift:

---

**Create a native iOS app in Swift with 3 screens matching the attached screenshots exactly. This is a HealthKit metrics monitoring app that syncs data to either InfluxDB or Prometheus Pushgateway.**

## **App Overview**

- **Purpose**: Monitor HealthKit metrics sync status to time-series databases
- **Architecture**: 3-screen navigation flow (Status → Configuration → Logs)
- **Design**: Ultra-minimal, technical aesthetic with deep blue background


## **Visual Specifications**

### **Colors**

- **Primary Background**: `#0804ac` (deep blue) - use throughout all screens
- **Primary Text**: White (`#FFFFFF`)
- **Secondary Text**: Light blue (`#93C5FD` or similar blue-300)
- **Accent Color**: Yellow (`#FDE047` - yellow-300)
- **Success Indicators**: Emerald (`#6EE7B7` - emerald-300)
- **Error Indicators**: Rose (`#FDA4AF` - rose-300)
- **Placeholder Text**: Blue-300 tint


### **Typography**

- **Font Family**: SF Mono (system monospace font)
- **Tracking**: Wide letter spacing (similar to CSS `tracking-wide`)
- **Sizes**:

- Headers: 18pt
- Body text: 14pt
- Small text: 12pt
- Timestamps: 10pt





### **Spacing & Layout**

- **Screen Padding**: 24pt all sides
- **Element Spacing**: 24pt between major sections, 12pt between related items
- **Button Padding**: 16pt horizontal, 8pt vertical
- **Input Height**: 44pt minimum (iOS standard)
- **Dot Size**: 12pt diameter
- **Central Circle**: 64pt diameter, white with 80% opacity
- **Outer Circle**: 256pt diameter, blue border with 40% opacity


## **Screen 1: Status Screen**

### **Layout**

- **Top Section**: Centered status text and metrics count
- **Middle**: Large circular visualization (256pt diameter)
- **Bottom**: Clickable log indicators (left) + Configure button (right)


### **Elements**

- **Status Text**: "you have synced" or "connection status"
- **Metrics Display**: "[number] metrics in 24 hours" with yellow highlights
- **Last Sync**: Small timestamp "last sync: 30 seconds ago"
- **Central Visualization**:

- Outer circle with blue border (40% opacity)
- 8 dots positioned around circle (yellow filled = good, blue hollow = needs attention)
- Central white circle (80% opacity)



- **Log Indicators**:

- Emerald dot + count (info logs)
- Rose dot + count (error logs)
- Clickable area to navigate to logs screen



- **Configure Button**: Yellow background, blue text, rounded corners


## **Screen 2: Configuration Screen**

### **Layout**

- **Header**: Back button + "configuration" title
- **Data Source Toggle**: InfluxDB/Prometheus buttons
- **Form Fields**: Conditional based on selected source
- **Bottom**: Test connection + Save button


### **InfluxDB Fields**

- Server URL (placeholder: "[https://your-influxdb.com:8086](https://your-influxdb.com:8086)")
- API Token (password field with show/hide toggle)
- Organization (placeholder: "your-org")
- Bucket (placeholder: "metrics-bucket")


### **Prometheus Fields**

- Gateway URL (placeholder: "[http://pushgateway:9091](http://pushgateway:9091)")
- Username (optional, placeholder: "basic auth username")
- Password (optional, password field with show/hide toggle)


### **Shared Elements**

- **Push Interval Slider**: 1-60 minutes with yellow thumb
- **Test Connection Button**: Transparent with white text
- **Connection Status**: Green checkmark + "connection successful" or red X + "connection failed"
- **Save Button**: Yellow background, disabled until connection test passes


### **Input Styling**

- **Background**: Transparent
- **Border**: None
- **Text Color**: White
- **Placeholder**: Blue-300 tint
- **Font**: SF Mono


## **Screen 3: Logs Screen**

### **Layout**

- **Header**: Back button + "logs" title
- **Info Logs Section**: Emerald dot + "info logs" header + log entries
- **Error Logs Section**: Rose dot + "error logs" header + log entries
- **Bottom**: Log count summary + "last 24h" indicator


### **Log Entry Format**

- **Timestamp**: Small blue text (e.g., "14:32:15")
- **Message**: White text for info, rose text for errors
- **Spacing**: 12pt between entries, 4pt between timestamp and message


### **Sample Log Messages**

**Info Logs:**

- "healthkit data synced successfully"
- "steps data pushed to influxdb"
- "heart rate metrics uploaded"


**Error Logs:**

- "connection timeout to influxdb"
- "failed to authenticate api token"
