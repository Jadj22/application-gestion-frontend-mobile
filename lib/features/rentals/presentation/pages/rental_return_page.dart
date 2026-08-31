import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/logi_event_shell.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../reservations/data/models/reservation.dart';
import '../../../reservations/data/reservations_repository.dart';

enum MaterialCondition { good, check, damaged }

/// Contrôle de retour de location — données réelles du backend (US-31).
class RentalReturnPage extends StatefulWidget {
  final String reservationId;

  const RentalReturnPage({
    super.key,
    required this.reservationId,
  });

  @override
  State<RentalReturnPage> createState() => _RentalReturnPageState();
}

class _RentalReturnPageState extends State<RentalReturnPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();

  ReservationModel? _reservation;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  MaterialCondition _condition = MaterialCondition.good;
  bool _maintenanceRequired = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (businessId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservation = await context
          .read<ReservationsRepository>()
          .detail(businessId, widget.reservationId);
      if (!mounted) return;
      setState(() {
        _reservation = reservation;
        if (reservation.quantiteRetournee != null) {
          _qtyController.text = '${reservation.quantiteRetournee}';
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _quantityOut => _reservation?.quantite ?? 0;

  int get _returnedQty {
    final parsed = int.tryParse(_qtyController.text.trim());
    return parsed ?? 0;
  }

  int get _missingCount =>
      (_quantityOut - _returnedQty).clamp(0, _quantityOut);

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyChanged(String value) {
    var qty = int.tryParse(value.trim()) ?? 0;
    if (qty > _quantityOut) qty = _quantityOut;
    if (qty < 0) qty = 0;
    if (value != qty.toString()) {
      _qtyController.value = TextEditingValue(
        text: qty.toString(),
        selection: TextSelection.collapsed(offset: qty.toString().length),
      );
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final reservation = _reservation;
    final businessId = context.read<SessionController>().currentBusiness?.id;
    if (reservation == null || businessId == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final damaged = _condition == MaterialCondition.damaged;
      final returned = _condition == MaterialCondition.damaged
          ? 0
          : _returnedQty;
      final abimee = damaged ? _returnedQty : 0;
      final perdue = _missingCount;
      final notes = <String>[
        if (_maintenanceRequired) 'Entretien requis',
        if (_condition == MaterialCondition.check) 'À contrôler',
      ];
      await context
          .read<ReservationsRepository>()
          .finish(
            businessId,
            reservation.id,
            quantiteRetournee: returned,
            quantiteAbimee: abimee,
            quantitePerdue: perdue,
            observations: notes.join(' ; '),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Retour enregistré : $returned rendu(s)'
            '${abimee > 0 ? ', $abimee abîmé(s)' : ''}'
            '${perdue > 0 ? ', $perdue perdu(s)' : ''}',
          ),
        ),
      );
      Navigator.maybePop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LogiEventShell(
      navIndex: 1,
      showNavigation: false,
      pageTitle: 'Retour de Location',
      body: SafeArea(
        child: _loading
            ? Skeleton(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      SkeletonCard(child: SkeletonListItem()),
                      SizedBox(height: 24),
                      SkeletonCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonText(width: 140, height: 18),
                            SizedBox(height: 16),
                            SkeletonBox(
                              height: 56,
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final reservation = _reservation!;
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32 : 16,
        isWide ? 24 : 8,
        isWide ? 32 : 16,
        isWide ? 32 : 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReservationCard(reservation: reservation),
                const SizedBox(height: 24),
                LogiEventCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuantitySection(
                        controller: _qtyController,
                        maxQty: _quantityOut,
                        missingCount: _missingCount,
                        onChanged: _onQtyChanged,
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'Quantité requise';
                          final n = int.tryParse(v);
                          if (n == null || n < 0) return 'Quantité invalide';
                          if (n > _quantityOut) return 'Max $_quantityOut';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.dashOutlineVariant),
                      const SizedBox(height: 24),
                      _ConditionSelector(
                        value: _condition,
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: AppColors.dashOutlineVariant),
                      const SizedBox(height: 24),
                      _MaintenanceToggle(
                        value: _maintenanceRequired,
                        onChanged: (v) =>
                            setState(() => _maintenanceRequired = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      'ENREGISTRER LE RETOUR',
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dashPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return LogiEventCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.itemNom,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dashPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Réf: ${reservation.reference}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatDate(reservation.dateDebut)} → '
                '${_formatDate(reservation.dateFin)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.dashOnSurfaceVariant,
                ),
              ),
            ],
          );

          if (constraints.maxWidth >= 480) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _ProductIcon(),
                const SizedBox(width: 16),
                Expanded(child: info),
                const SizedBox(width: 16),
                _QuantityBadge(count: reservation.quantite),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _ProductIcon(),
                  const SizedBox(width: 16),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 16),
              _QuantityBadge(count: reservation.quantite),
            ],
          );
        },
      ),
    );
  }
}

class _ProductIcon extends StatelessWidget {
  const _ProductIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.dashOnSurfaceVariant,
        size: 32,
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final int count;

  const _QuantityBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dashSurfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dashOutlineVariant),
      ),
      child: Column(
        children: [
          Text(
            'SORTIS',
            style: AppTextStyles.fieldLabel.copyWith(
              color: AppColors.dashOnSurfaceVariant,
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.dashPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantitySection extends StatelessWidget {
  final TextEditingController controller;
  final int maxQty;
  final int missingCount;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;

  const _QuantitySection({
    required this.controller,
    required this.maxQty,
    required this.missingCount,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUANTITÉ RENDUE EN BON ÉTAT',
          style: AppTextStyles.fieldLabel.copyWith(
            color: AppColors.dashOnSurface,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 128,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onChanged,
                validator: validator,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashPrimary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.dashSurface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.dashOutlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.dashOutlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.dashSecondary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            if (missingCount > 0)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.dashErrorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.dashError.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppColors.dashError,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$missingCount manquants',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dashError,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ConditionSelector extends StatelessWidget {
  final MaterialCondition value;
  final ValueChanged<MaterialCondition> onChanged;

  const _ConditionSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAT DU MATÉRIEL',
          style: AppTextStyles.fieldLabel.copyWith(
            color: AppColors.dashOnSurface,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 480 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: cols == 3 ? 1.1 : 2.8,
              children: [
                _ConditionCard(
                  label: 'Bon',
                  icon: Icons.check_circle_outlined,
                  selected: value == MaterialCondition.good,
                  onTap: () => onChanged(MaterialCondition.good),
                ),
                _ConditionCard(
                  label: 'À contrôler',
                  icon: Icons.search,
                  selected: value == MaterialCondition.check,
                  onTap: () => onChanged(MaterialCondition.check),
                ),
                _ConditionCard(
                  label: 'Endommagé',
                  icon: Icons.broken_image_outlined,
                  selected: value == MaterialCondition.damaged,
                  onTap: () => onChanged(MaterialCondition.damaged),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.dashSurfaceLow : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.dashPrimary
                  : AppColors.dashOutlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected
                    ? AppColors.dashPrimary
                    : AppColors.dashOnSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dashOnSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MaintenanceToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entretien requis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dashOnSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Signaler pour nettoyage ou réparation mineure',
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.dashPrimary,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.hint),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}