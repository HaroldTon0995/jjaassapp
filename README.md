# JJAAS Water Refilling Station System

Multi-platform system architecture for water refilling station management, dispatch, and customer ordering.

## Repository Structure

```text
JJAASSAPP/
├── admin_panel/       # Desktop / Web Admin Portal (Flutter)
│   ├── lib/
│   │   ├── screens/admin/      # Admin Dashboard & Analytics
│   │   └── ...
│   └── pubspec.yaml
│
├── mobile_app/        # Android / iOS Mobile Application (Flutter)
│   ├── lib/
│   │   ├── screens/customer/   # Customer Ordering & Tracking
│   │   ├── screens/driver/     # Driver Delivery & GPS Tracking
│   │   └── ...
│   └── pubspec.yaml
│
├── supabase/          # Database & Backend Configurations
│   └── supabase_tracking.sql
│
└── JJAASS MANUSCRIPT.pdf  # Project Documentation & Capstone Manuscript
```

## Running the Applications

### Admin Panel (Desktop / Web)
```bash
cd admin_panel
flutter pub get
flutter run -d chrome     # Run as Web App
# or
flutter run -d windows    # Run as Desktop App
```

### Mobile App (Customer & Driver)
```bash
cd mobile_app
flutter pub get
flutter run               # Run on Android / iOS device or emulator
```
