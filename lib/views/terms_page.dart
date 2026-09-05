import 'package:flutter/material.dart';

import '../services/storage_service.dart';

// Legal text versioning: bump this when the Terms/Privacy text changes so users are
// required to re-accept the updated terms.
const String _kTermsVersion = 'v1';
const String _kTermsStorageKey = 'terms_accepted_${_kTermsVersion}';

class TermsPage extends StatefulWidget {
  final StorageService storageService;
  const TermsPage({super.key, required this.storageService});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _accepted = false;
  bool _saving = false;

  // kept for backward compatibility (migrated to versioned key)
  static const _legacyStorageKey = 'terms_accepted';
  static const _storageKey = _kTermsStorageKey;

  @override
  void initState() {
    super.initState();
    _loadAccepted();
  }

  Future<void> _loadAccepted() async {
    try {
      final v = await widget.storageService.read(key: _storageKey);
      if (v == '1') {
        setState(() => _accepted = true);
        return;
      }

      final legacyValue = await widget.storageService.read(
        key: _legacyStorageKey,
      );
      if (legacyValue == '1') {
        await widget.storageService.write(key: _storageKey, value: '1');
        setState(() => _accepted = true);
      }
    } catch (_) {}
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await widget.storageService.write(key: _storageKey, value: '1');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar aceite: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Termos de Uso',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ESTE DOCUMENTO CONSTITUI OS TERMOS DE USO DO APLICATIVO ORBE ("Aplicativo").\n\n'
            '1. Aceitação dos Termos: Ao utilizar o Aplicativo, você declara que leu, compreendeu e concorda em cumprir estes Termos de Uso e nossa Política de Privacidade.\n\n'
            '2. Serviço: O Aplicativo fornece uma plataforma para postagem, compartilhamento e interação com conteúdo gerado por usuários. O serviço pode incluir funcionalidades de feed, mensagens, curtidas, reações e moderação.\n\n'
            '3. Conteúdo do Usuário: Você é o único responsável pelo conteúdo que publica. Ao enviar conteúdo, você concede ao Aplicativo uma licença não exclusiva, transferível e sublicenciável para usar, reproduzir e distribuir esse conteúdo conforme necessário para operar o serviço.\n\n'
            '4. Conduta e Moderação: Conteúdos que infrinjam direitos autorais, promovam ódio, violência ou desrespeitem a legislação serão removidos. Moderadores e administradores podem banir ou suspender contas que violem estas regras.\n\n'
            '5. Limitação de Responsabilidade: O Aplicativo é fornecido “no estado em que se encontra”. Não somos responsáveis por perdas indiretas, lucros cessantes ou danos decorrentes do uso do serviço até o limite legal aplicável.\n\n'
            '6. Alterações: Podemos atualizar estes Termos; se houver mudanças significativas, exigiremos nova aceitação através desta mesma interface.\n\n'
            '7. Lei Aplicável: Estes Termos são regidos pela legislação aplicável no país do operador do serviço, sujeito aos limites do ordenamento jurídico.\n\n'
            'Este é um resumo jurídico detalhado e não substitui aconselhamento jurídico profissional. Para a versão definitiva, consulte o departamento jurídico.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Política de Privacidade',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'POLÍTICA DE PRIVACIDADE: Nós coletamos, processamos e armazenamos informações pessoais estritamente para permitir funcionalidades essenciais do Aplicativo, incluindo criação de conta, publicação de conteúdo, e personalização do serviço.\n\n'
            'Finalidades: As informações podem ser usadas para autenticação, moderação de conteúdo, entrega de notificações e análises agregadas para melhoria do servico.\n\n'
            'Compartilhamento: Não vendemos dados de usuários. Podemos compartilhar informações com provedores de infraestrutura, parceiros de pagamento ou quando exigido por lei.\n\n'
            'Segurança: Implementamos medidas razoáveis para proteger dados, incluindo criptografia em trânsito e armazenamento protegido. Contudo, nenhum sistema é invulnerável.\n\n'
            'Direitos do Usuário: Usuários têm direito de acessar, corrigir e solicitar exclusão de seus dados nos termos da legislação aplicável.\n\n'
            'Contato: Para questões sobre privacidade, contate nosso responsável interno pela proteção de dados.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Checkbox(
                activeColor: const Color(0xFF2563EB),
                value: _accepted,
                onChanged: _accepted
                    ? null
                    : (v) {
                        if (v == true) {
                          setState(() => _accepted = true);
                        }
                      },
              ),
              const Expanded(
                child: Text(
                  'Eu li e concordo com os Termos de Uso e a Política de Privacidade.',
                  style: TextStyle(color: Color(0xFF111827)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _accepted && !_saving ? _accept : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Aceitar e Continuar'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Termos e Privacidade'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(child: content),
    );
  }
}

// A small gateway that checks the storage key and either pushes to LandingPage or shows TermsPage
class TermsGate extends StatefulWidget {
  final StorageService storageService;
  const TermsGate({super.key, required this.storageService});

  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  bool _checked = false;
  bool _accepted = false;

  // Use versioned key for gating
  static const _storageKey = _kTermsStorageKey;
  static const _onboardingKey = 'onboarding_completed';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final v = await widget.storageService.read(key: _storageKey);
      setState(() {
        _accepted = v == '1';
        _checked = true;
      });
      if (_accepted) {
        final onboarding = await widget.storageService.read(
          key: _onboardingKey,
        );
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            onboarding == '1' ? '/login' : '/onboarding',
          );
        }
      }
    } catch (_) {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_accepted) return const SizedBox.shrink();
    return TermsPage(storageService: widget.storageService);
  }
}
