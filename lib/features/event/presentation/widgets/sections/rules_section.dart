import 'dart:ui';

import 'package:flutter/material.dart';

class RulesSection extends StatelessWidget {
  const RulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const Color summerOrange = Color(0xFFFF8C00);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: summerOrange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: summerOrange.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: summerOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'LEITURA OBRIGATÓRIA: REGRAS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const _RuleItem(
                text:
                    'Uso exclusivo e intransferível de abadás, pulseiras e canecas oficiais!',
              ),
              const _RuleItem(
                text:
                    'Proibido Compartilhar Bebida: Passível de expulsão. Servidores do bloco têm autoridade para cortar a pulseira em caso de descumprimento.',
              ),
              const _RuleItem(
                text: 'Proibido Fumar: Dentro da área de concentração.',
              ),
              const _RuleItem(
                text: 'Tolerância Zero para Brigas: Passível de expulsão.',
              ),
              const _RuleItem(
                text:
                    "Respeito Obrigatório: Aos garçons, seguranças e servidores do bloco.",
              ),
              const _RuleItem(
                text:
                    'Entrada na concentração apenas com abadá, pulseira e caneca oficiais. Proibido uso de materiais de outros modelos ou marcas.',
              ),
              const _RuleItem(
                text:
                    'Responsabilidade do Material: A organização não se responsabiliza pela troca de materiais perdidos (caneca, pulseira ou abadá).',
              ),
              const _RuleItem(
                text: 'Banheiro do Bloco: Exclusivo para mulheres.',
              ),
              const _RuleItem(
                text:
                    'Gelo Saborizado Inteligente: Monitoramento digital e visual por garçons e organizadores. O gelo permanece inteiro por 3 a 4 rodadas, sem necessidade de reposição neste intervalo.',
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2, right: 16),
            child: Icon(
              Icons.priority_high_rounded,
              color: Color(0xFFFF8C00),
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
