# ElevateAI — AI-Powered Student Success Operating System

ElevateAI is a comprehensive platform designed to empower students through AI-driven insights, community collaboration, and smart campus resource management. It integrates academic data, behavioral DNA, and real-time campus context to provide a personalized success roadmap for every student.

## 🚀 Key Features

### 1. Smart Study Buddy Discovery
- **Live Campus Map**: Find students studying nearby in real-time.
- **Subject Filters**: Filter by subjects like DSA, Java, AI/ML, and more.
- **Instant Connect**: Message potential study partners or invite them to your project team directly from the map.

### 2. Context-Aware Smart Nudges
- **Proactive Guidance**: Intelligent recommendations based on your Student DNA and TrustScore.
- **Deadline Alerts**: Get priority reminders for scholarships and hackathons.
- **Skill Gap Analysis**: Proactive nudges to learn skills required for your target career paths.

### 3. Student DNA & TrustScore
- **Digital Twin**: A behavioral and academic profile that evolves with your activity.
- **TrustScore**: A reliability metric based on peer reviews, task completion, and academic integrity.
- **Career Predictor**: AI-driven career path recommendations based on your current skill set.

### 4. Campus OS & Digital Twin
- **Live Map**: Procedural visualization of campus resources and student activity.
- **Resource Booking**: Seamlessly book library seats, labs, or cafeteria meals.
- **ERP Integration**: Real-time sync with college academic records (Attendance, CGPA, Assignments).

### 5. Team Finder & Opportunity Engine
- **AI Matching**: Find the perfect teammates for hackathons based on skill overlap and TrustScore.
- **ScamShield**: Community-powered intelligence to flag fraudulent opportunities.
- **Portfolio Generator**: Automatically generate a verified digital portfolio based on your verified achievements.

## 📂 Project Structure

```
elevate/
├── elevate ai (1)/             # Main Flutter Application
│   └── elevateai/
│       ├── lib/                # Source code
│       ├── supabase/           # Edge Functions and DB logic
│       └── migrations/         # SQL database schemas
├── elevate community (1)/      # Community models and shared resources
└── README.md                   # Project documentation
```

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Edge Functions, Auth, Realtime)
- **Notifications**: Firebase Cloud Messaging
- **PDF Generation**: Printing & PDF packages
- **Navigation**: Go Router

## ⚙️ Setup Instructions

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/shekhark0309-cloud/ElevateAI.git
    ```
2.  **Install Dependencies**:
    Navigate to `elevate ai (1)/elevateai` and run:
    ```bash
    flutter pub get
    ```
3.  **Supabase Setup**:
    - Ensure your `lib/config/app_config.dart` has the correct Supabase URL and Anon Key.
    - Apply the migrations found in the `migrations/` folder to your Supabase instance.
4.  **Run the App**:
    ```bash
    flutter run
    ```

---

*Elevate your student life with AI.*
