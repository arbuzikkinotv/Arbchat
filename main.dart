// Minimal Arbchar Bluetooth chat (Android-only).
// Uses flutter_bluetooth_serial ^0.4.0
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const ArbcharApp());

class ArbcharApp extends StatelessWidget {
  const ArbcharApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arbchar',
      theme: ThemeData.dark(),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _devices = [];
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    FlutterBluetoothSerial.instance.state.then((s) {
      setState(() => _bluetoothState = s);
    });
    FlutterBluetoothSerial.instance.onStateChanged().listen((s) {
      setState(() => _bluetoothState = s);
    });
    _loadBonded();
  }

  Future<void> _requestPermissions() async {
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> _loadBonded() async {
    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => _devices = bonded);
    } catch (e) {
      debugPrint('Error getBonded: $e');
    }
  }

  Future<void> _startDiscovery() async {
    await _requestPermissions();
    setState(() {
      _discovering = true;
      _devices = [];
    });
    FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      final d = r.device;
      if (!_devices.any((x) => x.address == d.address)) {
        setState(() => _devices.add(d));
      }
    }).onDone(() {
      setState(() => _discovering = false);
    });
  }

  Widget _deviceTile(BluetoothDevice d) {
    return ListTile(
      leading: const Icon(Icons.devices),
      title: Text(d.name ?? 'Unknown'),
      subtitle: Text(d.address ?? ''),
      trailing: ElevatedButton(
        child: const Text('Chat'),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(device: d)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arbchar — Devices')),
      body: Column(
        children: [
          ListTile(
            title: Text('Bluetooth: $_bluetoothState'),
            trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBonded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _discovering ? null : _startDiscovery,
                  child: Text(_discovering ? 'Scanning...' : 'Scan'),
                ),
                const SizedBox(width:12),
                ElevatedButton(
                  onPressed: () async {
                    final enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
                    if (!enabled) {
                      await FlutterBluetoothSerial.instance.requestEnable();
                    } else {
                      await FlutterBluetoothSerial.instance.requestDisable();
                    }
                    _loadBonded();
                  },
                  child: const Text('Toggle BT'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (c, i) => _deviceTile(_devices[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final BluetoothDevice device;
  const ChatPage({super.key, required this.device});
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  BluetoothConnection? _connection;
  bool _connecting = true;
  final List<_Msg> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<Uint8List>? _sub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      _connection = await BluetoothConnection.toAddress(widget.device.address);
      setState(() => _connecting = false);
      _sub = _connection!.input!.listen(_onDataReceived).onDone(() {
        debugPrint('Disconnected');
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Connect error: $e');
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _onDataReceived(Uint8List data) {
    final text = utf8.decode(data);
    setState(() => _messages.add(_Msg(text: text, isMe: false)));
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _connection == null) return;
    try {
      _connection!.output.add(utf8.encode(text));
      await _connection!.output.allSent;
      setState(() => _messages.add(_Msg(text: text, isMe: true)));
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds:100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds:200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _connection?.dispose();
    super.dispose();
  }

  Widget _bubb(_Msg m) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal:12, vertical:6),
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: m.isMe ? Colors.tealAccent.withOpacity(0.12) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(m.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat — ${widget.device.name ?? widget.device.address}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: _messages.length,
              itemBuilder: (c,i) => _bubb(_messages[i]),
            ),
          ),
          const Divider(height:1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal:8, vertical:6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration.collapsed(hintText: _connecting ? 'Connecting...' : 'Type a message...'),
                    enabled: !_connecting && (_connection?.isConnected ?? false),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg { final String text; final bool isMe; _Msg({required this.text, required this.isMe}); }
