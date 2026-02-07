import streamlit as st
from streamlit_gsheets import GSheetsConnection
import pandas as pd
import numpy as np
from sklearn.neighbors import NearestNeighbors

# 1. ADVANCED UI CONFIGURATION
st.set_page_config(page_title="NEXUS // AI-LINK", page_icon="🔗", layout="wide")

# 2. PRISM DARK CSS (Black Font + High Contrast)
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;700;800&display=swap');
    
    .stApp { background-color: #0d1117; }
    
    h1, h2, h3, label { 
        font-family: 'Inter', sans-serif !important; 
        color: #f0f6fc !important; 
        font-weight: 800 !important;
    }
    
    /* PRISM BUTTONS: Black Font for Hackathon Visibility */
    .stButton > button {
        background: linear-gradient(135deg, #00f2fe 0%, #bc8cff 100%) !important;
        color: #000000 !important; 
        border: none !important;
        padding: 0.6rem 2rem !important;
        border-radius: 10px !important;
        font-weight: 800 !important;
        text-transform: uppercase;
    }

    /* BLUE PILL TOGGLE */
    div[data-testid="stCheckbox"] > label > div[role="checkbox"] {
        height: 38px !important; width: 75px !important;
        background-color: #21262d !important; border-radius: 40px !important;
        border: 2px solid #30363d !important;
    }
    div[data-testid="stCheckbox"] > label > div[role="checkbox"][aria-checked="true"] {
        background-color: #00f2fe !important;
    }

    .prism-card {
        background: rgba(22, 27, 34, 0.6);
        border: 1px solid rgba(48, 54, 61, 0.8);
        border-radius: 16px; padding: 25px; margin-bottom: 20px;
    }
    </style>
    """, unsafe_allow_html=True)

# 3. CONNECTION
conn = st.connection("gsheets", type=GSheetsConnection)
all_possible_interests = ["Python", "DSA", "ML", "Math", "Linear Algebra", "Digital Electronics"]

def encode_interests(interest_list):
    return [1 if i in interest_list else 0 for i in all_possible_interests]

# --- NAVIGATION ---
if 'page' not in st.session_state: st.session_state.page = 'gate'

# --- PAGE 1: GATEWAY (The Filter) ---
if st.session_state.page == 'gate':
    st.markdown("<br><br>", unsafe_allow_html=True)
    st.write("# 📡 NEXUS GATEWAY")
    
    is_free = st.checkbox("SIGNAL AVAILABILITY", key="gate_toggle")
    if is_free:
        st.markdown("<h1 style='color:#00f2fe !important; font-size: 60px;'>I AM FREE</h1>", unsafe_allow_html=True)
        if st.button("PROCEED TO HUB"):
            st.session_state.page = 'hub'
            st.rerun()

# --- PAGE 2: THE HUB (Active Users Only) ---
elif st.session_state.page == 'hub':
    if 'user' not in st.session_state:
        with st.form("identity"):
            sid = st.text_input("ROLL NUMBER")
            name = st.text_input("NICKNAME")
            if st.form_submit_button("CONNECT"):
                st.session_state.user = {"id": sid, "name": name}
                st.rerun()
        st.stop()

    user = st.session_state.user
    st.write(f"# 🪐 HUB // {user['name'].upper()}")

    try:
        # --- ACTIVE DATABASE SYNC ---
        all_data = conn.read(ttl=0)
        
        # 1. Update Current User as Active
        my_interests = ["Python"] # Example; update based on user input
        new_row = pd.DataFrame([{"student_id": user["id"], "name": user["name"], "interests": ",".join(my_interests), "is_active": True}])
        
        # 2. Filter out inactive users immediately from the local view
        # This ensures you only see people who have 'is_active' == True in the sheet
        active_peers = all_data[(all_data['is_active'] == True) & (all_data['student_id'] != user['id'])]
        
        # --- CAMPUS RESOURCE ADVISOR ---
        st.write("### 📍 Empty Venues & Suggestions")
        v1, v2 = st.columns(2)
        with v1: st.markdown('<div class="prism-card"><h3>Computer Centre</h3><p>Status: <b>Empty</b><br>Activity: Project Work</p></div>', unsafe_allow_html=True)
        with v2: st.markdown('<div class="prism-card"><h3>Lecture Hall 3</h3><p>Status: <b>No Class</b><br>Activity: Study Group</p></div>', unsafe_allow_html=True)

        # --- PEER DISPLAY ---
        st.divider()
        st.write("### 🤖 ACTIVE PEER NODES")
        
        if not active_peers.empty:
            for _, p in active_peers.iterrows():
                with st.container():
                    st.markdown(f'<div class="prism-card">👤 {p["name"]} <br> <span style="font-size:0.8em; color:#8b949e;">Interests: {p["interests"]}</span></div>', unsafe_allow_html=True)
                    if st.button(f"⚡ LINK WITH {p['name'].split()[0]}", key=p['student_id']):
                        st.session_state.linked_peer = p['name']
                        st.session_state.page = 'success'
                        st.rerun()
        else:
            st.info("Scanning IIIT Kota... No other active nodes found.")

        # Update the database with current user data
        updated_df = pd.concat([all_data[all_data['student_id'] != user["id"]], new_row], ignore_index=True)
        conn.update(data=updated_df)

    except Exception as e:
        st.error(f"Sync Error: {e}")

    # THE LOGOUT: SETS STATUS TO FALSE
    if st.sidebar.button("🚪 GO OFFLINE"):
        try:
            df = conn.read(ttl=0)
            df.loc[df['student_id'] == user['id'], 'is_active'] = False
            conn.update(data=df)
            st.session_state.clear()
            st.rerun()
        except: st.error("Sign-out failed.")

# --- PAGE 3: SUCCESS ---
elif st.session_state.page == 'success':
    st.markdown("<br><br>", unsafe_allow_html=True)
    st.markdown(f"""
        <div style="text-align: center; border: 2px solid #00f2fe; padding: 50px; border-radius: 30px;">
            <h1 style="color:#00f2fe !important;">🚀 UPLINK SUCCESSFUL!</h1>
            <h2>Linked with {st.session_state.linked_peer.upper()}</h2>
            <p>Recommended Meeting Point: <b>Computer Centre</b></p>
        </div>
    """, unsafe_allow_html=True)
    
    if st.button("RETURN TO HUB"):
        st.session_state.page = 'hub'
        st.rerun()