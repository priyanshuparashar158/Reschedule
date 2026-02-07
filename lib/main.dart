import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gsheets/gsheets.dart';

// --- 1. CONFIGURATION ---
const String spreadsheetId = 'your credentials'; // Your Sheet ID
const String credentialsJson = r'''
{
  your credentials
}
'''; 

void main() {
  runApp(const RescheduleApp());
}

// --- 2. THEME ---
class RescheduleApp extends StatelessWidget {
  const RescheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reschedule // AI-LINK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xFFF0F6FC),
          displayColor: const Color(0xFFF0F6FC),
        ),
        useMaterial3: true,
      ),
      home: const GatewayScreen(),
    );
  }
}

// --- 3. SERVICES ---

// A. GOOGLE SHEETS MANAGER (UPDATED FOR UPPERCASE CONSISTENCY)
class GSheetsManager {
  late GSheets _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;

  Future<void> init() async {
    _gsheets = GSheets(credentialsJson);
    _spreadsheet = await _gsheets.spreadsheet(spreadsheetId);
    _worksheet = _spreadsheet!.worksheetByTitle('Sheet1') ?? await _spreadsheet!.addWorksheet('Sheet1');
  }

  // WRITE: Registers the user (Forces UPPERCASE to prevent duplicates)
  Future<void> registerMe(String id, String name, List<String> interests) async {
    // 1. Force Uppercase inputs
    final String cleanId = id.trim().toUpperCase();
    final String cleanName = name.trim().toUpperCase();
    
    final rows = await _worksheet!.values.map.allRows() ?? [];
    
    int rowIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      // Check against uppercase ID in sheet
      if (rows[i]['student_id'].toString().toUpperCase() == cleanId) {
        rowIndex = i + 2; 
        break;
      }
    }

    // Prepare row data (All Uppercase)
    final userRow = [cleanId, cleanName, interests.join(','), 'TRUE'];

    if (rowIndex != -1) {
      // Update existing row
      await _worksheet!.values.insertRow(rowIndex, userRow); 
    } else {
      // Create new row
      await _worksheet!.values.appendRow(userRow);
    }
  }

  // READ: Fetches peers (Case-insensitive matching)
  Future<List<Map<String, String>>> getPeers(String myId) async {
    final rows = await _worksheet!.values.map.allRows() ?? [];
    final String myIdClean = myId.trim().toUpperCase();

    // DEBUG PRINT
    print("DEBUG: Fetched ${rows.length} rows: $rows"); 

    return rows.where((row) {
      // 1. Get is_active safely (handle 'TRUE', 'True', 'true')
      String activeStatus = row['is_active'].toString().toLowerCase();
      bool isActive = activeStatus == 'true';
      
      // 2. Get Row ID safely & force Uppercase for comparison
      String rowId = (row['student_id'] ?? "").toString().toUpperCase().trim();

      // 3. Return only if Active AND Not Me
      return isActive && rowId != myIdClean;
    }).toList();
  }
  
  // OFFLINE: Sets user to inactive (Finds row via Uppercase ID)
  Future<void> setOffline(String id) async {
    final String cleanId = id.trim().toUpperCase();
    final rows = await _worksheet!.values.map.allRows() ?? [];
    
    int rowIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i]['student_id'].toString().toUpperCase() == cleanId) {
        rowIndex = i + 2;
        break;
      }
    }
    
    if (rowIndex != -1) {
      await _worksheet!.values.insertValue('FALSE', column: 4, row: rowIndex); 
    }
  }
}

// B. UDP DISCOVERY (Local WiFi)
class P2PService {
  RawDatagramSocket? _socket;
  final StreamController<Map<String, String>> _peerController = StreamController.broadcast();
  Stream<Map<String, String>> get peerStream => _peerController.stream;

  Future<void> start(String name) async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5005);
    _socket?.broadcastEnabled = true;
    
    _socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket?.receive();
        if (dg != null) {
          final msg = utf8.decode(dg.data);
          if (msg.startsWith("RESCHEDULE_PEER:")) {
            final pName = msg.split(":")[1];
            if (pName != name) {
               _peerController.add({'ip': dg.address.address, 'name': pName});
            }
          }
        }
      }
    });

    Timer.periodic(const Duration(seconds: 4), (t) {
      if (_socket == null) t.cancel();
      try {
        _socket?.send(utf8.encode("RESCHEDULE_PEER:$name"), InternetAddress("255.255.255.255"), 5005);
      } catch (e) {
        // silent fail
      }
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}

// C. KNN MATH
class KNN {
  static double similarity(List<String> mine, String theirsStr) {
    final theirs = theirsStr.split(',');
    final all = ["Python", "DSA", "ML", "Math", "Linear Algebra"];
    
    var vecA = all.map((i) => mine.contains(i) ? 1.0 : 0.0).toList();
    var vecB = all.map((i) => theirs.contains(i) ? 1.0 : 0.0).toList();

    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < all.length; i++) {
      dot += vecA[i] * vecB[i];
      magA += vecA[i] * vecA[i];
      magB += vecB[i] * vecB[i];
    }
    
    if (magA == 0 || magB == 0) return 0.0;
    return (dot / (sqrt(magA) * sqrt(magB))) * 100;
  }
}

// --- 4. UI SCREENS ---

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});
  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  bool isFree = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("📡 RESCHEDULE GATEWAY", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 40),
            Switch(
              value: isFree,
              activeColor: Colors.black,
              activeTrackColor: const Color(0xFF00F2FE),
              onChanged: (v) => setState(() => isFree = v),
            ),
            const SizedBox(height: 10),
            const Text("SIGNAL AVAILABILITY"),
            const SizedBox(height: 40),
            if (isFree)
              NeonButton(text: "PROCEED TO HUB", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HubScreen())))
          ],
        ),
      ),
    );
  }
}

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});
  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  // State
  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool isLoggedIn = false;
  List<String> myFocus = ["Python"];
  Map<String, String> localPeers = {}; // IP: Name
  List<Map<String, String>> cloudPeers = [];
  bool isLoading = false;
  
  Timer? _cloudSyncTimer;

  // Services
  final _p2p = P2PService();
  final _sheets = GSheetsManager();

  @override
  void dispose() {
    _p2p.stop();
    _cloudSyncTimer?.cancel();
    super.dispose();
  }

  bool _isValidRollNumber(String roll) {
    // Regex allows upper or lowercase input
    final RegExp regex = RegExp(r'^20\d{2}[kK][uU](?:[cC][pP]1\d{3}|[aA][dD]3\d{3}|[eE][cC]2\d{3})$');
    return regex.hasMatch(roll.trim());
  }

  Future<void> _connect() async {
    // 1. Validation
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a Nickname!")));
      return;
    }
    if (!_isValidRollNumber(_idCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Invalid Format! Use 20XXkuXX1XXX, 2XXX, or 3XXX"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => isLoading = true);
    
    try {
      // 2. Initialize
      await _sheets.init();
      
      // 3. WRITE ONCE (Register me as active - logic will force uppercase)
      await _sheets.registerMe(_idCtrl.text, _nameCtrl.text, myFocus);
      
      // 4. READ (Get current peers immediately)
      await _refreshCloudPeers(silent: false);

      // 5. Start UDP
      _p2p.start(_nameCtrl.text);
      _p2p.peerStream.listen((p) => setState(() => localPeers[p['ip']!] = p['name']!));

      // 6. Start Cloud Polling (READ ONLY every 10s)
      _cloudSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshCloudPeers(silent: true));

      setState(() { isLoading = false; isLoggedIn = true; });
    } catch (e) {
       setState(() => isLoading = false);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e")));
    }
  }

  // READ ONLY function
  Future<void> _refreshCloudPeers({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);
    try {
      final peers = await _sheets.getPeers(_idCtrl.text);
      if (mounted) setState(() => cloudPeers = peers);
    } catch (e) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Error: $e")));
    }
    if (!silent && mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) return _buildLogin();

    return Scaffold(
      appBar: AppBar(
        title: Text("HUB // ${_nameCtrl.text.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () => _refreshCloudPeers(silent: false)
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: () {
               _sheets.setOffline(_idCtrl.text);
               Navigator.pop(context);
            }
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LOCAL UDP
            const Text("📶 Local Mesh Nodes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (localPeers.isEmpty) 
              const Text("Scanning Local WiFi...", style: TextStyle(color: Colors.grey, fontSize: 12))
            else 
              ...localPeers.values.map((name) => PrismCard(
                child: Row(children: [
                  const Icon(Icons.wifi, color: Color(0xFF00F2FE)),
                  const SizedBox(width: 10),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Text("LOCAL", style: TextStyle(color: Colors.green))
                ])
              )),

            const Divider(height: 40, color: Color(0xFF30363D)),

            // ONLINE CLOUD
            const Text("🤖 AI-Matched Peers (Internet)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Auto-refreshing...", style: TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 10),
            
            Wrap(
              spacing: 8,
              children: ["Python", "DSA", "ML", "Math"].map((tag) => FilterChip(
                label: Text(tag),
                selected: myFocus.contains(tag),
                onSelected: (sel) {
                  setState(() => sel ? myFocus.add(tag) : myFocus.remove(tag));
                  // If interests change, update sheet immediately
                  _sheets.registerMe(_idCtrl.text, _nameCtrl.text, myFocus); 
                  _refreshCloudPeers(silent: false);
                },
                backgroundColor: const Color(0xFF21262D),
                checkmarkColor: const Color(0xFF00F2FE),
                selectedColor: const Color(0xFF00F2FE).withOpacity(0.2),
              )).toList(),
            ),
            const SizedBox(height: 20),
            
            if (isLoading) 
              const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
            else if (cloudPeers.isEmpty)
              const Text("No active peers found online.", style: TextStyle(color: Colors.grey))
            else
              ...cloudPeers.map((peer) {
                final sim = KNN.similarity(myFocus, peer['interests'] ?? "");
                return PrismCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("👤 ${peer['name']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("${sim.toStringAsFixed(1)}%", style: const TextStyle(color: Color(0xFFBC8CFF), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      NeonButton(
                        text: "⚡ LINK", 
                        small: true, 
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuccessScreen(name: peer['name']!)))
                      )
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("IDENTIFY", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 30),
            TextField(controller: _idCtrl, decoration: _fieldDeco("ROLL NUMBER"), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 15),
            TextField(controller: _nameCtrl, decoration: _fieldDeco("NICKNAME"), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 30),
            isLoading 
              ? const CircularProgressIndicator()
              : NeonButton(text: "CONNECT", onTap: _connect)
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: const Color(0xFF161B22),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
  );
}

class SuccessScreen extends StatelessWidget {
  final String name;
  const SuccessScreen({super.key, required this.name});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00F2FE), size: 80),
            const SizedBox(height: 20),
            Text("LINKED WITH ${name.toUpperCase()}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 40),
            NeonButton(text: "RETURN", onTap: () => Navigator.pop(context))
          ],
        ),
      ),
    );
  }
}

// --- 5. WIDGETS ---
class PrismCard extends StatelessWidget {
  final Widget child;
  const PrismCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withOpacity(0.8),
        border: Border.all(color: const Color(0xFF30363D)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool small;
  const NeonButton({super.key, required this.text, required this.onTap, this.small = false});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: small ? double.infinity : 200,
        height: small ? 40 : 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00F2FE), Color(0xFFBC8CFF)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
    );
  }
}