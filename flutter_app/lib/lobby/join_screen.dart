import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ui/theme/app_theme.dart';
import '../core/state/game_state_provider.dart';
import '../core/network/nearby_service.dart';

class JoinScreen extends ConsumerWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final nearby = ref.watch(nearbyServiceProvider);

    // Auto-Navigate wenn verbunden
    ref.listen(sessionProvider, (prev, next) {
      if (next.connectionStatus == ConnectionStatus.connected) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: SlapColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: SlapColors.neonPink),
          onPressed: () {
            nearby.disconnect();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'BEITRETEN',
          style: TextStyle(
            color: SlapColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          _buildSearchHeader(),
          const SizedBox(height: 24),
          _buildDeviceList(context, ref, nearby),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: SlapColors.neonPink.withOpacity(0.1),
            border: Border.all(color: SlapColors.neonPink.withOpacity(0.3)),
          ),
          child: const Icon(Icons.wifi_tethering, color: SlapColors.neonPink, size: 40),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms)
            .then()
            .scale(begin: const Offset(1.15, 1.15), end: const Offset(1, 1), duration: 800.ms),
        const SizedBox(height: 16),
        const Text(
          'Suche nach Spielen...',
          style: TextStyle(
            color: SlapColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Stelle sicher dass beide Geräte\nWiFi & Bluetooth aktiviert haben',
          style: TextStyle(color: SlapColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, WidgetRef ref, NearbyService nearby) {
    return StreamBuilder<List<DiscoveredDevice>>(
      stream: nearby.devicesStream,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];

        if (devices.isEmpty) {
          return Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: SlapColors.neonPink,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Noch keine Spiele gefunden',
                    style: TextStyle(color: SlapColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: devices.length,
            itemBuilder: (context, i) {
              final device = devices[i];
              return _DeviceCard(
                device: device,
                onTap: () => ref
                    .read(sessionProvider.notifier)
                    .connectToHost(device.endpointId),
              ).animate().fadeIn(delay: (i * 100).ms).slideX(begin: 0.3);
            },
          ),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SlapColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SlapColors.neonPink.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: SlapColors.neonPink.withOpacity(0.1),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: SlapColors.neonPink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gamepad, color: SlapColors.neonPink, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: SlapColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Tippen zum Verbinden',
                    style: TextStyle(
                      color: SlapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: SlapColors.neonPink, size: 16),
          ],
        ),
      ),
    );
  }
}
