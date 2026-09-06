import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    const maxWidth = 900.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Política de Privacidade',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esta Política de Privacidade descreve, de forma transparente e completa, como o aplicativo ORBE coleta, usa, compartilha, protege e conserva dados pessoais e informações de uso relacionadas à operação do serviço. O presente documento aplica-se a usuários, convidados, administradores e parceiros quando interagem com a plataforma, incluindo cadastro, autenticação, publicação de conteúdo, mensagens, interações sociais, notificações e acesso a áreas restritas.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '1. Informações que coletamos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Coletamos informações que você fornece diretamente ao usar o aplicativo, como nome, e-mail, telefone, data de nascimento, perfil de usuário, conteúdo publicado, fotos, vídeos, comentários, reações, mensagens privadas, preferências, histórico de interações e dados de participação no evento. Também coletamos dados de uso e operação, como logs de acesso, data e hora de autenticação, informações técnicas do dispositivo e registros de atividade funcional para melhorar a experiência, a segurança e o diagnóstico de erros.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '2. Finalidades do tratamento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'As informações podem ser tratadas para operar, manter e melhorar a plataforma; autenticar usuários; permitir acesso a conteúdo, fluxos e serviços do evento; personalizar a experiência; enviar notificações, lembretes e comunicações relevantes; prevenir fraudes, abuso, spam, conteúdo impróprio ou atividades que violem nossos termos; gerar estatísticas agregadas e relatórios operacionais; cumprir obrigações legais e registrar consentimentos e autorizações quando necessários.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '3. Compartilhamento com terceiros',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Não vendemos dados pessoais. Podemos compartilhar informações com provedores de infraestrutura, autenticação, armazenamento, análise, notificações, mensageria, suporte operacional e hospedagem necessários para o funcionamento do aplicativo, sempre sob contratos e políticas de segurança adequadas. Em alguns casos, dados podem ser revelados quando exigido por lei, ordem judicial, investigação de segurança ou proteção dos direitos e da segurança dos usuários ou da própria plataforma.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '4. Segurança e retenção',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adotamos medidas técnicas e organizacionais razoáveis para proteger os dados contra acesso não autorizado, uso indevido, perda, alteração ou destruição. No entanto, nenhuma plataforma digital é totalmente imune a incidentes de segurança. Os dados serão mantidos apenas pelo período necessário para cumprir as finalidades do serviço, respeitando prazos legais, obrigações fiscais, regulatórias e necessidades de auditoria, suporte e moderação.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '5. Seus direitos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Você pode solicitar acesso, correção, atualização, exclusão ou portabilidade de seus dados, conforme a legislação aplicável e os mecanismos disponíveis na plataforma. Também pode revogar consentimentos, limitar o uso de certos dados ou solicitar informações sobre nossas práticas de processamento. Para exercer esses direitos, utilizar os canais de suporte do aplicativo ou entrar em contato com o responsável pela privacidade da operação.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '6. Atualizações desta política',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta Política pode ser atualizada para refletir melhorias legais, operacionais ou de segurança. Quando houver mudança material, o aplicativo poderá exigir nova confirmação de aceite para manter o usuário informado e alinhado com os termos vigentes. O uso contínuo do serviço após a publicação da versão atualizada implica concordância com a nova política.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Contato: suporte@orbe.app',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
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
