import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design_system/app_widgets.dart';
import '../../data/providers.dart';
import '../../domain/repositories/repositories.dart';
import '../../core/errors_user_facing.dart';

class ReportHelpScreen extends ConsumerStatefulWidget {
  final String? targetType;
  final String? targetId;
  const ReportHelpScreen({super.key, this.targetType, this.targetId});

  @override
  ConsumerState<ReportHelpScreen> createState() => _ReportHelpScreenState();
}

class _ReportHelpScreenState extends ConsumerState<ReportHelpScreen> {
  final _description = TextEditingController();
  String _category = 'safety';
  bool _sending = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(myReportsProvider);
    final repository = ref.watch(safetyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/settings'),
        title: const Text('Rapportering og hjelp'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rapporter noe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Rapporter sikkerhet, trakassering, spam eller annet som bør vurderes.'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: const [
                      DropdownMenuItem(value: 'safety', child: Text('Sikkerhet / uønsket adferd')),
                      DropdownMenuItem(value: 'harassment', child: Text('Trakassering')),
                      DropdownMenuItem(value: 'spam', child: Text('Spam / misbruk')),
                      DropdownMenuItem(value: 'content', child: Text('Innhold')),
                      DropdownMenuItem(value: 'other', child: Text('Annet')),
                    ],
                    onChanged: (value) => setState(() => _category = value ?? 'other'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: 'Beskrivelse', hintText: 'Hva har skjedd?'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending || repository == null ? null : () => _submit(repository),
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.flag_outlined),
                      label: Text(repository == null ? 'Krever innlogget konto' : 'Send rapport'),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                const ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Hjelp'),
                  subtitle: Text('Ved akutt fare: kontakt lokale nødetater. WayCrew er ikke en nød- eller redningstjeneste.'),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Kontakt WayCrew-support'),
                  subtitle: const Text('rengelse@outlook.com'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri(
                    scheme: 'mailto',
                    path: 'rengelse@outlook.com',
                    queryParameters: {'subject': 'WayCrew support'},
                  )),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Mine rapporter', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            reports.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (error, _) => Text(userFacingError(error, fallback: 'Kunne ikke hente rapporthistorikken.')),
              data: (items) {
                if (items.isEmpty) {
                  return const Card(child: ListTile(title: Text('Ingen rapporter sendt.')));
                }
                return Column(
                  children: items.map((item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(_categoryLabel(item.category)),
                      subtitle: Text('${item.description}\nStatus: ${_statusLabel(item.status)}'),
                      isThreeLine: true,
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(SafetyRepository repository) async {
    final description = _description.text.trim();
    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beskriv hendelsen litt mer før du sender.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await repository.submitReport(
        category: _category,
        description: description,
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      _description.clear();
      ref.invalidate(myReportsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapporten er sendt.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingError(error, fallback: 'Kunne ikke sende rapporten. Prøv igjen.'))));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  static String _categoryLabel(String value) => switch (value) {
        'safety' => 'Sikkerhet / uønsket adferd',
        'harassment' => 'Trakassering',
        'spam' => 'Spam / misbruk',
        'content' => 'Innhold',
        _ => 'Annet',
      };

  static String _statusLabel(String value) => switch (value) {
        'reviewing' => 'Under vurdering',
        'resolved' => 'Behandlet',
        'dismissed' => 'Avsluttet',
        _ => 'Mottatt',
      };
}
