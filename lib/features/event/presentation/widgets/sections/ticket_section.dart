// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:labomba_app/providers/shop_provider.dart';
import 'package:labomba_app/providers/client_provider.dart';
import 'package:labomba_app/models/client.dart';
import 'package:labomba_app/core/theme/app_theme.dart';

class AppStyles {
  static TextStyle labombaTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize ?? 14,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: letterSpacing ?? 0,
      height: height,
      color: color ?? Colors.white,
    );
  }
}

class TicketSection extends StatefulWidget {
  const TicketSection({super.key});

  @override
  State<TicketSection> createState() => _TicketSectionState();
}

class _TicketSectionState extends State<TicketSection> {
  bool _isHovered = false;

  Future<Client?> _ensureClient(BuildContext context) async {
    final client = await Navigator.pushNamed(context, '/register');
    return client as Client?;
  }

  Future<void> _finalizePurchase(
    BuildContext context,
    Client client,
    String paymentMethod,
  ) async {
    final shop = context.read<ShopProvider>();
    final available = shop.lots.firstWhere(
      (l) => l.active && l.remaining > 0,
      orElse: () => throw Exception('sem disponibilidade'),
    );

    final success = await shop.registerSale(available.id, quantity: 1);
    if (!success) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar o pedido - lote esgotado.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    const status = 'Pendente';
    final purchase = ClientPurchase(
      description: available.name,
      quantity: 1,
      amount: available.price,
      purchasedAt: DateTime.now(),
      paymentMethod: paymentMethod,
      paymentStatus: status,
    );

    final clientProvider = context.read<ClientProvider>();
    await clientProvider.addPurchase(client.id, purchase);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pedido registrado! Aguardando confirmação de pagamento.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context) async {
    final client = await _ensureClient(context);
    if (client == null || !context.mounted) return;

    final success = await context.read<ShopProvider>().launchWhatsApp();
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Não foi possível abrir o WhatsApp.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await _finalizePurchase(context, client, 'WhatsApp');
  }

  Future<void> _handleSitePayment(BuildContext context) async {
    final client = await _ensureClient(context);
    if (client == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Redirecionando para o Mercado Pago... (Integração pendente)',
        ),
        backgroundColor: const Color(0xFF009EE3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    await _finalizePurchase(context, client, 'Mercado Pago');
  }

  @override
  Widget build(BuildContext context) {
    final ticket = context.read<ShopProvider>().ticket;
    final scale = _isHovered ? 1.02 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2D1B69),
              _isHovered ? const Color(0xFF37207D) : const Color(0xFF1A123D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: _isHovered ? 0.6 : 0.2),
            width: _isHovered ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  ticket.badge,
                  style: AppStyles.labombaTextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: AppTheme.accent, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              ticket.description,
              textAlign: TextAlign.center,
              style: AppStyles.labombaTextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ticket.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'R\$',
                  style: TextStyle(
                    fontSize: 24,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ticket.price.toStringAsFixed(0),
                  style: AppStyles.labombaTextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  ',00',
                  style: TextStyle(fontSize: 24, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 40),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 400;

                final siteButton = SizedBox(
                  height: 65,
                  width: isCompact ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSitePayment(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009EE3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.payment, size: 24),
                    label: Text(
                      'PAGAR NO SITE',
                      style: AppStyles.labombaTextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                );

                final whatsappButton = SizedBox(
                  height: 65,
                  width: isCompact ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePurchase(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble, size: 24),
                    label: Text(
                      'VIA WHATSAPP',
                      style: AppStyles.labombaTextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                );

                if (isCompact) {
                  return Column(
                    children: [
                      siteButton,
                      const SizedBox(height: 16),
                      whatsappButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: siteButton),
                    const SizedBox(width: 16),
                    Expanded(child: whatsappButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
