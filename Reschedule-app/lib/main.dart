import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const SyncSpaceApp());
}

class SyncSpaceApp extends StatelessWidget {
  const SyncSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F2FE),
          primary: const Color(0xFF00F2FE),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161B22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
      ),
      home: const MeshGateway(),
    );
  }
}

class MeshGateway extends StatefulWidget {
  const MeshGateway({super.key});

  @override
  State<MeshGateway> createState() => _MeshGatewayState();
}

class _MeshGatewayState extends State<MeshGateway> {
  // UI CONTROLLERS
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  
  // STATE
  bool isFree = false;          // True = Visible User, False = Silent Relay
  bool isRelayRunning = false;  // True = Bluetooth is ON (in either mode)
  
  // DATA
  Map<String, dynamic> myProfile = {};
  Map<String, Map<String, dynamic>> meshBuffer = {}; 
  List<Map<String, dynamic>> localMatches = [];
  List<String> logs = [];

  // TAGS
  final List<String> availableTags = [
    "Python", "ML", "DSA", "Maths", 
    "Web Dev", "AI", "Block Chain", "Cyber Security"
  ];
  Set<String> selectedTags = {};

  @override
  void initState() {
    super.initState();
    _initRelayMode();
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  void addLog(String msg) {
    setState(() {
      logs.insert(0, "${DateTime.now().second}s: $msg");
      if (logs.length > 5) logs.removeLast();
    });
  }

  // --- 1. INITIALIZATION ---
  void _initRelayMode() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _startMeshService(asRelay: true);
    } else {
      addLog("❌ Permissions Missing");
    }
  }

  // --- 2. TOGGLE LOGIC ---
  void toggleFreeStatus() {
    if (isFree) {
      // SWITCH TO SILENT RELAY
      setState(() {
        isFree = false;
        localMatches.clear(); // Clear visual matches (but keep buffer)
      });
      _startMeshService(asRelay: true);
    } else {
      // SWITCH TO ACTIVE USER
      if (_nameController.text.isEmpty || _rollNoController.text.isEmpty) {
        addLog("❌ Enter Name & Roll No");
        return;
      }
      if (selectedTags.length < 3) {
        addLog("⚠️ Select 3+ interests");
        return;
      }
      setState(() => isFree = true);
      _startMeshService(asRelay: false);
    }
  }

  // --- 3. MESH ENGINE ---
  void _startMeshService({required bool asRelay}) async {
    // CRITICAL FIX: Stop everything before switching modes!
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints(); // Drop existing relay connections to force refresh

    String endpointName;
    
    if (asRelay) {
      endpointName = "Relay_${Random().nextInt(9999)}";
      myProfile = {
        "id": "Relay_${DateTime.now().millisecondsSinceEpoch}",
        "name": "Silent Relay",
        "interests": [],
        "isRelay": true
      };
      addLog("📡 Silent Relay Active");
    } else {
      endpointName = _nameController.text.trim();
      myProfile = {
        "id": _rollNoController.text.trim(),
        "name": endpointName,
        "interests": selectedTags.toList(),
        "isRelay": false
      };
      addLog("✅ You are Visible!");
    }

    setState(() => isRelayRunning = true);

    try {
      // 1. ADVERTISE
      await Nearby().startAdvertising(
        endpointName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: (id, info) {
          Nearby().acceptConnection(id, onPayLoadRecieved: (id, payload) => handlePayload(id, payload));
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) sendMeshData(id);
        },
        onDisconnected: (id) {},
      );

      // 2. DISCOVER
      await Nearby().startDiscovery(
        "SyncSpaceNode",
        Strategy.P2P_CLUSTER,
        onEndpointFound: (id, name, serviceId) {
          // FIX: Instant UI Feedback for Active Users
          if (isFree) {
             setState(() {
              if (!localMatches.any((m) => m['endpointId'] == id)) {
                localMatches.add({
                  "endpointId": id,
                  "id": "Unknown",
                  "name": name, // Show name immediately
                  "score": 0,
                  "interests": [],
                  "status": "Connecting...",
                  "isLoading": true
                });
              }
            });
          }

          Nearby().requestConnection(
            endpointName, 
            id, 
            onConnectionInitiated: (id, info) {
              Nearby().acceptConnection(id, onPayLoadRecieved: (id, payload) => handlePayload(id, payload));
            }, 
            onConnectionResult: (id, status) {
               if (status == Status.CONNECTED) {
                 sendMeshData(id);
               } else {
                 // Clean up if connection failed
                 if (isFree) setState(() => localMatches.removeWhere((m) => m['endpointId'] == id));
               }
            }, 
            onDisconnected: (id) {}
          );
        },
        onEndpointLost: (id) {
           if (isFree) setState(() => localMatches.removeWhere((m) => m['endpointId'] == id));
        },
      );
    } catch (e) {
      addLog("Mesh Error: $e");
    }
  }

  // --- 4. DATA HANDLING ---
  void sendMeshData(String endpointId) {
    Map<String, dynamic> package = { 
      "source": myProfile, 
      "buffer": meshBuffer 
    };
    
    String jsonString = jsonEncode(package);
    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));
    Nearby().sendBytesPayload(endpointId, bytes); 
  }

  void handlePayload(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      try {
        final String str = utf8.decode(payload.bytes!);
        final Map<String, dynamic> receivedPackage = jsonDecode(str);

        processProfile(receivedPackage['source'], endpointId);
        
        if (receivedPackage['buffer'] != null) {
          Map<String, dynamic> incomingBuffer = Map<String, dynamic>.from(receivedPackage['buffer']);
          incomingBuffer.forEach((key, profile) => processProfile(profile, null));
        }
      } catch (e) { addLog("❌ Parse Error"); }
    }
  }

  void processProfile(dynamic profile, String? sourceEndpointId) {
    if (profile == null) return;
    String id = profile['id'];
    bool isPeerRelay = profile['isRelay'] ?? false;

    // A. STORE (Always overwrite to get latest data)
    if (id != myProfile['id']) {
      setState(() {
        meshBuffer[id] = Map<String, dynamic>.from(profile);
      });
    }

    // B. SHOW (Only if I am Active AND Peer is NOT a relay)
    if (!isFree) return; 
    if (isPeerRelay) return; 

    double score = calculateKNNMatch(myProfile['interests'], profile['interests']);
    
    setState(() {
      // Find by Endpoint ID (Direct connection) OR User ID (Mesh/Update)
      int index = -1;
      if (sourceEndpointId != null) {
        index = localMatches.indexWhere((m) => m['endpointId'] == sourceEndpointId);
      }
      if (index == -1) {
        index = localMatches.indexWhere((m) => m['id'] == id);
      }

      if (index != -1) {
        // UPDATE Existing
        localMatches[index]['id'] = id;
        localMatches[index]['name'] = profile['name'];
        localMatches[index]['score'] = score.toInt();
        localMatches[index]['interests'] = profile['interests'];
        localMatches[index]['status'] = "Matched";
        localMatches[index]['isLoading'] = false;
      } else {
        // ADD New
        localMatches.add({
          "endpointId": sourceEndpointId ?? "mesh",
          "id": id,
          "name": profile['name'],
          "score": score.toInt(),
          "interests": profile['interests'],
          "status": "Via Mesh",
          "isLoading": false
        });
      }
      localMatches.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    });
  }

  // --- 5. MATH (KNN) ---
  double calculateKNNMatch(List<dynamic> myTags, List<dynamic> peerTags) {
    Set<String> universe = {...myTags, ...peerTags}.map((e) => e.toString()).toSet();
    if (universe.isEmpty) return 0.0;
    List<int> vectorA = [];
    List<int> vectorB = [];
    for (String tag in universe) {
      vectorA.add(myTags.contains(tag) ? 1 : 0);
      vectorB.add(peerTags.contains(tag) ? 1 : 0);
    }
    double dot = 0.0, magA = 0.0, magB = 0.0;
    for (int i = 0; i < universe.length; i++) {
      dot += vectorA[i] * vectorB[i];
      magA += vectorA[i] * vectorA[i];
      magB += vectorB[i] * vectorB[i];
    }
    return (magA == 0 || magB == 0) ? 0.0 : (dot / (sqrt(magA) * sqrt(magB))) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SYNC SPACE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                isRelayRunning ? "RELAY ACTIVE" : "OFFLINE", 
                style: TextStyle(
                  color: isRelayRunning ? Colors.greenAccent : Colors.red, 
                  fontSize: 10,
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INPUTS
              Row(
                children: [
                  Expanded(child: TextField(controller: _nameController, enabled: !isFree, decoration: const InputDecoration(hintText: "Name", prefixIcon: Icon(Icons.person)))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _rollNoController, enabled: !isFree, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Roll No", prefixIcon: Icon(Icons.badge)))),
                ],
              ),
              
              const SizedBox(height: 15),
              const Text("Select Interests (Min 3)", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              // TAGS
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableTags.map((tag) {
                      bool isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: isFree ? null : (bool selected) {
                          setState(() {
                            if (selected) selectedTags.add(tag);
                            else selectedTags.remove(tag);
                          });
                        },
                        backgroundColor: const Color(0xFF161B22),
                        selectedColor: const Color(0xFF00F2FE).withValues(alpha: 0.3),
                        checkmarkColor: const Color(0xFF00F2FE),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF00F2FE) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: toggleFreeStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFree ? Colors.redAccent : (selectedTags.length >= 3 ? const Color(0xFF00F2FE) : Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isFree ? "STOP (GO TO SILENT MODE)" : "I AM FREE", 
                    style: TextStyle(
                      color: isFree ? Colors.white : Colors.black, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              Center(
                child: Text(
                  isFree ? "Visible to others" : "Silent Relay Mode (Helping others connect)",
                  style: const TextStyle(color: Colors.white24, fontSize: 12)
                ),
              ),

              const SizedBox(height: 20),
              const Text("KNN MATCHES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              
              Expanded(
                flex: 2,
                child: localMatches.isEmpty 
                  ? Center(child: Text(isFree ? "Scanning for peers..." : "Go Free to see matches", style: const TextStyle(color: Colors.white24)))
                  : ListView.builder(
                      itemCount: localMatches.length,
                      itemBuilder: (context, i) => _buildMatchTile(localMatches[i]),
                    ),
              ),
              
              // LOGS
              const Divider(color: Colors.grey),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, i) => Text(logs[i], style: const TextStyle(fontSize: 10, color: Colors.greenAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match) {
    String displayName = match['name'] ?? "Unknown";
    bool isLoading = match['isLoading'] ?? false;
    List<dynamic> interests = match['interests'] ?? [];
    
    int score = match['score'] ?? 0;
    Color scoreColor = score > 70 ? Colors.greenAccent : (score > 40 ? Colors.orangeAccent : Colors.grey);

    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scoreColor.withValues(alpha: 0.2),
              radius: 24,
              child: isLoading
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text("$score%", style: TextStyle(color: scoreColor, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 6),
                  isLoading
                   ? Text(match['status'], style: const TextStyle(color: Colors.grey, fontSize: 12))
                   : Wrap(
                       spacing: 4,
                       runSpacing: 4,
                       children: interests.take(4).map((tag) => Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                           color: Colors.white10,
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.white24)
                         ),
                         child: Text(tag.toString(), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                       )).toList(),
                     )
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX();
  }
}