import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/offline/entity_registry.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/invoice_repository.dart';

/// Création facture (proforma ou définitive) pour une réservation (V4)
class InvoiceCreateScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String? preselectedReservationId;

  const InvoiceCreateScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    this.preselectedReservationId,
  });

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  late final InvoiceRepository _repository;
  late final OfflineRepository _offline;

  final _formKey = GlobalKey<FormState>();
  String? _selectedReservationId;
  ReservationModel? _selectedReservation;
  String _type = 'PROFORMA';
  double _tvaTaux = 0.0;
  List<InvoiceLineInput> _lines = [];
  bool _loadingReservations = true;
  bool _loading = false;
  List<ReservationModel> _reservations = [];

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(tokens: TokenStorage());
    final offline = context.read<OfflineRepository>();
    _offline = offline;
    _repository = InvoiceRepository(apiClient, offline);
    _loadReservations();
  }

  double _parseInputDouble(String value) {
    final sanitized = value.replaceAll(',', '.').trim();
    return double.tryParse(sanitized) ?? 0.0;
  }

  Future<void> _loadReservations() async {
    setState(() => _loadingReservations = true);
    try {
      final rows = await _offline.readCollection(
        EntityRegistry.reservation,
        widget.businessId,
      );
      _reservations = rows
          .where((r) =>
              r['statut'] == 'VALIDEE' ||
              r['statut'] == 'EN_COURS' ||
              r['statut'] == 'TERMINEE')
          .map(ReservationModel.fromJson)
          .toList();
      if (widget.preselectedReservationId != null) {
        final preselected = _reservations
            .where((r) => r.id == widget.preselectedReservationId)
            .toList();
        if (preselected.isNotEmpty) {
          _onReservationChanged(preselected.first.id);
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement réservations: $e');
    } finally {
      if (mounted) setState(() => _loadingReservations = false);
    }
  }

  void _onReservationChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedReservationId = value;
      _selectedReservation = _reservations.firstWhere((r) => r.id == value);
      _buildLinesFromReservation();
    });
  }

  void _buildLinesFromReservation() {
    if (_selectedReservation == null) {
      _lines = [];
      return;
    }
    final res = _selectedReservation!;
    _lines = [
      InvoiceLineInput(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description:
            'Location ${res.itemNom} (${DateFormat('dd/MM/yyyy').format(res.dateDebut!)} - ${DateFormat('dd/MM/yyyy').format(res.dateFin!)})',
        quantite: res.quantite,
        prixUnitaire: 0,
      ),
    ];
    _loadItemPrice();
  }

  Future<void> _loadItemPrice() async {
    if (_selectedReservation == null) return;
    try {
      final item = await _offline.store.findPayload(
        EntityRegistry.item.type,
        _selectedReservation!.itemId,
      );
      if (item != null && mounted) {
        final prixRaw = item['prix'];
        final prix = prixRaw is num
            ? prixRaw.toDouble()
            : double.tryParse('$prixRaw'.replaceAll(',', '.')) ?? 0.0;
        setState(() {
          if (_lines.isNotEmpty) {
            _lines[0] = _lines[0].copyWith(prixUnitaire: prix);
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur prix item: $e');
    }
  }

  void _addLine() {
    setState(() {
      _lines.add(InvoiceLineInput(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: 'Nouvelle ligne',
        quantite: 1,
        prixUnitaire: 0,
      ));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  double get _sousTotal => _lines.fold(0, (sum, l) => sum + l.total);
  double get _tvaMontant => _sousTotal * _tvaTaux / 100;
  double get _totalTtc => _sousTotal + _tvaMontant;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une ligne')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _repository.create(
        businessId: widget.businessId,
        reservationId: _selectedReservationId!,
        type: _type,
        tvaTaux: _tvaTaux,
        lines: _lines.map((l) => l.toJson()).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Facture créée'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une facture'),
      ),
      body: _loadingReservations
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Réservation',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedReservationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Réservation *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    selectedItemBuilder: (context) => _reservations
                        .map((r) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${r.reference} • ${r.itemNom}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ))
                        .toList(),
                    items: _reservations
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                '${r.reference} • ${r.itemNom} • ${r.dateDebut != null ? DateFormat('dd/MM').format(r.dateDebut!) : ''}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ))
                        .toList(),
                    onChanged: _onReservationChanged,
                    validator: (v) =>
                        v == null ? 'Sélectionnez une réservation' : null,
                  ),
                  const SizedBox(height: 16),

                  Text('Type de facture',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'PROFORMA',
                          label: Text('Proforma'),
                          icon: Icon(Icons.receipt_long)),
                      ButtonSegment(
                          value: 'DEFINITIVE',
                          label: Text('Définitive'),
                          icon: Icon(Icons.verified)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (sel) =>
                        setState(() => _type = sel.first),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _tvaTaux.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'TVA (%)',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) =>
                        setState(() => _tvaTaux = _parseInputDouble(v)),
                  ),
                  const SizedBox(height: 16),

                  Text('Lignes de facture',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  ..._lines.asMap().entries.map((entry) {
                    final i = entry.key;
                    final line = entry.value;

                    return Card(
                      key: ValueKey(
                          '${line.id}_${line.prixUnitaire}_${line.quantite}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: line.description,
                                    decoration: const InputDecoration(
                                      labelText: 'Description',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (v) => _lines[i] =
                                        line.copyWith(description: v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: line.quantite.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Qté',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => setState(() {
                                      _lines[i] = line.copyWith(
                                          quantite: int.tryParse(v) ?? 1);
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        line.prixUnitaire.toStringAsFixed(0),
                                    decoration: const InputDecoration(
                                      labelText: 'Prix unitaire',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    onChanged: (v) => setState(() {
                                      _lines[i] = line.copyWith(
                                          prixUnitaire: _parseInputDouble(v));
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '${NumberFormat('#,##0', 'fr_FR').format(line.total)} FCFA',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: _lines.length > 1
                                      ? () => _removeLine(i)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une ligne'),
                    onPressed: _addLine,
                  ),
                  const SizedBox(height: 24),

                  Card(
                    color: Theme.of(context)
                        .primaryColor
                        .withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _TotalRow('Sous-total',
                              '${NumberFormat('#,##0', 'fr_FR').format(_sousTotal)} FCFA'),
                          if (_tvaTaux > 0)
                            _TotalRow(
                                'TVA (${_tvaTaux.toStringAsFixed(0)}%)',
                                '${NumberFormat('#,##0', 'fr_FR').format(_tvaMontant)} FCFA'),
                          const Divider(),
                          _TotalRow(
                              'Total TTC',
                              '${NumberFormat('#,##0', 'fr_FR').format(_totalTtc)} FCFA',
                              isTotal: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Créer la facture',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _TotalRow(this.label, this.value, {this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 16,
                  fontWeight:
                      isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 16,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal ? Theme.of(context).primaryColor : null)),
        ],
      ),
    );
  }
}

class InvoiceLineInput {
  final String id;
  final String description;
  final int quantite;
  final double prixUnitaire;

  const InvoiceLineInput({
    required this.id,
    required this.description,
    required this.quantite,
    required this.prixUnitaire,
  });

  InvoiceLineInput copyWith(
      {String? id,
      String? description,
      int? quantite,
      double? prixUnitaire}) {
    return InvoiceLineInput(
      id: id ?? this.id,
      description: description ?? this.description,
      quantite: quantite ?? this.quantite,
      prixUnitaire: prixUnitaire ?? this.prixUnitaire,
    );
  }

  double get total => quantite * prixUnitaire;

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
        'total': total,
      };
}