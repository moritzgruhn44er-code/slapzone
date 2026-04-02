import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../ui/theme/app_theme.dart';
import '../core/state/game_state_provider.dart';
import '../core/network/nearby_service.dart';
import 'game_select_screen.dart';
import 'join_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _nameController = TextEditingController(text: 'Player');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: SlapColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 48),
              _buildNameField(),
              const SizedBox(height: 32),
              if (session.connectionStatus == ConnectionStatus.idle) ...[
                _buildHostButton(),
                const SizedBox(height: 16),
                _buildJoinButton(),
              ],
              if (session.connectionStatus == ConnectionStatus.advertising)
                _buildWaitingCard(),
              if (session.connectionStatus == ConnectionStatus.connected)
                _buildConnectedCard(session),
              const SizedBox(height: 32),
              _buildLatencyBadge(session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          '👋',
          style: const TextStyle(fontSize: 72),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [SlapColors.neonBlue, SlapColors.neonPink],
          ).createShader(bounds),
          child: const Text(
            'SLAPZONE',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 6,
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),
        const SizedBox(height: 8),
        const Text(
          'LOCAL MULTIPLAYER',
          style: TextStyle(
            fontSize: 13,
            color: SlapColors.textSecondary,
            letterSpacing: 4,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SlapColors.neonBlue.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _nameController,
        style: const TextStyle(
          color: SlapColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          hintText: 'Dein Name',
          hintStyle: TextStyle(color: SlapColors.textMuted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(Icons.person, color: SlapColors.neonBlue),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildHostButton() {
    return SlapButton(
      label: '🎮  SPIEL ERSTELLEN',
      color: SlapColors.neonBlue,
      onTap: () {
        final name = _nameController.text.trim().isEmpty
            ? 'Player 1'
            : _nameController.text.trim();
        ref.read(sessionProvider.notifier).setHost(name);
      },
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildJoinButton() {
    return SlapButton(
      label: '🔍  SPIEL BEITRETEN',
      color: SlapColors.neonPink,
      onTap: () {
        final name = _nameController.text.trim().isEmpty
            ? 'Player 2'
            : _nameController.text.trim();
        ref.read(sessionProvider.notifier).setClient(name);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JoinScreen()),
        );
      },
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3);
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SlapColors.neonBlue.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: SlapColors.neonBlue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: SlapColors.neonBlue,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Warte auf Spieler...',
            style: TextStyle(
              color: SlapColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anderer Spieler muss "Beitreten" drücken',
            style: TextStyle(color: SlapColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildConnectedCard(SessionState session) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SlapColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SlapColors.neonGreen.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: SlapColors.neonGreen.withOpacity(0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: SlapColors.neonGreen, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Verbunden! 🎉',
            style: TextStyle(
              color: SlapColors.neonGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _playerChip(session.player1?.name ?? '?', SlapColors.neonBlue),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('VS', style: TextStyle(
                  color: SlapColors.textSecondary,
                  fontWeight: FontWeight.w900,
                )),
              ),
              _playerChip(session.player2?.name ?? '?', SlapColors.neonPink),
            ],
          ),
          const SizedBox(height: 20),
          if (session.isHost)
            SlapButton(
              label: '▶  SPIEL WÄHLEN',
              color: SlapColors.neonGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GameSelectScreen()),
              ),
            ),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _playerChip(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildLatencyBadge(SessionState session) {
    if (!session.isConnected) return const SizedBox.shrink();
    final ms = session.latencyMs;
    final color = ms < 50
        ? SlapColors.neonGreen
        : ms < 100
            ? SlapColors.neonYellow
            : SlapColors.neonPink;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.network_ping, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '${ms}ms',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Shared Button Widget ──────────────────────────────────────────────────
class SlapButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const SlapButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<SlapButton> createState() => _SlapButtonState();
}

class _SlapButtonState extends State<SlapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
