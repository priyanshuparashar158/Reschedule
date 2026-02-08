import os
from dotenv import load_dotenv
import streamlit as st
import pandas as pd
import requests
import json
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import MultiLabelBinarizer

# Load environment variables
load_dotenv()

# --- CONFIGURATION ---
FIREBASE_URL = os.getenv("FIREBASE_URL")
if not FIREBASE_URL:
    st.error("FIREBASE_URL environment variable not set. Please check your .env file.")
    st.stop()

# --- TIMETABLE DATA (SECTION A) ---
#  Lecture Schedule
LECTURES = {
    "Monday":    ["AIT102 (AI)", "MAT102 (Math)", "ECT102-T (Elec)", "CST102 (DSA)"],
    "Tuesday":   ["FREE",        "ECT102 (Elec)", "MAT102 (Math)",   "FREE"],
    "Wednesday": ["CST102 (DSA)", "ECT102 (Elec)", "CST102 (DSA)",   "FREE"],
    "Thursday":  ["MAT102 (Math)", "AIT102 (AI)",   "MMT102 (Mgmt)",  "FREE"],
    "Friday":    ["FREE",        "FREE",          "FREE",            "FREE"]
}

#  Lab Schedule by Batch (Afternoon Slots)
LABS = {
    "A1": {"Monday": "CSP112 (Python) - Lab 124", "Thursday": "AIP102 (Data Eng) - Lab 123", "Friday": "CSP102 (DSA) - Lab 138"},
    "A2": {"Monday": "CSP102 (DSA) - Lab 138", "Thursday": "ECP102 (Elec) - Lab 236", "Friday": "CSP112 (Python) - Lab 124"},
    "A3": {"Monday": "HSP102 (Writing) - Lab 305", "Wednesday": "AIP102 (Data Eng) - Lab 123", "Thursday": "CSP112 (Python) - Lab 124", "Friday": "CSP102 (DSA) - Lab 138"},
    "A4": {"Wednesday": "HSP102/ECP102", "Thursday": "CSP102 (DSA) - Lab 138", "Friday": "CSP112 (Python) - Lab 32"}
}

# 1. ARCHITECTURAL CONFIG
st.set_page_config(
    page_title="Reschedule // Resource Protocol", 
    page_icon="📅", 
    layout="wide"
)

# 2. HIGH-END CYBER-GRID CSS
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=Outfit:wght@300;600;900&display=swap');
    
    .stApp {
        background: radial-gradient(circle at 10% 10%, #10141d 0%, #07090e 100%);
        font-family: 'Outfit', sans-serif;
        color: #e6edf3;
    }

    .hud-header {
        background: linear-gradient(90deg, #00f2fe 0%, #bc8cff 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        font-weight: 900;
        letter-spacing: -2px;
        text-transform: uppercase;
    }

    .node-card {
        background: rgba(255, 255, 255, 0.03);
        border: 1px solid rgba(0, 242, 254, 0.2);
        border-radius: 16px;
        padding: 24px;
        margin-bottom: 20px;
        transition: all 0.4s ease;
        backdrop-filter: blur(10px);
    }
    
    .node-card:hover {
        border-color: #00f2fe;
        box-shadow: 0 0 25px rgba(0, 242, 254, 0.15);
        transform: translateY(-5px);
    }

    .schedule-card {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid rgba(255, 255, 255, 0.1);
        padding: 15px;
        border-radius: 12px;
        margin-bottom: 10px;
        text-align: center;
    }
    
    .slot-free {
        border-color: #00ff9d;
        color: #00ff9d;
        background: rgba(0, 255, 157, 0.05);
    }

    .slot-lab {
        border-color: #ffb86c;
        color: #ffb86c;
        background: rgba(255, 184, 108, 0.05);
    }

    .badge {
        background: rgba(188, 140, 255, 0.1);
        color: #bc8cff;
        padding: 4px 12px;
        border-radius: 20px;
        font-size: 0.75rem;
        font-family: 'JetBrains Mono', monospace;
        border: 1px solid rgba(188, 140, 255, 0.3);
        margin-right: 5px;
    }

    .stButton > button {
        background: transparent !important;
        color: #00f2fe !important;
        border: 1px solid #00f2fe !important;
        padding: 10px 20px !important;
        border-radius: 8px !important;
        font-family: 'JetBrains Mono' !important;
        font-weight: 700 !important;
        letter-spacing: 1px;
        transition: 0.3s;
        width: 100%;
    }
    </style>
    """, unsafe_allow_html=True)

# 3. DATABASE HELPER FUNCTIONS
def get_all_users():
    try:
        response = requests.get(f"{FIREBASE_URL}.json")
        data = response.json()
        if data:
            users_list = list(data.values())
            df = pd.DataFrame(users_list)
            return df
        else:
            return pd.DataFrame(columns=["student_id", "name", "interests", "is_active", "batch"])
    except Exception as e:
        st.error(f"Connection Error: {e}")
        return pd.DataFrame()

def upsert_user(student_id, name, interests, is_active, batch):
    user_data = {
        "student_id": str(student_id),
        "name": name,
        "interests": interests,
        "is_active": str(is_active).upper(),
        "batch": batch
    }
    requests.put(f"{FIREBASE_URL}/{student_id}.json", json=user_data)

def update_status(student_id, is_active):
    requests.patch(f"{FIREBASE_URL}/{student_id}.json", json={"is_active": str(is_active).upper()})


if 'page' not in st.session_state: st.session_state.page = 'gate'

# --- PAGE 1: THE GATEWAY ---
if st.session_state.page == 'gate':
    st.markdown("<br><br><br>", unsafe_allow_html=True)
    c1, c2, c3 = st.columns([1, 2, 1])
    with c2:
        # UPDATED TITLE HERE
        st.markdown("<h1 class='hud-header' style='font-size: 5rem; text-align: center; margin-bottom:0;'>Reschedule</h1>", unsafe_allow_html=True)
        st.markdown("<p style='text-align: center; color: #8b949e; letter-spacing: 4px;'>NETWORK ACCESS PROTOCOL</p>", unsafe_allow_html=True)
        st.write("---")
        if st.button("INITIALIZE SYSTEM"):
            st.session_state.page = 'hub'
            st.rerun()

# --- PAGE 2: THE HUB ---
elif st.session_state.page == 'hub':
    # --- AUTHENTICATION BLOCK ---
    if 'user' not in st.session_state:
        c1, c2, c3 = st.columns([1, 1.5, 1])
        with c2:
            with st.form("auth"):
                st.markdown("<h2 style='text-align: center;'>USER UPLINK</h2>", unsafe_allow_html=True)
                sid = st.text_input("UNIVERSITY ID", placeholder="Roll Number")
                nick = st.text_input("ALIAS", placeholder="Choose a display name")
                batch = st.selectbox("BATCH (SECTION A)", ["A1", "A2", "A3", "A4"])
                interests = st.multiselect(
                    "CORE EXPERTISE", 
                    ["Python", "ML", "DSA", "Math", "Web Dev", "Cybersec", "AI", "Blockchain", "Design"],
                    default=["Python"]
                )
                
                if st.form_submit_button("ESTABLISH CONNECTION"):
                    try:
                        sid_str = str(sid).strip()
                        interest_str = ", ".join(interests)
                        
                        if sid_str and nick:
                            upsert_user(sid_str, nick, interest_str, "TRUE", batch)
                            st.session_state.user = {"id": sid_str, "name": nick, "batch": batch}
                            st.rerun()
                        else:
                            st.warning("CREDENTIALS REQUIRED")
                    except Exception as e:
                        st.error(f"Write Error: {e}")
        st.stop()

    # --- MAIN INTERFACE BLOCK ---
    user = st.session_state.user
    
    # NAVIGATION
    nav_c1, nav_c2, nav_c3 = st.columns([1, 2, 1])
    with nav_c2:
        st.markdown(f"<h3 style='text-align:center;'>OPERATOR: <span style='color:#bc8cff;'>{user['name'].upper()}</span> | BATCH: {user['batch']}</h3>", unsafe_allow_html=True)
        
    tab1, tab2 = st.tabs(["🤝 PEER NETWORK", "📅 SCHEDULE"])

    # --- TAB 1: PEER NETWORK ---
    with tab1:
        if st.button("🔄 SYNCHRONIZE ACTIVE NODES"):
            st.cache_data.clear()
            st.rerun()

        try:
            all_data = get_all_users()
            
            if not all_data.empty:
                all_data.columns = all_data.columns.str.strip().str.lower()
                all_data['is_active'] = all_data['is_active'].astype(str).str.strip().str.upper()
                active_df = all_data[all_data['is_active'] == "TRUE"].copy().reset_index(drop=True)

                if len(active_df) < 2:
                     st.info("🔍 SCANNING... No other active nodes detected.")
                else:
                    active_df['interests_clean'] = active_df['interests'].astype(str).str.lower().apply(
                        lambda x: [i.strip() for i in x.split(',') if i.strip()]
                    )
                    mlb = MultiLabelBinarizer()
                    feature_matrix = mlb.fit_transform(active_df['interests_clean'])
                    
                    n_neighbors = min(len(active_df), 5) 
                    knn = NearestNeighbors(n_neighbors=n_neighbors, metric='jaccard', algorithm='brute')
                    knn.fit(feature_matrix)

                    user_matches = active_df[active_df['student_id'].astype(str) == str(user['id'])]
                    
                    if not user_matches.empty:
                        curr_user_idx = user_matches.index[0]
                        distances, indices = knn.kneighbors([feature_matrix[curr_user_idx]])

                        st.markdown(f"### RECOMMENDED PEER NODES")
                        cols = st.columns(3)
                        count = 0
                        
                        for i, neighbor_idx in enumerate(indices[0]):
                            if neighbor_idx == curr_user_idx: continue
                            
                            peer_row = active_df.iloc[neighbor_idx]
                            dist = distances[0][i]
                            match_score = int((1 - dist) * 100)
                            
                            display_tags = [t.upper() for t in peer_row['interests_clean']]
                            badges_html = "".join([f"<span class='badge'>{x}</span>" for x in display_tags])
                            
                            with cols[count % 3]:
                                st.markdown(f"""
                                    <div class='node-card'>
                                        <div style='display: flex; justify-content: space-between;'>
                                            <b style='color:#00f2fe; font-size:1.4rem;'>{peer_row['name']}</b>
                                            <span style='color: #bc8cff; font-weight:bold;'>{match_score}% MATCH</span>
                                        </div>
                                        <p style='color:#8b949e; font-size:0.8rem; margin:10px 0;'>ID: {peer_row['student_id']}</p>
                                        <div style='margin-bottom:20px;'>{badges_html}</div>
                                    </div>
                                """, unsafe_allow_html=True)
                                
                                if st.button(f"LINK WITH {peer_row['name'].upper()}", key=f"btn_{peer_row['student_id']}"):
                                    st.session_state.linked_peer = peer_row['name']
                                    st.session_state.page = 'success'
                                    st.rerun()
                            count += 1
                    else:
                        st.warning("User data desynchronized. Please re-login.")
            else:
                st.info("System Empty. Waiting for nodes...")
                    
        except Exception as e:
            st.error(f"System Error: {e}")

    # --- TAB 2: SCHEDULE (TIMETABLE) ---
    with tab2:
        st.markdown("### 🗓️ WEEKLY PROTOCOL (SECTION A)")
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        
        # User's Lab Schedule
        my_labs = LABS.get(user['batch'], {})

        # Create 5 columns for M-F
        cols = st.columns(5)
        
        for idx, day in enumerate(days):
            with cols[idx]:
                st.markdown(f"<div style='text-align:center; margin-bottom:10px; font-weight:bold; color:#bc8cff;'>{day.upper()}</div>", unsafe_allow_html=True)
                
                # 1. MORNING SLOTS (9-1)
                daily_lectures = LECTURES[day]
                times = ["09:00", "10:00", "11:00", "12:00"]
                
                for time, subject in zip(times, daily_lectures):
                    # Style logic
                    if subject == "FREE":
                        style_class = "slot-free"
                        content = "🟢 FREE SLOT"
                    else:
                        style_class = "schedule-card"
                        content = subject
                        
                    st.markdown(f"""
                        <div class='schedule-card {style_class}'>
                            <span style='font-size:0.7rem; color:#8b949e;'>{time}</span><br>
                            {content}
                        </div>
                    """, unsafe_allow_html=True)

                # 2. LUNCH
                st.markdown("<div style='text-align:center; color:#8b949e; font-size:0.8rem; margin: 10px 0;'>--- LUNCH (13:00) ---</div>", unsafe_allow_html=True)

                # 3. LABS (2-5 PM)
                lab_content = my_labs.get(day, "NO LABS")
                if lab_content != "NO LABS":
                    st.markdown(f"""
                        <div class='schedule-card slot-lab'>
                            <span style='font-size:0.7rem; color:#ffb86c;'>14:00 - 17:00</span><br>
                            🧪 {lab_content}
                        </div>
                    """, unsafe_allow_html=True)
                else:
                    st.markdown(f"""
                        <div class='schedule-card slot-free'>
                            <span style='font-size:0.7rem; color:#00ff9d;'>14:00 - 17:00</span><br>
                            🟢 FREE TIME
                        </div>
                    """, unsafe_allow_html=True)

    with st.sidebar:
        st.markdown("### ⚙️ DIAGNOSTICS")
        if st.checkbox("Show Network Data"):
            st.dataframe(get_all_users())
        if st.button("TERMINATE CONNECTION"):
            st.cache_data.clear()
            update_status(user['id'], "FALSE")
            st.session_state.clear()
            st.rerun()

# --- PAGE 3: SUCCESS ---
elif st.session_state.page == 'success':
    st.markdown("<br><br><br>", unsafe_allow_html=True)
    st.markdown(f"""
        <div style='text-align: center; border: 2px solid #00f2fe; padding: 50px; border-radius: 20px; background: rgba(0, 242, 254, 0.05);'>
            <h1 style='font-size: 4rem;'>UPLINK ESTABLISHED</h1>
            <p style='font-size: 1.5rem;'>Matched with <b style='color:#bc8cff;'>{st.session_state.linked_peer.upper()}</b></p>
        </div>
    """, unsafe_allow_html=True)
    if st.button("RETURN TO HUB"):
        st.session_state.page = 'hub'
        st.rerun()