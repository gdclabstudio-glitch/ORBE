import 'dart:ui';

import 'package:flutter/material.dart';

class RulesSection extends StatelessWidget {
  const RulesSection({super.key});

  void _showRulesModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const _RulesModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _showRulesModal(context),
        icon: const Icon(Icons.info_outline_rounded, color: Colors.white70),
        label: const Text(
          'TERMOS E REGRAS DO BLOCO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}

class _RulesModal extends StatelessWidget {
  const _RulesModal();

  @override
  Widget build(BuildContext context) {
    const Color summerOrange = Color(0xFFFF8C00);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF130A2A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: summerOrange.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: summerOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'REGRAS OFICIAIS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white24),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _RuleItem(
                        text:
                            'Uso exclusivo e intransferível de abadás, pulseiras e canecas oficiais!',
                      ),
                      _RuleItem(
                        text:
                            'Proibido Compartilhar Bebida: Passível de expulsão. Servidores do bloco têm autoridade para cortar a pulseira em caso de descumprimento.',
                      ),
                      _RuleItem(
                        text: 'Proibido Fumar: Dentro da área de concentração.',
                      ),
                      _RuleItem(
                        text:
                            'Tolerância Zero para Brigas: Passível de expulsão.',
                      ),
                      _RuleItem(
                        text:
                            'Respeito Obrigatório: Aos garçons, seguranças e servidores do bloco.',
                      ),
                      _RuleItem(
                        text:
                            'Entrada na concentração apenas com abadá, pulseira e caneca oficiais. Proibido uso de materiais de outros modelos ou marcas.',
                      ),
                      _RuleItem(
                        text:
                            'Responsabilidade do Material: A organização não se responsabiliza pela troca de materiais perdidos (caneca, pulseira ou abadá).',
                      ),
                      _RuleItem(
                        text: 'Banheiro do Bloco: Exclusivo para mulheres.',
                      ),
                      _RuleItem(
                        text:
                            'Gelo Saborizado Inteligente: Monitoramento digital e visual por garçons e organizadores. O gelo permanece inteiro por 3 a 4 rodadas, sem necessidade de reposição neste intervalo.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: summerOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'EU ENTENDI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 16),
            child: Icon(
              Icons.priority_high_rounded,
              color: Color(0xFFFF8C00),
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
