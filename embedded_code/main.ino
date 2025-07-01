#include <Arduino.h>
#include <FreqCountESP.h>

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ==========================
// GPIO and Threshold Setup
// ==========================
#define CENTER_PIN 25  // Also used by FreqCountESP
const int OUTER_PINS[] = {32, 33, 34, 35};
const int NUM_OUTER_PINS = sizeof(OUTER_PINS) / sizeof(OUTER_PINS[0]);

#define THRESHOLD_75 69000 // 59000
#define THRESHOLD_95 54500
#define LEAK_THRESHOLD_1 59000 // 75%
#define LEAK_THRESHOLD_2 61500 // 60%
#define LEAK_THRESHOLD_3 64000 // 50%

// ==========================
// BLE Definitions
// ==========================
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Notification flags
bool sent75 = false;
bool sent95 = false;

// ==========================
// BLE Connection Handling
// ==========================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) override {
    deviceConnected = true;
    if (pCharacteristic != nullptr) {
      pCharacteristic->setValue("CONNECTED");
      pCharacteristic->notify();
    }
  }
  void onDisconnect(BLEServer *pServer) override {
    deviceConnected = false;
  }
};

// ==========================
// Modular Setup Functions
// ==========================
void initSerial() {
  Serial.begin(115200);
}

void initSensorPins() {
  for (int i = 0; i < NUM_OUTER_PINS; i++) {
    pinMode(OUTER_PINS[i], INPUT);
  }
}

void initFreqCounter() {
  FreqCountESP.begin(CENTER_PIN, 1000);  // 1-second sample
}

void initBLE() {
  BLEDevice::init("EASEHygienePad");
  BLEDevice::setPower(ESP_PWR_LVL_N0);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_INDICATE
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();

  Serial.println("Waiting for client connection...");
}

void setup() {
  initSerial();
  initSensorPins();
  initFreqCounter();
  initBLE();
}

// ==========================
// Main Loop
// ==========================
void loop() {
  if (deviceConnected) {
    // // ----- Short Detection -----
    // int shortsDetected = 0;
    // for (int i = 0; i < NUM_OUTER_PINS; i++) {
    //   if (digitalRead(OUTER_PINS[i]) == HIGH) {
    //     shortsDetected++;
    //   }
    // }

    // ----- Frequency Reading -----
    if (FreqCountESP.available()) {
      uint32_t frequency = FreqCountESP.read();
      Serial.print("Frequency:");
      Serial.println(frequency);
      // Serial.print("Shorts: ");
      // Serial.println(shortsDetected);

      // ---- Capacitance Threshold Notifications (75% and 95%) ----
      if (frequency < THRESHOLD_95 && !sent95) {
        Serial.println("Reached the 95% threshold!");
        pCharacteristic->setValue("THRESHOLD_95");
        pCharacteristic->notify();
        sent95 = true;
      } else if (frequency < THRESHOLD_75 && !sent75) {
        Serial.println("Reached the 75% threshold!");
        pCharacteristic->setValue("THRESHOLD_75");
        pCharacteristic->notify();
        sent75 = true;
      }

      // Reset flags if frequency rises above 75% again
      if (frequency >= THRESHOLD_75) {
        sent75 = false;
        sent95 = false;
      }

      // // ---- Leak Detection Logic ----
      // if (shortsDetected > 0) {
      //   uint32_t leakThreshold = LEAK_THRESHOLD_1;
      //   String severity = "low";

      //   if (shortsDetected == 2) {
      //     leakThreshold = LEAK_THRESHOLD_2;
      //     severity = "medium";
      //   }
      //   if (shortsDetected >= 3) {
      //     leakThreshold = LEAK_THRESHOLD_3;
      //     severity = "high";
      //   }

      //   if (frequency < leakThreshold) {
      //     Serial.println("Leakage detected — sending BLE notification.");
      //     String message = "{\"type\":\"leakage\",\"severity\":\"" + severity + "\"}";
      //     pCharacteristic->setValue(message.c_str());
      //     pCharacteristic->notify();
      //   }
      // }
    }

    // delay(10000);
  }

  // ----- BLE Reconnection Handling -----
  if (!deviceConnected && oldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    Serial.println("Restarting advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(500);
}
