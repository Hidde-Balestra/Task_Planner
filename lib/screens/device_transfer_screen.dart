import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/task.dart';
import '../services/task_storage.dart';
import '../services/transfer_service.dart';

enum TransferMode { send, receive }

class DeviceTransferScreen extends StatelessWidget {
  final TransferMode mode;

  const DeviceTransferScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mode == TransferMode.send
              ? 'Versturen naar ander toestel'
              : 'Ontvangen van ander toestel',
        ),
      ),
      body: mode == TransferMode.send
          ? const _SendView()
          : const _ReceiveView(),
    );
  }
}

class _SendView extends StatefulWidget {
  const _SendView();

  @override
  State<_SendView> createState() => _SendViewState();
}

class _SendViewState extends State<_SendView> {
  String? _qrPayload;
  bool _loading = true;
  bool _noNetwork = false;
  bool _transferred = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _noNetwork = false;
      _transferred = false;
    });
    final tasks = await TaskStorage.loadTasks();
    final payload = await TransferService.startSendServer(
      tasks,
      onTransferred: () {
        if (mounted) setState(() => _transferred = true);
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _qrPayload = payload;
      _noNetwork = payload == null;
    });
  }

  @override
  void dispose() {
    TransferService.stopSendServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_noNetwork) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'Geen wifi-verbinding gevonden',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Zorg dat dit toestel verbonden is met een wifi-netwerk '
                '(of zet een mobiele hotspot aan) en probeer opnieuw. '
                'Beide toestellen moeten op hetzelfde netwerk zitten.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _start,
                child: const Text('Opnieuw proberen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transferred) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Overgedragen!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Klaar'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(data: _qrPayload!, size: 240),
          ),
          const SizedBox(height: 24),
          const Text(
            'Scan deze code met het andere toestel om al je taken over '
            'te zetten. Beide toestellen moeten op hetzelfde wifi-netwerk '
            'zitten.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'De gegevens gaan rechtstreeks tussen de toestellen via '
                  'het lokale netwerk, nooit via internet of een server.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiveView extends StatefulWidget {
  const _ReceiveView();

  @override
  State<_ReceiveView> createState() => _ReceiveViewState();
}

class _ReceiveViewState extends State<_ReceiveView> {
  bool _processing = false;

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);

    List<Task> tasks;
    try {
      tasks = await TransferService.receiveFromQrPayload(raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kon geen verbinding maken. Probeer opnieuw.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taken overzetten?'),
        content: Text(
          '${tasks.length} taken gevonden op het andere toestel. '
          'Dit vervangt alle huidige taken op dit toestel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Overzetten'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (!mounted) return;
      setState(() => _processing = false);
      return;
    }

    await TaskStorage.saveTasks(tasks);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(onDetect: _handleDetect),
        if (_processing)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Scan de QR-code die getoond wordt op het andere toestel',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
