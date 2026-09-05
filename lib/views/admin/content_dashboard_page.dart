import 'dart:io' show SocketException;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:labomba_app/widgets/user_appbar_actions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/edition.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/edition_service.dart';
import '../../theme/app_theme.dart';

class ContentDashboardPage extends StatefulWidget {
  final bool embedded;
  const ContentDashboardPage({super.key, this.embedded = false});

  @override
  State<ContentDashboardPage> createState() => _ContentDashboardPageState();
}

class _ContentDashboardPageState extends State<ContentDashboardPage> {
  late final ApiService _apiService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Obtain AuthService from Provider and create ApiService with it
    final authService = Provider.of<AuthService>(context, listen: false);
    _apiService = ApiService(authService: authService);
  }

  final _bannerTitleController = TextEditingController(
    text: 'LA BOMBA 2027 • O MAIOR CARNAVAL',
  );
  final _eventDateController = TextEditingController(
    text: '05 de Fevereiro de 2027',
  );
  final _locationController = TextEditingController(text: 'Peçanha - MG');

  final List<Edition> _galleryItems =
      const EditionService().generateHistoricalEditions();

  @override
  void dispose() {
    _bannerTitleController.dispose();
    _eventDateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _uploadMedia(String category) async {
    setState(() => _isLoading = true);
    try {
      // Simulação / Integração de upload de bytes
      final fakeBytes = <int>[0, 1, 2];
      await _apiService.uploadMedia(fakeBytes, '${category}_novo.png');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Text('Upload para $category concluído'),
        ),
      );
    } on SocketException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Falha de rede durante upload. Verifique a conexão/API: $e',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Erro no upload: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTextChanges() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.updateEventConfig({
        'title': _bannerTitleController.text.trim(),
        'date': _eventDateController.text.trim(),
        'location': _locationController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Configurações salvas com sucesso!'),
        ),
      );
    } on SocketException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Falha de rede ao salvar. Verifique a conexão/API: $e'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Erro ao salvar: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: 'Banners & Identidade Visual',
                      subtitle:
                          'Altere o banner principal e as mídias em destaque da Landing Page.',
                      icon: Icons.image_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildBannerCard(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      title: 'Textos Dinâmicos & Informações do Evento',
                      subtitle:
                          'Edite os títulos, datas e locais exibidos em tempo real no site.',
                      icon: Icons.edit_note_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextEditorCard(),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      title: 'Galeria de Fotos (Edições Anteriores)',
                      subtitle: 'Gerencie as fotos dos eventos anteriores.',
                      icon: Icons.photo_library_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildGalleryManager(),
                  ],
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Conteúdo (CMS)'),
        actions: [UserAppBarActions()],
      ),
      body: content,
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard() {
    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Banner Principal',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Altere o banner exibido na landing page. Dimensão recomendada: 1920x1080 (PNG/WebP, máx 2MB)',
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: MediaQuery.of(context).size.width > 600 ? 520 : 320,
                  height: MediaQuery.of(context).size.width > 600 ? 180 : 120,
                  color: Colors.black38,
                  child: ('assets/images/labomba_banner.png'.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: 'assets/images/labomba_banner.png',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white30,
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/labomba_banner.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white30,
                            ),
                          ),
                        )),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                onPressed: () => _uploadMedia('banner_principal'),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Substituir Banner'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextEditorCard() {
    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _bannerTitleController,
              decoration: const InputDecoration(
                labelText: 'Título Principal do Evento',
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _eventDateController,
                    decoration: const InputDecoration(
                      labelText: 'Data do Evento',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local do Evento',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveTextChanges,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar Alterações'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryManager() {
    final editions = _galleryItems;

    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemCount: editions.length,
          itemBuilder: (context, index) {
            final edition = editions[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            (edition.imageUrl.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: edition.imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Center(
                                      child: Icon(
                                        Icons.photo_library_outlined,
                                        color: Colors.white30,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    edition.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(
                                        Icons.photo_library_outlined,
                                        color: Colors.white30,
                                        size: 40,
                                      ),
                                    ),
                                  )),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.72),
                                      Colors.black.withValues(alpha: 0.08),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    edition.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${edition.year}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Atualizar imagem',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.upload_file_rounded,
                                size: 18,
                              ),
                              color: Colors.white,
                              tooltip:
                                  'Alterar imagem da edição ${edition.year}',
                              onPressed: () =>
                                  _uploadMedia('galeria_${edition.year}'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
