# 🔗 Reschedule

### *Real-Time Resource & Peer Optimizer*

**Reschedule** is a high-performance, real-time networking ecosystem designed to bridge the gap between "idle time" and "active collaboration." Built for the modern campus, it uses machine learning to instantly match students based on their immediate availability, academic interests, and physical location.

---

## 📡 The Problem & Vision

**The Gap:** Unexpected class cancellations or gaps in timetables lead to wasted productivity. Most students struggle to coordinate spontaneous study sessions or find available campus resources manually.

**The Solution:** A frictionless platform that treats time and knowledge as exchangeable assets. One click signals your availability; the ML engine does the rest.

---

## 🚀 Key Features

* **The "I'm Free" Trigger**: Instant availability broadcasting across the campus network.
* **ML-Driven Matchmaking**: Uses a **K-Nearest Neighbors (KNN)** algorithm to calculate "Interest Distance," ensuring you are paired with the most relevant peers.
* **Live Resource Mapping**: Real-time suggestions for meeting spots like empty library slots or open labs.
* **Prism UI**: A high-contrast, dark-mode interface designed for maximum visibility and ease of use during high-pressure hackathons.

---

## 🛠️ Technical Architecture

| Layer | Technology | Purpose |
| --- | --- | --- |
| **Frontend** | Streamlit | Real-time interactive dashboard & UI |
| **Logic** | Python / NumPy | Data processing & availability matrices |
| **Intelligence** | Scikit-Learn | KNN-based peer recommendation engine |
| **Database** | Google Sheets API | Cloud-synced student database |
| **Design** | Figma | UI/UX Prototyping |

---

## 📈 Impact

* **Student Productivity**: Reclaims "lost" hours and reduces the friction of finding project partners.
* **Cross-Disciplinary Growth**: Connects students from different branches (e.g., CS and Mechanical) based on shared project goals.
* **Campus Efficiency**: Provides administration with heatmaps of student "free time" to better optimize facility usage and class schedules.

---

## 💻 Installation & Setup

1. **Clone the repository:**
```bash
git clone https://github.com/your-username/Reschedule-sync-space.git

```


2. **Install dependencies:**
```bash
pip install streamlit streamlit-gsheets pandas numpy scikit-learn

```


3. **Configure Secrets:**
Set up your `.streamlit/secrets.toml` with your Google Sheets connection details.
4. **Run the App:**
```bash
streamlit run main.py

```



---

## 👥 Team: Sync Squad

* **Priyanshu** (2025KUCP1009)
* **Shivang** (2025KUCP1006)
* **Ishant** (2025KUAD3005)
* **Rituraj** (2025KUAD3002)

---

*Built for the IIIT Kota Hackathon Ecosystem.*
