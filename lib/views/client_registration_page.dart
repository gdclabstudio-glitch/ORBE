import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../providers/client_provider.dart';
import '../providers/google_auth_provider.dart';
import '../theme/app_theme.dart';

import 'package:labomba_app/widgets/user_appbar_actions.dart';

class ClientRegistrationPage extends StatefulWidget {
  const ClientRegistrationPage({super.key});

  @override
  State<ClientRegistrationPage> createState() => _ClientRegistrationPageState();
}

class _ClientRegistrationPageState extends State<ClientRegistrationPage>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Função auxiliar para validar campos obrigatórios vazios
  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, informe $fieldName.';
    }
    return null;
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

  Future<void> _showTermsDialog() async {
    setState(() {
      _hasOpenedTerms = true;
    });

    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const _TermsDialog(),
    );

    if (accepted == true) {
      setState(() {
        _acceptedTerms = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Cadastro do Comprador',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [UserAppBarActions()],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 100,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          blurRadius: 34,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.22,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Antes de comprar',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF102A43),
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Preencha seus dados. O evento é exclusivo para maiores de 18 anos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 32),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _handleGoogleSignIn,
                            icon: const Icon(
                              Icons.g_mobiledata,
                              size: 28,
                              color: AppTheme.primary,
                            ),
                            label: const Text(
                              'Continuar com o Google',
                              style: TextStyle(color: Color(0xFF0F172A)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: AppTheme.primary,
                                width: 1.4,
                              ),
                              backgroundColor: const Color(0xFFF8FBFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(color: Color(0xFFBFDBFE)),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OU PREENCHA',
                                  style: TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Color(0xFFBFDBFE)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildModernTextField(
                            controller: _nameController,
                            label: 'Nome completo',
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) =>
                                _required(value, 'seu nome completo'),
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _birthDateController,
                            label: 'Data de nascimento',
                            hint: 'DD/MM/AAAA',
                            icon: Icons.calendar_today_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_dateMask],
                            validator: (value) => _parseBirthDate() == null
                                ? 'Informe uma data válida'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _cpfController,
                            label: 'CPF',
                            hint: '000.000.000-00',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_cpfMask],
                            validator: (value) => !_isValidCPF(value)
                                ? 'Informe um CPF válido'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _phoneController,
                            label: 'Telefone',
                            hint: '(00) 00000-0000',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_phoneMask],
                            validator: (value) => _digits(value).length < 10
                                ? 'Informe um telefone válido'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _acceptedTerms
                                  ? AppTheme.primary.withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _acceptedTerms
                                    ? AppTheme.primary.withValues(alpha: 0.45)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: _hasOpenedTerms
                                      ? (v) => setState(
                                            () => _acceptedTerms = v ?? false,
                                          )
                                      : null,
                                ),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        'Li e aceito os ',
                                        style: TextStyle(
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _showTermsDialog,
                                        child: const Text(
                                          'Termos de Responsabilidade',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w700,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_hasOpenedTerms)
                            const Padding(
                              padding: EdgeInsets.only(left: 12, top: 8),
                              child: Text(
                                'Por favor, leia os termos antes de aceitar.',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(height: 32),
                          FilledButton(
                            onPressed:
                                (!_acceptedTerms || _saving) ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'CONTINUAR PARA A COMPRA',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: AppTheme.primary),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF1E3A8A)),
      ),
      validator: validator,
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

class _TermsDialog extends StatefulWidget {
  const _TermsDialog({Key? key}) : super(key: key);

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (_scrollController.position.maxScrollExtent <= 0) {
          setState(() {
            _isAtBottom = true;
          });
        }
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 20 &&
        !_scrollController.position.outOfRange) {
      if (!_isAtBottom) {
        setState(() {
          _isAtBottom = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: dart_ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.18),
                blurRadius: 32,
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
                  const Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'TERMOS DE USO',
                        style: TextStyle(
                          color: Color(0xFF102A43),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF475569)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Color(0xFFE2E8F0)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: const Text(
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
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              if (!_isAtBottom)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        color: Colors.white54,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Role até o fim para aceitar',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed:
                    _isAtBottom ? () => Navigator.pop(context, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isAtBottom ? AppTheme.primary : Colors.grey.shade800,
                  foregroundColor: _isAtBottom ? Colors.white : Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.grey.shade900,
                ),
                child: const Text(
                  'LI E CONCORDO',
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
