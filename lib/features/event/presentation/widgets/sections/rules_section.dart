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
                    'Use o ORBE com respeito e responsabilidade.',
              ),
              const _RuleItem(
                text:
                    'Não compartilhe conteúdo que viole os direitos de outras pessoas.',
              ),
              const _RuleItem(
                text: 'Mantenha os espaços de convivência seguros e acolhedores.',
              ),
              const _RuleItem(
                text: 'Agressões e assédio não são permitidos.',
              ),
              const _RuleItem(
                text:
                    'Respeite os membros da comunidade e a equipe de suporte.',
              ),
              const _RuleItem(
                text:
                    'Publique apenas conteúdo que você tenha autorização para compartilhar.',
              ),
              const _RuleItem(
                text:
                    'Proteja seus dados e mantenha suas credenciais em segurança.',
              ),
              const _RuleItem(
                text: 'Use os canais de denúncia quando precisar de ajuda.',
              ),
              const _RuleItem(
                text:
                    'Consulte os Termos de Uso oficiais quando forem disponibilizados.',
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
