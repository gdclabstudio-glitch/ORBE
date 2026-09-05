import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/la_bomba_design_system.dart';
import '../models/orb_universe.dart';
import '../models/social_orb.dart';
import '../models/universe_stack.dart';
import '../models/universe_type.dart';
import '../widgets/orb_renderer.dart';

class OrbUniversePage extends StatefulWidget {
  const OrbUniversePage({super.key, required this.initialUniverse});

  final OrbUniverse initialUniverse;

  @override
  State<OrbUniversePage> createState() => _OrbUniversePageState();
}

class _OrbUniversePageState extends State<OrbUniversePage>
    with SingleTickerProviderStateMixin {
  late UniverseStack _stack;
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _stack = UniverseStack([widget.initialUniverse]);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final universe = _stack.current!;
    return Scaffold(
      backgroundColor: LaBombaColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: LaBombaColors.textPrimary,
        title: Text(universe.title),
        leading: _stack.canGoBack
            ? IconButton(
                tooltip: 'Voltar ao universo anterior',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _stack = _stack.pop()),
              )
            : null,
      ),
      body: FadeTransition(
        opacity:
            CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(
                parent: _entryController, curve: Curves.easeOutCubic),
          ),
          child: Container(
            decoration: LaBombaDecorations.shell,
            child: Column(
              children: [
                _buildBreadcrumbs(),
                Expanded(child: _buildUniverseBody(universe)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _stack.items.length,
        separatorBuilder: (_, __) => const Icon(
          Icons.chevron_right_rounded,
          color: LaBombaColors.textMuted,
          size: 18,
        ),
        itemBuilder: (context, index) {
          final item = _stack.items[index];
          final isCurrent = index == _stack.depth - 1;
          return Semantics(
            button: !isCurrent,
            label: 'Universo ${item.title}',
            child: TextButton(
              onPressed: isCurrent
                  ? null
                  : () => setState(() => _stack = _stack.popTo(index)),
              style: TextButton.styleFrom(
                foregroundColor: isCurrent
                    ? LaBombaColors.textPrimary
                    : LaBombaColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(item.title),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUniverseBody(OrbUniverse universe) {
    final centerTitle = universe.center.title?.trim().isNotEmpty == true
        ? universe.center.title!
        : universe.title;
    return Center(
      child: Semantics(
        label: '${universe.title}, universo ${universe.type.name}',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContextHeader(universe),
              const SizedBox(height: 24),
              _UniverseCenterOrb(
                title: centerTitle,
                imageUrl: universe.center.imageUrl,
              ),
              const SizedBox(height: 22),
              Text(
                universe.title,
                style: const TextStyle(
                  color: LaBombaColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (universe.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  universe.subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LaBombaColors.textMuted),
                ),
              ],
              if (universe.context?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  universe.context!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LaBombaColors.textMuted),
                ),
              ],
              if (!universe.isEmpty) ...[
                const SizedBox(height: 20),
                _buildContextOrbs(universe.orbs),
              ],
              const SizedBox(height: 18),
              Text(
                universe.isEmpty
                    ? _emptyMessage(universe.type)
                    : '${universe.orbs.length} conexões orbitando',
                style: const TextStyle(color: LaBombaColors.textSecondary),
              ),
              if (_stack.depth > 1) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => setState(() => _stack = _stack.pop()),
                  icon: const Icon(Icons.keyboard_return_rounded),
                  label: const Text('Voltar ao universo anterior'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextOrbs(List<SocialOrb> orbs) {
    return SizedBox(
      width: 300,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int index = 0; index < orbs.length; index++)
            Positioned(
              left: 150 + math.cos(index * 2.4) * 92 - 28,
              top: 75 + math.sin(index * 2.4) * 44 - 28,
              child: OrbRenderer(
                orb: orbs[index],
                isSelected: false,
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContextHeader(OrbUniverse universe) {
    final parent = _stack.parent;
    return Column(
      children: [
        Text(
          _universeTypeLabel(universe.type),
          style: const TextStyle(
            color: LaBombaColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          parent == null ? 'Seu contexto agora' : 'Dentro de ${parent.title}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: LaBombaColors.textMuted),
        ),
      ],
    );
  }

  String _universeTypeLabel(UniverseType type) {
    switch (type) {
      case UniverseType.personal:
        return 'UNIVERSO PESSOAL';
      case UniverseType.community:
        return 'UNIVERSO DE COMUNIDADE';
      case UniverseType.group:
        return 'UNIVERSO DE GRUPO';
      case UniverseType.topic:
        return 'UNIVERSO DE TÓPICO';
      case UniverseType.event:
        return 'UNIVERSO DE EVENTO';
    }
  }

  String _emptyMessage(UniverseType type) {
    switch (type) {
      case UniverseType.personal:
        return 'Seu universo ainda está começando.';
      case UniverseType.community:
        return 'Esta comunidade ainda está começando.';
      case UniverseType.group:
        return 'Este grupo ainda está começando.';
      case UniverseType.topic:
        return 'Este tópico ainda está começando.';
      case UniverseType.event:
        return 'Este evento ainda está começando.';
    }
  }
}

class _UniverseCenterOrb extends StatelessWidget {
  const _UniverseCenterOrb({required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 126,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [LaBombaColors.primary, LaBombaColors.digitalBlue],
        ),
        boxShadow: [
          BoxShadow(
            color: LaBombaColors.primary.withValues(alpha: 0.28),
            blurRadius: 30,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(imageUrl!, fit: BoxFit.cover)
            : Container(
                color: LaBombaColors.surfaceElevated,
                alignment: Alignment.center,
                child: Text(
                  title.isEmpty ? '?' : title[0].toUpperCase(),
                  style: const TextStyle(
                    color: LaBombaColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}
