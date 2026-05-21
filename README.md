# 🛡️ HealthGuard: A Context-Aware Personalized Health Anomaly Detection System



> 🚀 **Using Machine Learning and Deep Learning for Preventive Healthcare**

HealthGuard Resources Drive: https://drive.google.com/drive/folders/1fVpUpfcCrq7Z0m9G2OHgoMox37M-9g2C?usp=sharing
Google Play Link: https://play.google.com/store/apps/details?id=com.swapnilsalunke.healthguard
(Currently accessible to internal testers only)

## 🎯 Project Overview

HealthGuard is an end-to-end, production-ready remote patient monitoring ecosystem designed to transition mobile health tracking from reactive data logging into proactive, intelligent intervention. Traditional health trackers suffer from **context blindness**, triggering excessive non-actionable false alarms (alert fatigue) when biometrics naturally fluctuate due to environmental variables.

HealthGuard solves this by deploying a **Dual-Layer AI Architecture**:

1. 🌲 **Context-Aware Filtering Layer:** A machine learning Context Engine that factors in real-time activity and atmospheric telemetry (temperature, humidity, noise, AQI) to dynamically calculate safe physiological limits.
2. 🧬 **Personalized Deep Learning Layer:** A personalized **Digital Twin** (LSTM Autoencoder) trained on per-user historical trends to track unique biological rhythms and spot subtle, multi-metric clinical degradation.

The architecture features a cross-platform **Flutter mobile client** and a high-performance, serverless **FastAPI (Python) backend** hosted on **Google Cloud Run**, fully integrated with **Supabase** and published for internal target testing.



## ✨ Key Features

* 🧠 **Dual-Tier AI Pipeline:** Implements a rapid, in-memory global Random Forest model for instant environmental assessment alongside stateless, user-specific LSTM weight loading.
* 📈 **Dynamic Thresholding:** Continuously updates target alert margins based on real-time atmospheric shifts to reduce false alarms by over 85% during environmental stress.
* 📱 **Device-Agnostic Core:** Operates strictly at the software intelligence layer, allowing premium clinical-grade tracking completely independent of proprietary wearable hardware costs.
* 🔍 **Universal OCR Lab Scanner:** Employs computer vision to instantly extract, structure, and securely stream biochemical metrics from paper medical reports directly to data storage tables.
* 📺 **On-Demand Screen Digitization:** Uses an integrated screen scanner tool to digitize data from legacy third-party hardware displays, bridging physical instrumentation with cloud storage.
* 🔄 **Asynchronous Re-training Loop:** Features an automated background CRON runner that sequences 30-day historical health windows to safely update user weights without causing live application API lag.



## 🏗️ System Architecture


[⌚ Wearable / Manual Data] 
            │
            ▼
 📱 [Flutter App Client] ───( 📨 POST JSON Micro-Payload )───► ⚡ [FastAPI on Cloud Run]
            ▲                                                           │
            │                                                   ┌───────┴───────┐
            │                                                   ▼               ▼
 🔔 [FCM Push Alert] ◄───( 🚨 Trigger if Anomaly )─── 🗄️ [Supabase DB]  📦 [Supabase Storage]
                                                       (Telemetry)    (.tflite weights)



The system minimizes user cellular bandwidth and latency by implementing a **Hybrid Micro-Payload strategy**: the mobile client transmits only the immediate current timestamp context, while the server coordinates heavy sequential fetching and temporal array formatting server-side.


## 📋 Prerequisites & Technical Stack

### 🎨 **Frontend Client**

* **Framework:** Flutter SDK `^3.19.0` or higher
* **Language:** Dart `^3.3.0`

### ⚙️ **Backend & Machine Learning Inference**

* **Language:** Python `3.10` or `3.11`
* **Framework:** FastAPI
* **Core Libraries:** `scikit-learn`, `tensorflow-cpu`, `pydantic`, `supabase-py`

### ☁️ **Cloud Infrastructure & Storage**

* **Database:** Supabase PostgreSQL (Relational time-series table schema)
* **Object Storage:** Supabase Storage Bucket (`user_models/` directory for `.tflite` binaries and `scaler.gz` files)
* **Cloud Server:** Google Cloud Run (Stateless container scaling)
* **Alert Dispatch:** Firebase Cloud Messaging (FCM)



## 🧪 Demonstration & Verification Steps

To verify your production implementation against established testing benchmarks, follow this sequence:

1. ☀️ **Simulate Environmental Activity Baseline (TC1):** Input a high heart rate state ($HR = 110\,\text{BPM}$) bundled with high environmental temperature parameters ($Temp = 38^{\circ}\text{C}$) and high motion tracking ($Steps = 5000$). Ensure the main dashboard index scales gracefully to display a `SAFE` status callout, indicating the Context Engine successfully filtered out ambient weather interference.
2. 🛋️ **Verify Rest Anomaly Triggering (TC2):** Submit an elevated heart rate ($HR = 110\,\text{BPM}$) during complete rest states ($Steps = 50$) under normal ambient conditions ($Temp = 22^{\circ}\text{C}$). Verify that the engine immediately escalates the state classification output to `ELEVATED` and updates database anomaly rows.
3. 🌡️ **Trigger Temporal Illness Progression Anomaly (TC4):** Stream a progressive 48-hour sequential telemetry string showing steady multi-metric degradation to simulate systemic illness onset. Monitor your device logs to confirm that as internal patterns deviate from the stored digital twin memory, the Mean Squared Error ($MSE$) spikes sharply above the personalized anomaly threshold, instantly dispatching an early warning alert.
4. 📄 **Execute Document OCR Extractions (TC5):** Launch the universal scanning feature within your application layout and present a physical lab report page to the camera lens. Confirm the system smoothly tokenizes unstructured data streams, parses individual blood metrics, and formats payload packages without user dashboard lag.