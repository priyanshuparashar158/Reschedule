import streamlit as st
from streamlit_gsheets import GSheetsConnection
import pandas as pd
import numpy as np
import socket
import threading
import time
from sklearn.neighbors import NearestNeighbors

# 1. UI CONFIGURATION
st.set_page_config(page_title="Reschedule // AI-LINK", page_icon="📶", layout="wide")

# 2. PRISM DARK CSS (Black Font Buttons + Modern Toggle)
st.markdown("""
    <style>
    .stApp { background-color: #0d1117; }
    h1, h2, h3, label { color: #f0f6fc !important; font-family: 'Inter', sans-serif; font-weight: 800 !important; }
    
    .stButton > button {
        background: linear-gradient(135deg, #00f2fe 0%, #bc8cff 100%) !important;
        color: #000 !important; font-weight: 800 !important; 
        border-radius: 10px !important; text-transform: uppercase;
    }

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
    .offline-badge { background: #ff4b4b; color: white; padding: 5px 15px; border-radius: 20px; font-weight: bold; }
    </style>
    """, unsafe_allow_html=True)

# --- 3. OFFLINE P2P DISCOVERY ENGINE ---
UDP_PORT = 5005
if 'local_peers' not in st.session_state: st.session_state.local_peers = {}

def start_broadcast(name):
    """Announces presence to local Wi-Fi nodes."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    while True:
        try:
            message = f"RESCHEDULE_PEER:{name}".encode()
            sock.sendto(message, ('<broadcast>', UDP_PORT))
        except: pass
        time.sleep(4)

def listen_for_peers():
    """Detects other Reschedule nodes on the network."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('', UDP_PORT))
    while True:
        data, addr = sock.recvfrom(1024)
        msg = data.decode()
        if msg.startswith("RESCHEDULE_PEER:"):
            peer_name = msg.split(":")[1]
            st.session_state.local_peers[addr[0]] = {"name": peer_name, "time": time.time()}

# --- NAVIGATION ---
if 'page' not in st.session_state: st.session_state.page = 'gate'

# --- PAGE 1: GATEWAY ---
if st.session_state.page == 'gate':
    st.write("# 📡 RESCHEDULE GATEWAY")
    is_free = st.checkbox("SIGNAL AVAILABILITY", key="gate_toggle")
    if is_free:
        st.markdown("<h1 style='color:#00f2fe !important; font-size: 60px;'>I AM FREE</h1>", unsafe_allow_html=True)
        if st.button("PROCEED TO HUB"):
            st.session_state.page = 'hub'
            st.rerun()

# --- PAGE 2: HUB (KNN + OFFLINE MESH) ---
elif st.session_state.page == 'hub':
    if 'user' not in st.session_state:
        with st.form("id"):
            sid = st.text_input("ROLL NUMBER")
            name = st.text_input("NICKNAME")
            if st.form_submit_button("CONNECT"):
                st.session_state.user = {"id": sid, "name": name}
                # Trigger P2P Threads once user is identified
                threading.Thread(target=start_broadcast, args=(name,), daemon=True).start()
                threading.Thread(target=listen_for_peers, daemon=True).start()
                st.rerun()
        st.stop()

    user = st.session_state.user
    st.write(f"# 🪐 HUB // {user['name'].upper()}")

    # A. OFFLINE MESH DISCOVERY
    st.write("### 📶 Local Mesh Nodes (Offline Discovery)")
    current_time = time.time()
    # Clean up peers not seen in last 12 seconds
    active_local = {k: v for k, v in st.session_state.local_peers.items() if current_time - v['time'] < 12}
    
    if active_local:
        for ip, info in active_local.items():
            st.success(f"Peer Detected via Wi-Fi Direct: **{info['name']}**")
    else:
        st.info("Scanning local network for Reschedule nodes...")

    # B. ONLINE KNN MATCHING
    st.divider()
    st.write("### 🤖 AI-Matched Peers (Cloud Sync)")
    all_interests = ["Python", "DSA", "ML", "Math", "Linear Algebra"]
    my_focus = st.multiselect("DEFINE FOCUS:", all_interests, default=["Python"])
    
    try:
        conn = st.connection("gsheets", type=GSheetsConnection)
        all_data = conn.read(ttl=0)
        all_data['interests'] = all_data['interests'].fillna("")
        all_data['is_active'] = all_data['is_active'].fillna(False).astype(bool)

        # Update Current User Status
        new_row = pd.DataFrame([{"student_id": user["id"], "name": user["name"], "interests": ",".join(my_focus), "is_active": True}])
        updated_df = pd.concat([all_data[all_data['student_id'] != user["id"]], new_row], ignore_index=True)
        conn.update(data=updated_df)

        # KNN Logic
        active_peers = all_data[(all_data['is_active'] == True) & (all_data['student_id'] != user['id'])]
        if not active_peers.empty:
            def encode(lst): return [1 if i in lst.split(",") else 0 for i in all_interests]
            peer_vecs = [encode(p) for p in active_peers['interests']]
            my_vec = [1 if i in my_focus else 0 for i in all_interests]
            
            knn = NearestNeighbors(n_neighbors=min(len(peer_vecs), 4), metric='cosine')
            knn.fit(peer_vecs)
            dist, idx = knn.kneighbors([my_vec])
            
            for i, val in enumerate(idx[0]):
                p = active_peers.iloc[val]
                sim = round((1 - dist[0][i]) * 100, 1)
                st.markdown(f'<div class="prism-card">👤 {p["name"]} | Similarity: {sim}%</div>', unsafe_allow_html=True)
                if st.button(f"⚡ LINK WITH {p['name'].split()[0]}", key=p['student_id']):
                    st.session_state.linked_peer = p['name']
                    st.session_state.page = 'success'
                    st.rerun()
    except:
        st.markdown('<span class="offline-badge">OFFLINE MODE ACTIVE</span>', unsafe_allow_html=True)
        st.warning("Internet disconnected. KNN matching suspended. Use Local Mesh Discovery above.")

    if st.sidebar.button("🚪 GO OFFLINE"):
        st.session_state.clear()
        st.rerun()

# --- PAGE 3: SUCCESS ---
elif st.session_state.page == 'success':
    st.markdown(f"<div style='text-align:center;'><h1>🚀 LINKED WITH {st.session_state.linked_peer.upper()}</h1></div>", unsafe_allow_html=True)
    

#  [Image of K-Nearest Neighbors diagram]

    if st.button("RETURN"):
        st.session_state.page = 'hub'
        st.rerun()