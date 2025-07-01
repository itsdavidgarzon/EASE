import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Monitor',
      theme: ThemeData(
        fontFamily: 'SourceSans3',
        scaffoldBackgroundColor: const Color(0xFFFFE0E0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA83434),
          primary: const Color(0xFFA83434),
          secondary: const Color(0xFF7A1E1E),
          background: const Color(0xFFFFE0E0),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ESP32 Monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;

  String connectionStatus = "Waiting for BLE...";
  String lastMessage = "None";

  bool sent75 = false;
  bool sent95 = false;

  final String deviceName = "EASEHygienePad";
  final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid characteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();
  }

  Future<void> toggleConnection() async {
    if (isConnected) {
      await connectedDevice?.disconnect();
      setState(() {
        connectedDevice = null;
        targetCharacteristic = null;
        isConnected = false;
        connectionStatus = "Disconnected from ESP32";
        lastMessage = "None";
      });
    } else {
      scanAndConnect();
    }
  }

  void scanAndConnect() async {
    setState(() {
      connectionStatus = "Scanning for ESP32...";
    });

    await connectedDevice?.disconnect();
    await FlutterBluePlus.stopScan();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final name = r.advertisementData.localName;
        if (name == deviceName) {
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    setState(() {
      connectionStatus = "Connecting...";
    });

    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;
      isConnected = true;
      setState(() => connectionStatus = "Connected to ESP32");
      await discoverServices(device);
    } catch (e) {
      setState(() {
        connectionStatus = "Connection failed";
        isConnected = false;
      });
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            targetCharacteristic = characteristic;
            subscribeToNotifications();
            return;
          }
        }
      }
    }
    setState(() {
      connectionStatus = "Service not found.";
    });
  }

  void subscribeToNotifications() async {
    if (targetCharacteristic != null) {
      await targetCharacteristic!.setNotifyValue(true).catchError((e) {
        print("Notification setup failed: $e");
      });

      targetCharacteristic!.value.listen((value) {
        if (value.isEmpty) {
          print("Received empty BLE message — ignoring.");
          return;
        }

        final decoded = utf8.decode(value);
        print("Received: $decoded");

        setState(() {
          lastMessage = decoded;
        });

        if (decoded == "CONNECTED") {
          setState(() {
            connectionStatus = "Connected to ESP32 (confirmed)";
          });
        } else if (decoded == "THRESHOLD_75" && !sent75) {
          NotificationService().showNotification("75% capacity reached.");
          sent75 = true;
        } else if (decoded == "THRESHOLD_95" && !sent95) {
          NotificationService().showNotification("95% capacity reached.");
          sent95 = true;
        } else if (decoded == "LEAKAGE_LOW") {
          NotificationService().showNotification("Leakage Detected: Low");
        } else if (decoded == "LEAKAGE_MEDIUM") {
          NotificationService().showNotification("Leakage Detected: Medium");
        } else if (decoded == "LEAKAGE_HIGH") {
          NotificationService().showNotification("Leakage Detected: High");
        }

        if (!(decoded.contains("75") || decoded.contains("95"))) {
          sent75 = false;
          sent95 = false;
        }
      });
    }
  }

  void triggerTestNotification(String type, [dynamic value]) {
    Future.delayed(const Duration(seconds: 5), () {
      if (type == "threshold" && value == 75) {
        NotificationService().showNotification("75% capacity reached.");
        setState(() => lastMessage = "Test: threshold 75%");
      } else if (type == "threshold" && value == 95) {
        NotificationService().showNotification("95% capacity reached.");
        setState(() => lastMessage = "Test: threshold 95%");
      } else if (type == "leakage") {
        NotificationService().showNotification("Leakage: $value");
        setState(() => lastMessage = "Test: leakage $value");
      }
    });
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = isConnected;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: <Widget>[
              const Text('Device Status',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Connection Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: connected ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  connectionStatus,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: connected ? Colors.green[900] : Colors.red[900],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Last Received Message
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Last Received Message:",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    lastMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: toggleConnection,
                child: Text(connected ? "Disconnect" : "Connect"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    sent75 = false;
                    sent95 = false;
                    lastMessage = "None";
                    connectionStatus =
                        connected ? "Connected to ESP32" : "Monitoring reset";
                  });
                },
                child: const Text("Reset Notifications"),
              ),

              const Divider(height: 40),
              const Text("Test Notifications",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => triggerTestNotification("threshold", 75),
                  child: const Text("Test 75% Threshold")),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => triggerTestNotification("threshold", 95),
                  child: const Text("Test 95% Threshold")),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => triggerTestNotification("leakage", "low"),
                  child: const Text("Test Low Leakage")),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => triggerTestNotification("leakage", "medium"),
                  child: const Text("Test Medium Leakage")),
              const SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () => triggerTestNotification("leakage", "high"),
                  child: const Text("Test High Leakage")),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(settings);
  }

  Future<void> showNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'threshold_notifications',
      'ESP32 Threshold Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin.show(
        0, 'ESP32 Threshold Alert', message, platformDetails);
  }
}
