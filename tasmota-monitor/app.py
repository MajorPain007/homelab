import streamlit as st
import pandas as pd
import requests
import time
import os
import threading
import altair as alt
import json
from datetime import datetime, timedelta

# --- KONSTANTEN ---
DATA_DIR = "data"
CONFIG_FILE = os.path.join(DATA_DIR, "config.json")

# Standard-Werte
DEFAULT_CONFIG = {
    "refresh_rate": 5,
    "retention_days": 30,
    "devices": {
        "Server": "192.168.30.190",
        "Tisch": "192.168.30.191"
    }
}

# --- SETUP ---
st.set_page_config(page_title="Tasmota Hub", page_icon="⚡", layout="wide")

if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

# --- HELPER FUNKTIONEN ---
def load_config():
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "w") as f:
            json.dump(DEFAULT_CONFIG, f, indent=4)
        return DEFAULT_CONFIG
    with open(CONFIG_FILE, "r") as f:
        try:
            return json.load(f)
        except:
            return DEFAULT_CONFIG

def save_config(new_config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(new_config, f, indent=4)

def cleanup_data(file_path, days_to_keep):
    try:
        if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
            df = pd.read_csv(file_path, names=["timestamp", "watt"], header=0)
            df["timestamp"] = pd.to_datetime(df["timestamp"], format='mixed', errors='coerce')
            df = df.dropna(subset=['timestamp'])
            cutoff = datetime.now() - timedelta(days=days_to_keep)
            df_new = df[df["timestamp"] > cutoff]
            if len(df_new) < len(df):
                df_new.to_csv(file_path, index=False)
    except: pass

def get_device_status_detailed(ip):
    try:
        r = requests.get(f"http://{ip}/cm?cmnd=Status%2011", timeout=1.5)
        data = r.json()
        return data.get("StatusSTS", {})
    except:
        return None

def toggle_device_relay(ip, relay_name):
    try:
        cmd_target = relay_name.replace("STATUS", "")
        requests.get(f"http://{ip}/cm?cmnd={cmd_target}%20TOGGLE", timeout=1)
        return True
    except:
        return False

# --- HINTERGRUND SAMMLER ---
@st.cache_resource
def start_background_collector():
    def collect_loop():
        last_cleanup = datetime.now()
        while True:
            current_config = load_config()
            devices = current_config.get("devices", {})
            rate = current_config.get("refresh_rate", 5)
            retention = current_config.get("retention_days", 30)

            for name, ip in devices.items():
                try:
                    url = f"http://{ip}/cm?cmnd=Status%208"
                    r = requests.get(url, timeout=2)
                    data = r.json()
                    if 'StatusSNS' in data and 'ENERGY' in data['StatusSNS']:
                        watt = float(data['StatusSNS']['ENERGY']['Power'])
                    else:
                        watt = 0.0
                    
                    file_path = os.path.join(DATA_DIR, f"{name}.csv")
                    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    
                    if not os.path.exists(file_path):
                        with open(file_path, "w") as f:
                            f.write("timestamp,watt\n")
                            
                    with open(file_path, "a") as f:
                        f.write(f"{timestamp},{watt}\n")
                        f.flush()
                        os.fsync(f.fileno())
                except: pass
            
            if (datetime.now() - last_cleanup).total_seconds() > 3600:
                for name in devices.keys():
                    cleanup_data(os.path.join(DATA_DIR, f"{name}.csv"), retention)
                last_cleanup = datetime.now()
            
            time.sleep(rate)

    t = threading.Thread(target=collect_loop, daemon=True)
    t.start()

start_background_collector()

# --- FRONTEND ---

config = load_config()
devices = config.get("devices", {})

# Sidebar Navigation
st.sidebar.title("Menü")
page = st.sidebar.radio("Navigation", ["📊 Monitor", "🎛️ Steuerung", "⚙️ Verwaltung"], label_visibility="collapsed")
st.sidebar.divider()

# ==========================================
# SEITE 1: MONITOR (Graph Only)
# ==========================================
if page == "📊 Monitor":
    st.sidebar.subheader("Monitor Optionen")
    is_paused = st.sidebar.checkbox("⏸️ Pause (Zoom)")
    smoothing_window = st.sidebar.slider("Glättung", 1, 20, 3)
    new_rate = st.sidebar.slider("Refresh (s)", 2, 60, config.get("refresh_rate", 5))
    if new_rate != config.get("refresh_rate"):
        config["refresh_rate"] = new_rate
        save_config(config)

    if not devices:
        st.info("Keine Geräte konfiguriert.")
    else:
        # Gerät wählen
        box_options = list(devices.keys())
        if "selected_device" not in st.session_state or st.session_state.selected_device not in box_options:
            st.session_state.selected_device = box_options[0]
        idx = box_options.index(st.session_state.selected_device)
        selected_device_name = st.selectbox("Gerät", box_options, index=idx, key="selected_device")

        # Nur ein kleiner Link, keine Buttons!
        current_ip = devices[selected_device_name]
        st.caption(f"IP: {current_ip} | [🌐 Web-Interface](http://{current_ip})")

        # Zeit wählen
        time_options = {"10 Min": 10, "1 Std": 60, "6 Std": 360, "24 Std": 1440, "7 Tage": 10080, "Alles": 0}
        selected_time_label = st.radio("Zeitraum", list(time_options.keys()), horizontal=True)

        file_path = os.path.join(DATA_DIR, f"{selected_device_name}.csv")

        if os.path.exists(file_path):
            try:
                df = pd.read_csv(file_path, names=["timestamp", "watt"], header=0)
                df["timestamp"] = pd.to_datetime(df["timestamp"], format='mixed', errors='coerce')
                df = df.dropna(subset=['timestamp'])
                df = df.sort_values(by="timestamp")

                minutes = time_options[selected_time_label]
                if minutes > 0:
                    cutoff = datetime.now() - timedelta(minutes=minutes)
                    df = df[df["timestamp"] > cutoff]
                
                if not df.empty:
                    # Stats
                    last_val = df.iloc[-1]["watt"]
                    max_val = df["watt"].max()
                    avg_val = df["watt"].mean()

                    col1, col2, col3 = st.columns(3)
                    col1.metric("Aktuell", f"{last_val:.1f} W")
                    col2.metric("Max", f"{max_val:.1f} W")
                    col3.metric("Ø", f"{avg_val:.1f} W")

                    # Glättung
                    if smoothing_window > 1:
                        df["watt_smooth"] = df["watt"].rolling(window=smoothing_window, min_periods=1).mean()
                        y_col = "watt_smooth"
                        tooltip = [
                            alt.Tooltip('timestamp', title='Zeit', format='%H:%M:%S'),
                            alt.Tooltip('watt', title='Roh (W)', format='.1f'),
                            alt.Tooltip('watt_smooth', title='Glatt (W)', format='.1f')
                        ]
                    else:
                        y_col = "watt"
                        tooltip = [
                            alt.Tooltip('timestamp', title='Zeit', format='%H:%M:%S'),
                            alt.Tooltip('watt', title='Watt', format='.1f')
                        ]

                    axis_format = '%H:%M'
                    if minutes == 0 or minutes > 1440: axis_format = '%d.%m %H:%M'
                    elif minutes <= 10: axis_format = '%H:%M:%S'

                    # Graph (Clean Definition)
                    chart = alt.Chart(df).mark_line(
                        color='#FFA500', 
                        interpolate='monotone'
                    ).encode(
                        x=alt.X('timestamp', axis=alt.Axis(title='Zeit', format=axis_format, grid=True)),
                        y=alt.Y(y_col, axis=alt.Axis(title='Leistung (W)')),
                        tooltip=tooltip
                    ).properties(
                        height=450
                    ).interactive()

                    st.altair_chart(chart, use_container_width=True)
                else:
                    st.warning("Keine Daten im Zeitraum.")
            except Exception as e:
                st.error(f"Fehler beim Laden: {e}")
        else:
            st.info("Warte auf Daten...")

    # Auto Refresh nur auf der Monitor Seite
    if not is_paused:
        time.sleep(config.get("refresh_rate", 5))
        st.rerun()

# ==========================================
# SEITE 2: STEUERUNG (Buttons Only)
# ==========================================
elif page == "🎛️ Steuerung":
    st.title("🎛️ Multi-Switch Steuerung")
    
    if st.button("🔄 Status aktualisieren"):
        st.rerun()
    
    st.markdown("---")
    
    if not devices:
        st.info("Keine Geräte.")
    
    for name, ip in devices.items():
        with st.container():
            c1, c2 = st.columns([3, 1])
            c1.subheader(f"{name}")
            c2.link_button("🌐 Tasmota Web", f"http://{ip}")
            
            status_data = get_device_status_detailed(ip)
            
            if status_data:
                power_keys =
                power_keys.sort()
                
                if not power_keys:
                    st.warning("Verbunden, aber keine Schalter gefunden.")
                else:
                    # Grid für Schalter
                    cols = st.columns(4)
                    for i, p_key in enumerate(power_keys):
                        state = status_data[p_key]
                        col = cols[i % 4]
                        
                        with col:
                            # Label generieren
                            lbl = p_key.replace("POWER", "Schalter ")
                            if lbl == "Schalter ": lbl = "Hauptschalter"
                            
                            st.caption(lbl)
                            
                            # Farbige Buttons
                            if state == "ON":
                                if st.button(f"🟢 AN", key=
                                    toggle_device_relay(ip, p_key)
                                    time.sleep(0.2)
                                    st.rerun()
                            else:
                                if st.button(f"🔴 AUS", key=
                                    toggle_device_relay(ip, p_key)
                                    time.sleep(0.2)
                                    st.rerun()
            else:
                st.error(f"❌ {name} offline")
        st.divider()

# ==========================================
# SEITE 3: VERWALTUNG
# ==========================================
elif page == "⚙️ Verwaltung":
    st.title("⚙️ Einstellungen")
    
    tab1, tab2 = st.tabs(["Geräte", "System"])
    
    with tab1:
        st.subheader("Hinzufügen")
        with st.form("add"):
            c1, c2 = st.columns(2)
            nn = c1.text_input("Name")
            ni = c2.text_input("IP")
            if st.form_submit_button("Hinzufügen"):
                if nn and ni:
                    config["devices"][nn] = ni
                    save_config(config)
                    st.rerun()

        st.subheader("Liste & Bearbeiten")
        for n, i in list(devices.items()):
            with st.expander(f"{n}"):
                with st.form(f"edit_{n}"):
                    en = st.text_input("Name", value=n)
                    ei = st.text_input("IP", value=i)
                    dele = st.checkbox("Löschen")
                    if st.form_submit_button("Speichern"):
                        if dele:
                            del config["devices"][n]
                        else:
                            if en != n:
                                del config["devices"][n]
                                try: os.rename(os.path.join(DATA_DIR, f"{n}.csv"), os.path.join(DATA_DIR, f"{en}.csv"))
                                except: pass
                            config["devices"][en] = ei
                        save_config(config)
                        st.rerun()
                        
    with tab2:
        st.subheader("Datenbank")
        nr = st.number_input("Behalten (Tage)", value=config.get("retention_days", 30))
        if st.button("Speichern"):
            config["retention_days"] = nr
            save_config(config)
            st.success("Gespeichert")
