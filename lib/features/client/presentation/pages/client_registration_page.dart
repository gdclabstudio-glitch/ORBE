import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'package:labomba_app/providers/client_provider.dart';
import 'package:labomba_app/providers/google_auth_provider.dart';
import 'package:labomba_app/core/theme/app_theme.dart';

class ClientRegistrationPage extends StatefulWidget {
  const ClientRegistrationPage({super.key});

  @override
  State<ClientRegistrationPage> createState() => _ClientRegistrationPageState();
}

class _ClientRegistrationPageState extends State<ClientRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  bool _acceptedTerms = false;
  bool _hasOpenedTerms = false;

  final _dateMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  DateTime? _parseBirthDate() {
    final parts = _birthDateController.text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null || year < 1900) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  int _age(DateTime birthDate) {
    final today = DateTime.now();
    var years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final birthDate = _parseBirthDate();
    if (birthDate == null) return;
    if (_age(birthDate) < 18) {
      await _showAdultRestrictionDialog();
      return;
    }

    setState(() => _saving = true);
    try {
      final client = await context.read<ClientProvider>().registerClient(
            fullName: _nameController.text,
            birthDate: birthDate,
            cpf: _cpfController.text,
            phone: _phoneController.text,
            acceptedTerms: _acceptedTerms,
          );
      if (!mounted) return;
      Navigator.pop(context, client);
    } on ClientRegistrationException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final googleProvider = context.read<GoogleAuthProvider>();
    try {
      final googleData = await googleProvider.signInWithGoogle();
      if (!mounted) return;
      if (googleData == null) return; // User cancelled

      setState(() {
        _nameController.text = googleData.displayName ?? '';
      });
      _showMessage(
        'Conta Google vinculada com sucesso. Complete os dados restantes.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Erro ao acessar o Google. Tente novamente.');
    }
  }

  Future<void> _showAdultRestrictionDialog() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.accent,
            size: 36,
          ),
          title: const Text('Cadastro não permitido'),
          content: const Text(
            'O evento é restrito para maiores de 18 anos. '
            'Não é possível concluir o cadastro ou a compra.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTermsDialog() {
    setState(() {
      _hasOpenedTerms = true;
    });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termos de Responsabilidade'),
        content: const SingleChildScrollView(
          child: Text(
            'TERMOS DE USO, POLÍTICA DE ACESSO E REGRAS DO BLOCO – Bloco La Bomba\n\n'
            'Ao adquirir o ingresso para o Bloco La Bomba através deste sistema oficial e/ou ao fazer uso do abadá, caneca e pulseira, o Comprador/Folião ("Usuário") declara ter lido, compreendido e aceitado de forma expressa, irrevogável e irretratável todas as cláusulas, políticas de segurança e regras de conduta descritas abaixo:\n\n'
            '1. DA IDENTIDADE E RESPONSABILIDADE JURÍDICA DA PLATAFORMA E DO BLOCO\n'
            '1.1. O presente sistema e o Bloco La Bomba constituem uma operação unificada sob a responsabilidade de seus organizadores e desenvolvedores.\n'
            '1.2. O Usuário isenta integralmente os organizadores, produtores, equipe técnica e desenvolvedores do sistema de qualquer responsabilidade civil ou penal por danos materiais, corporais ou morais decorrentes de acidentes, tumultos, brigas, furtos, roubos ou casos fortuitos ocorridos antes, durante ou após a realização do bloco, ressalvadas as obrigações legais diretas da organização.\n\n'
            '2. DO KIT DO FOLIÃO E REGRAS DE ACESSO\n'
            '2.1. O ingresso dá direito à participação no Bloco La Bomba pelo período contratado, mediante o recebimento do Kit do Folião, composto por: Abadá, Caneca e Pulseira oficiais.\n'
            '2.2. Uso exclusivo e intransferível de abadás, pulseiras e canecas oficiais!\n'
            '2.3. Entrada na concentração apenas com abadá, pulseira e caneca oficiais. É terminantemente proibido o uso de materiais de outros modelos ou marcas.\n'
            '2.4. Responsabilidade do Material: A organização não se responsabiliza pela troca de materiais perdidos (caneca, pulseira ou abadá). A perda de qualquer um dos itens não gera direito à reposição gratuita ou emissão de segunda via.\n\n'
            '3. POLÍTICA DE CONSUMO, BEBIDAS E COMPARTILHAMENTO\n'
            '3.1. O bloco poderá disponibilizar bebidas (como cerveja, vodka, tequila e correlatos) exclusivamente aos portadores legítimos do kit oficial.\n'
            '3.2. Proibido Compartilhar Bebida: Passível de expulsão. Os servidores e seguranças do bloco têm total autoridade para cortar a pulseira em caso de descumprimento.\n'
            '3.3. Gelo Saborizado Inteligente: Monitoramento digital e visual por garçons e organizadores. O gelo permanece inteiro por 3 a 4 rodadas, sem necessidade de reposição neste intervalo.\n'
            '3.4. É terminantemente proibida a venda ou fornecimento de bebidas alcoólicas para menores de 18 (dezoito) anos. A organização reserva-se o direito de recusar o fornecimento de álcool a participantes com sinais extremos de embriaguez ou comportamento inadequado.\n\n'
            '4. CÓDIGO DE CONDUTA, SEGURANÇA E TOLERÂNCIA ZERO\n'
            '4.1. Tolerância Zero para Brigas: Qualquer ato de agressão física ou verbal é passível de expulsão imediata do evento, sem direito a reembolso.\n'
            '4.2. Respeito Obrigatório: Aos garçons, seguranças, organizadores e demais servidores do bloco.\n'
            '4.3. Proibido Fumar: Dentro da área de concentração do bloco.\n'
            '4.4. Banheiro do Bloco: Exclusivo para mulheres.\n'
            '4.5. O folião concorda expressamente em submeter-se a revistas de segurança na entrada, visando impedir o porte de armas, objetos cortantes, garrafas de vidro de fora ou substâncias ilícitas. O descumprimento das normas de segurança acarreta expulsão com apoio de força policial, se necessário.\n\n'
            '5. DIREITO DE IMAGEM E VOZ\n'
            '5.1. Ao participar do Bloco La Bomba, o Usuário cede de forma gratuita, irrevogável e definitiva seus direitos de imagem e voz para fins de divulgação, materiais promocionais, redes sociais e vídeos oficiais, sem gerar direito a qualquer cachê ou indenização futura.\n\n'
            '6. CANCELAMENTOS E LEGISLAÇÃO (CDC)\n'
            '6.1. O direito de arrependimento (Art. 49 do CDC) é garantido pelo prazo de até 7 (sete) dias corridos após a compra, desde que formalizado até 48 horas antes do primeiro dia do evento.\n'
            '6.2. Ausências ("No-show"), expulsões por infração às regras ou desistências posteriores não dão direito a qualquer tipo de reembolso.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.white70),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? 'Informe $label' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro do comprador')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    color: AppTheme.accent,
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Antes de comprar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preencha seus dados. O cadastro é obrigatório e o evento é exclusivo para maiores de 18 anos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _saving ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.account_circle),
                    label: const Text('Continuar com o Google'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OU',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => _required(value, 'seu nome completo'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _birthDateController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_dateMask],
                    decoration: const InputDecoration(
                      labelText: 'Data de nascimento',
                      hintText: 'DD/MM/AAAA',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (value) => _parseBirthDate() == null
                        ? 'Informe uma data válida (DD/MM/AAAA)'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cpfMask],
                    decoration: const InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) =>
                        !_isValidCPF(value) ? 'Informe um CPF válido' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_phoneMask],
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      hintText: '(00) 00000-0000',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => _digits(value).length < 10
                        ? 'Informe um telefone válido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        onChanged: _hasOpenedTerms
                            ? (v) => setState(() => _acceptedTerms = v ?? false)
                            : null,
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            const Text('Li e aceito os '),
                            GestureDetector(
                              onTap: _showTermsDialog,
                              child: const Text(
                                'Termos de Responsabilidade',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_hasOpenedTerms)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        'Você precisa abrir e ler os termos antes de marcar a caixa.',
                        style: TextStyle(
                          color: Colors.amber.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: (!_acceptedTerms || _saving) ? null : _submit,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: const Text('CONTINUAR PARA A COMPRA'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _digits(String? value) => (value ?? '').replaceAll(RegExp(r'\D'), '');

bool _isValidCPF(String? cpf) {
  if (cpf == null || cpf.isEmpty) return false;

  String numbers = cpf.replaceAll(RegExp(r'[^0-9]'), '');

  if (numbers.length != 11) return false;

  if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

  List<int> digits = numbers.split('').map(int.parse).toList();

  int calc1 = 0;
  for (int i = 0; i < 9; i++) {
    calc1 += digits[i] * (10 - i);
  }
  calc1 = (calc1 * 10) % 11;
  if (calc1 == 10) {
    calc1 = 0;
  }
  if (digits[9] != calc1) return false;

  int calc2 = 0;
  for (int i = 0; i < 10; i++) {
    calc2 += digits[i] * (11 - i);
  }
  calc2 = (calc2 * 10) % 11;
  if (calc2 == 10) {
    calc2 = 0;
  }
  if (digits[10] != calc2) return false;

  return true;
}
