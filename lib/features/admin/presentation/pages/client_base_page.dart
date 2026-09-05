import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:labomba_app/core/theme/app_theme.dart';
import 'package:labomba_app/models/client.dart';
import 'package:labomba_app/providers/admin_auth_provider.dart';
import 'package:labomba_app/providers/client_provider.dart';
import 'package:labomba_app/views/user_login_page.dart';

class ClientBasePage extends StatelessWidget {
  final bool embedded;
  const ClientBasePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AdminAuthProvider>().isAuthenticated) {
      return const UserLoginPage();
    }
    return _ClientBaseContent(embedded: embedded);
  }
}

class _ClientBaseContent extends StatefulWidget {
  final bool embedded;
  const _ClientBaseContent({this.embedded = false});

  @override
  State<_ClientBaseContent> createState() => _ClientBaseContentState();
}

class _ClientBaseContentState extends State<_ClientBaseContent> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = SafeArea(
      child: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          final clients = provider.clients
              .where(
                (c) => c.fullName.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 16 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compradores cadastrados',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${provider.clients.length} cliente(s) na base',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nome',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: clients.isEmpty
                              ? const _EmptyClients()
                              : ListView.separated(
                                  itemCount: clients.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _ClientRowSimple(client: clients[index]),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Base de Clientes'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bodyContent,
    );
  }
}

class _EmptyClients extends StatelessWidget {
  const _EmptyClients();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.people_outline, size: 52, color: Colors.white38),
            SizedBox(height: 12),
            Text(
              'Nenhum cliente cadastrado ainda',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
}

class _ClientRowSimple extends StatelessWidget {
  const _ClientRowSimple({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight.withValues(alpha: .2),
            child: Text(client.fullName.substring(0, 1).toUpperCase()),
          ),
          title: Text(
            client.fullName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            client.purchaseHistory.isEmpty
                ? client.phone
                : '${client.phone} • ${client.purchaseHistory.map((p) => p.description).join(', ')}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${client.age} anos',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    client.purchaseHistory.isEmpty
                        ? 'Pendente'
                        : client.purchaseHistory.last.paymentStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: client.purchaseHistory.isEmpty
                          ? Colors.orangeAccent
                          : (client.purchaseHistory.last.paymentStatus ==
                                  'Confirmado'
                              ? Colors.greenAccent
                              : Colors.orangeAccent),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Editar',
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => _EditClientDialog(client: client),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Excluir',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar exclusão'),
                      content:
                          const Text('Deseja realmente excluir este cliente?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Excluir'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (!context.mounted) return;
                    await context
                        .read<ClientProvider>()
                        .deleteClient(client.id);
                  }
                },
                icon:
                    const Icon(Icons.delete, size: 18, color: Colors.redAccent),
              ),
            ],
          ),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => _ClientDetailsDialog(client: client),
          ),
        ),
      );
}

class _ClientDetailsDialog extends StatelessWidget {
  const _ClientDetailsDialog({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(client.fullName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailLine(label: 'Idade', value: '${client.age} anos'),
              _DetailLine(
                label: 'Data de nascimento',
                value: _date(client.birthDate),
              ),
              _DetailLine(label: 'CPF', value: client.cpf),
              _DetailLine(label: 'Telefone', value: client.phone),
              const SizedBox(height: 14),
              const Text(
                'Informações de Pagamento',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (client.purchaseHistory.isEmpty)
                const Text(
                  'Nenhuma informação de pagamento registrada.',
                  style: TextStyle(color: Colors.white60),
                )
              else
                for (final purchase in client.purchaseHistory)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(purchase.description),
                    subtitle: Text(
                      '${purchase.quantity} unidade(s) • ${_date(purchase.purchasedAt)}\nMétodo: ${purchase.paymentMethod}',
                    ),
                    trailing: Text(
                      purchase.paymentStatus,
                      style: TextStyle(
                        color: purchase.paymentStatus == 'Confirmado'
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
}

class _EditClientDialog extends StatefulWidget {
  const _EditClientDialog({required this.client});
  final Client client;

  @override
  State<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<_EditClientDialog> {
  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  late final _name = TextEditingController(text: widget.client.fullName);
  late final _birth = TextEditingController(
    text:
        '${widget.client.birthDate.day.toString().padLeft(2, '0')}/${widget.client.birthDate.month.toString().padLeft(2, '0')}/${widget.client.birthDate.year}',
  );
  late final _cpf = TextEditingController(text: widget.client.cpf);
  late final _phone = TextEditingController(text: widget.client.phone);

  @override
  void dispose() {
    _name.dispose();
    _birth.dispose();
    _cpf.dispose();
    _phone.dispose();
    super.dispose();
  }

  DateTime? _parseBirth() {
    final parts = _birth.text.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Editar cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome completo'),
            ),
            TextField(
              controller: _birth,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data de nascimento (DD/MM/AAAA)',
              ),
            ),
            TextField(
              controller: _cpf,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'CPF'),
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
              inputFormatters: [_phoneMask],
              keyboardType: TextInputType.phone,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aceitou o termo'),
              trailing: Icon(
                widget.client.acceptedTerms ? Icons.check_circle : Icons.cancel,
                color: widget.client.acceptedTerms ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final birthDate = _parseBirth();
              if (birthDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data de nascimento inválida')),
                );
                return;
              }
              await context.read<ClientProvider>().updateClient(
                    clientId: widget.client.id,
                    fullName: _name.text,
                    birthDate: birthDate,
                    cpf: _cpf.text,
                    phone: _phone.text,
                    acceptedTerms: widget.client.acceptedTerms,
                  );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
