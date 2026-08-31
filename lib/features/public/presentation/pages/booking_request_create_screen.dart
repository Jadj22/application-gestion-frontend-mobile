import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/public_item_model.dart';
import '../../data/repositories/booking_request_repository.dart';
import 'booking_request_confirmation_screen.dart';

/// Écran création demande de location par client (V2)
class BookingRequestCreateScreen extends StatefulWidget {
  final String slug;
  final String businessName;
  final PublicItemModel item;
  final DateTime? selectedDateDebut;
  final DateTime? selectedDateFin;

  const BookingRequestCreateScreen({
    super.key,
    required this.slug,
    required this.businessName,
    required this.item,
    this.selectedDateDebut,
    this.selectedDateFin,
  });

  @override
  State<BookingRequestCreateScreen> createState() => _BookingRequestCreateScreenState();
}

class _BookingRequestCreateScreenState extends State<BookingRequestCreateScreen> {
  late final BookingRequestRepository _repository;

  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _lieuNomController = TextEditingController();
  final _lieuAdresseController = TextEditingController();
  final _contactNomController = TextEditingController();
  final _contactTelephoneController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dateDebut;
  DateTime? _dateFin;
  int _quantite = 1;
  bool _loading = false;
  bool _acceptConditions = false;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<ApiClient>();
    _repository = BookingRequestRepository(apiClient);

    _dateDebut = widget.selectedDateDebut ?? DateTime.now().add(const Duration(days: 1));
    _dateFin = widget.selectedDateFin ?? DateTime.now().add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    _lieuNomController.dispose();
    _lieuAdresseController.dispose();
    _contactNomController.dispose();
    _contactTelephoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptConditions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez accepter les conditions')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _repository.createPublic(
        slug: widget.slug,
        itemId: widget.item.id,
        clientNom: _nomController.text.trim(),
        clientTelephone: _telephoneController.text.trim(),
        clientEmail: _emailController.text.trim(),
        dateDebut: _dateDebut!,
        dateFin: _dateFin!,
        quantite: _quantite,
        message: _messageController.text.trim(),
        lieuNom: _lieuNomController.text.trim(),
        lieuAdresse: _lieuAdresseController.text.trim(),
        contactNom: _contactNomController.text.trim(),
        contactTelephone: _contactTelephoneController.text.trim(),
        notesLivraison: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingRequestConfirmationScreen(
            slug: widget.slug,
            businessName: widget.businessName,
            result: result,
            item: widget.item,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final total = item.prix * _quantite;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demander une location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Récap article
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: item.photoUrl != null
                            ? Image.network(item.photoUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.grey[200]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.nom, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${DateFormat('dd/MM/yyyy').format(_dateDebut!)} - ${DateFormat('dd/MM/yyyy').format(_dateFin!)}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          Text('${_quantite} x ${item.prixFormate} = ${NumberFormat('#,##0', 'fr_FR').format(total)} FCFA',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dates (non modifiables si déjà sélectionnées)
            if (widget.selectedDateDebut == null) ...[
              Text('Période de location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Date début',
                      value: _dateDebut,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Date fin',
                      value: _dateFin,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Affichage seulement si déjà sélectionnées
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('Période: ${DateFormat('dd/MM/yyyy').format(_dateDebut!)} - ${DateFormat('dd/MM/yyyy').format(_dateFin!)}'),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      _dateDebut = DateTime.now().add(const Duration(days: 1));
                      _dateFin = DateTime.now().add(const Duration(days: 2));
                    });
                  },
                  child: const Text('Modifier'),
                ),
              ),
            ],

            // Quantité
            const SizedBox(height: 16),
            Text('Quantité', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _quantite > 1 ? () => setState(() => _quantite--) : null,
                ),
                Text('$_quantite', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _quantite++),
                ),
                const Spacer(),
                Text('Total: ${NumberFormat('#,##0', 'fr_FR').format(total)} FCFA',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    )),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Infos client
            Text('Vos coordonnées', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom complet *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telephoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone *',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.trim().isEmpty || !v.contains('@') ? 'Email invalide' : null,
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Lieu & contact (optionnel)
            Text('Lieu de livraison (optionnel)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lieuNomController,
              decoration: const InputDecoration(
                labelText: 'Nom du lieu (ex: Salle des fêtes, Hôtel...)',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lieuAdresseController,
              decoration: const InputDecoration(
                labelText: 'Adresse complète',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactNomController,
              decoration: const InputDecoration(
                labelText: 'Contact sur place (nom)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactTelephoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone du contact',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes livraison (étage, code porte, instructions...)',
                prefixIcon: Icon(Icons.note_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Message
            Text('Message (optionnel)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message pour l\'entreprise (occasion, besoins particuliers...)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Conditions
            Row(
              children: [
                Checkbox(
                  value: _acceptConditions,
                  onChanged: (v) => setState(() => _acceptConditions = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _acceptConditions = !_acceptConditions),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'J\'accepte les '),
                          TextSpan(
                            text: 'conditions générales',
                            style: TextStyle(
                              color: theme.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' et la politique de confidentialité'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bouton envoyer
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Envoyer la demande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isDebut) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? _dateDebut! : _dateFin!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
          if (_dateFin != null && _dateFin!.isBefore(picked)) {
            _dateFin = picked.add(const Duration(days: 1));
          }
        } else {
          _dateFin = picked;
          if (_dateDebut != null && _dateDebut!.isAfter(picked)) {
            _dateDebut = picked.subtract(const Duration(days: 1));
          }
        }
      });
    }
  }
}

/// Champ date picker
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(value != null ? DateFormat('dd/MM/yyyy').format(value!) : 'Sélectionner'),
      ),
    );
  }
}