# LastMinute - Because Deadlines Always Sneak Up 📚⏰

[![Flutter CI](https://github.com/aadishsamir123/lastminute/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/aadishsamir123/lastminute/actions/workflows/flutter-ci.yml)

A beautiful, feature-rich homework reminder app built with Flutter and Firebase, designed to help students stay on top of their assignments with style.

## Join the Closed Test

Want to try LastMinute on your Android device and help it get published on the Play Store faster? Follow these simple steps:

1. **Join the Google Group**
   - Visit <https://groups.google.com/g/asdev-testers>
   - Join the testing group

2. **Install from Play Store**
   - Open the Play Store URL on your Android device: <https://play.google.com/store/apps/details?id=com.aadishsamir.lastminute>
   - Tap "Install" to download the app
   - Launch and log in to the app.

## ✨ Features

### 🎯 Core Features

- **Homework Management** - Full CRUD operations for homework assignments
- **Smart Reminders** - Schedule multiple reminders for each assignment
- **Priority System** - Organize homework by urgency (Low, Medium, High, Urgent)
- **Subject Organization** - Categorize assignments by subject
- **Completion Tracking** - Mark homework as complete with timestamps

### 📅 Calendar & Scheduling

- **Interactive Calendar** - Beautiful table calendar view with homework markers
- **Due Date Visualization** - See all homework at a glance
- **Today/Tomorrow/Overdue** - Smart date formatting and categorization
- **Device Calendar Integration** - Sync homework to Android device calendar (Android only)

### 🧠 Study Mode

- **Focus Timer** - Pomodoro-style study sessions (15, 25, 45, 60, 90 minutes)
- **Real-time Countdown** - Live timer display with beautiful animations
- **Session Tracking** - Monitor study time and build habits
- **App Usage Stats** - Track study time (Android only)

### 🔐 Authentication & Data

- **Google Sign-In** - Seamless authentication with Credential Manager (Android) and web popup
- **Cloud Firestore** - Real-time data sync across devices
- **User Profiles** - Personal homework library per user
- **Statistics Dashboard** - Track total, completed, pending, and overdue assignments

### 🎨 Beautiful UI/UX

- **Material Design 3** - Modern, polished interface
- **Teal Theme** - Fresh, modern color scheme
- **Light & Dark Mode** - Automatic theme switching
- **Smooth Animations** - Predictive back gestures and page transitions
- **Adaptive Design** - Optimized for Android, web, iOS, and desktop

### 📱 Platform-Specific Features

- **Android**
  - Credential Manager for Google Sign-In
  - Local notifications with exact alarms
  - Device calendar integration
  - App usage statistics
  - Study mode app blocking support
- **Web**
  - Google Sign-In popup flow
  - Responsive design
  - All core features available

### 🔔 Smart Notifications

- **Scheduled Reminders** - Set multiple reminders per homework
- **Exact Alarm Support** - Reliable Android 12+ notifications
- **Time-based Alerts** - Get notified at the perfect time
- **Custom Notification Channels** - Organized notification management

### 🐙 GitHub Integration

- **Latest Commit Display** - See the most recent app changes
- **Developer Transparency** - Track app updates in real-time
- **Commit Details** - Author, message, timestamp, and link

## 🛠️ Tech Stack

- **Flutter** - Cross-platform UI framework
- **Firebase Auth** - Secure authentication
- **Cloud Firestore** - Real-time NoSQL database
- **Google Sign-In** - OAuth authentication
- **Flutter Local Notifications** - Push notifications
- **Table Calendar** - Beautiful calendar widget
- **Device Calendar** - Native calendar integration
- **App Usage** - Usage statistics tracking

## 📦 Dependencies

```yaml
# Core Firebase
firebase_core, firebase_auth, cloud_firestore

# Authentication
google_sign_in

# UI & Calendar
table_calendar, intl

# Notifications & Scheduling
flutter_local_notifications, timezone

# Platform-specific
device_calendar, app_usage

# Networking
http
```

## 🚀 Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/aadishsamir123/lastminute.git
   cd lastminute
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Ensure Firebase is set up for your project
   - Check `firebase_options.dart` for configuration

4. **Run the app**

   ```bash
   # Android
   flutter run

   # Web
   flutter run -d chrome

   # iOS (if configured)
   flutter run -d ios
   ```

## 📱 Screenshots & Features Showcase

### Home Screen

- Personalized greeting with user's name
- Statistics card showing homework progress
- Overdue and upcoming homework sections
- Beautiful card-based layout
- Pull-to-refresh support

### Homework Management

- Add/Edit homework with rich details
- Set due dates and times with date/time pickers
- Assign priority levels with segmented buttons
- Add multiple reminders per assignment
- Beautiful form validation and error handling

### Calendar View

- Monthly/Weekly/2-Week calendar formats
- Homework markers on calendar dates
- Select dates to view homework
- Today button for quick navigation
- Event count indicators

### Study Mode

- Large countdown timer display
- Preset time options (chips)
- Session complete celebrations
- App usage tracking dashboard
- Focus features explanation

### Profile

- User information display
- Latest GitHub commit card
- App information
- Sign-out functionality

## 🎨 Design Principles

- **Material Design 3** - Latest design system
- **Teal Color Scheme** - Fresh, modern, non-indigo
- **No Gradients** - Clean, flat design
- **Rounded Corners** - Soft, friendly appearance (20px cards, 16px buttons)
- **Consistent Spacing** - 8px grid system
- **Elevated Components** - Subtle shadows and surface tints
- **Adaptive Icons** - Platform-specific iconography

## 🔒 Permissions (Android)

- `POST_NOTIFICATIONS` - Send reminder notifications
- `SCHEDULE_EXACT_ALARM` - Schedule precise reminders
- `READ/WRITE_CALENDAR` - Device calendar integration
- `PACKAGE_USAGE_STATS` - Study time tracking
- `INTERNET` - Firebase and GitHub API access

## 📄 License

This is a school project - "Because Deadlines Always Sneak Up" 😄

## 👨‍💻 Developer

Built with ❤️ for students who need that extra reminder!

---

**LastMinute** - Stay organized, stay ahead! 🎓✨
