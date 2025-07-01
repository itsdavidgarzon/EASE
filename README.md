# EASE: Notifying Feminine Hygiene Pad

**EASE** (Enhanced Alert System for Everyone) is a smart wearable system that integrates sensor technology, embedded systems, and mobile communication to provide real-time alerts when a menstrual hygiene pad approaches saturation. The system enhances user comfort and confidence by preventing leaks and promoting better menstrual health management.

## 🧠 Overview

This project was developed as a Senior Design capstone at the University of Central Florida. It consists of three major components:

* **Embedded System (ESP32 + PCB)**
* **Cross-platform Mobile Application (Flutter)**
* **Informational Website (HTML/CSS/JS)**

The project was sponsored by Gabriela Mercado and advised by Dr. Lei Wei.

## 🔧 Features

### ✅ Core Capabilities

* Real-time fluid level monitoring via capacitive sensors
* BLE notifications at 75% and 95% pad saturation
* Optional leak detection using solid-state perimeter sensors
* Cross-platform mobile alerts (Android/iOS)
* Reusable, low-power design with optimized PCB integration

### 🎯 Goals

* **Basic**: Reliable sensing, comfort, BLE alerts
* **Advanced**: Cross-platform support, reusable system, sensor readouts
* **Stretch**: Health tracking (e.g. pH), wearable alert systems

---

## 📁 Repository Structure

```
EASE/
│
├── embedded_code/       # ESP32 firmware (Arduino-based)
│   └── ...
│
├── mobile_app/          # Flutter mobile application
│   └── ...
│
├── website/             # Public-facing website for the EASE project
│   └── ...
│
└── README.md
```

---

## 📱 Mobile App (Flutter)

The mobile app connects to the BLE-enabled pad and receives alerts when the product reaches defined fluid thresholds. Key functions:

* Scan and connect to ESP32 device (`EASEHygienePad`)
* Display BLE notifications and sensor status
* Toggle device connection

---

## 🔌 Embedded System (ESP32)

### Components

* **MCU**: ESP32-WROOM (chosen for BLE, dev ease)
* **Sensor**: Flex PCB with interdigitated capacitive electrodes
* **ADC**: AD7746 for precise capacitance-to-digital conversion
* **Power**: 9V battery + 3.3V regulator (NCP1117)
* **Leak Detection**: Concentric solid-state rings short when fluid bridges them

### BLE Protocol

* Sends simple string-based alerts over GATT (e.g., `"THRESHOLD_75"`, `"LEAK_LOW"`)

---

## 🌐 Website

The website serves as a static project showcase with:

* Overview of the EASE system
* Meet the Team section
* Sponsor and Advisor acknowledgements
* Design documentation and updates

---

## 🧪 Testing and Evaluation

The system underwent extensive testing:

* Capacitance threshold detection via 555 timer + ADC fallback
* Leak detection validation with conductive fluids
* BLE stability across Android/iOS
* Response time < 3 seconds on average

Target accuracy: **±0.5 mL**

---

## 📚 Documentation

* [📘 Final Report (PDF)](./SD2_Final_Report.pdf)
* [📘 Conference Paper (PDF)](./8_Page_Conference_Paper.pdf)

---

## 🤝 Contributors

* **David Garzon** (Computer Engineer)
* **Alexander Nguyen** (Electrical Engineer)
* **Matthew Poole** (Electrical Engineer)
* **Dillon Sardarsingh** (Electrical Engineer)

Sponsor: Gabriela Mercado
Advisor: Dr. Lei Wei

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
