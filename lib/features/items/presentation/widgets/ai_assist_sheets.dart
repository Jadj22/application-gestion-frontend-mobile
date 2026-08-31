import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/item_assist_service.dart';
import '../../data/models/image_description.dart';

/// Ce que l'utilisateur a choisi dans le sélecteur de source.
class AiRequest {
  final AiSource source;
  final String motsCles;
  final String consigne;

  const AiRequest(this.source, {this.motsCles = '', this.consigne = ''});
}

/// Demande à l'utilisateur **d'où** l'IA doit tirer sa proposition.
///
/// Cette étape est le cœur du changement : l'IA ne part plus d'un effet de
/// bord (une photo qu'on vient de prendre) mais d'un choix conscient. Elle
/// coûte un geste de plus, et c'est volontaire — une génération est un appel
/// facturé, elle mérite une intention.
class AiSourcePicker extends StatefulWidget {
  /// Sources indisponibles dans le contexte courant, avec la raison affichée
  /// (« aucune photo », « description vide »…).
  final Map<AiSource, String> disabled;

  final AiSource initial;

  const AiSourcePicker({
    super.key,
    this.disabled = const {},
    this.initial = AiSource.nom,
  });

  @override
  State<AiSourcePicker> createState() => _AiSourcePickerState();
}

class _AiSourcePickerState extends State<AiSourcePicker> {
  late AiSource _choix = widget.initial;
  final _motsClesController = TextEditingController();
  final _consigneController = TextEditingController();

  @override
  void dispose() {
    _motsClesController.dispose();
    _consigneController.dispose();
    super.dispose();
  }

  bool get _peutContinuer {
    if (widget.disabled.containsKey(_choix)) return false;
    return switch (_choix) {
      AiSource.motsCles => _motsClesController.text.trim().isNotEmpty,
      AiSource.libre => _consigneController.text.trim().isNotEmpty,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comment générer la description ?',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 4),
            Text(
              'L\'IA proposera un texte : vous pourrez l\'accepter, le '
              'modifier ou l\'ignorer.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            for (final source in AiSource.values)
              _OptionSource(
                source: source,
                selected: _choix == source,
                disabledReason: widget.disabled[source],
                onTap: () => setState(() => _choix = source),
              ),
            if (_choix == AiSource.motsCles) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _motsClesController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Mots-clés',
                  hintText: 'chaise, bois, marron, restaurant',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_choix == AiSource.libre) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _consigneController,
                autofocus: true,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Votre demande',
                  hintText: 'Décris cet article pour mon catalogue…',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _peutContinuer
                        ? () => Navigator.of(context).pop(
                              AiRequest(
                                _choix,
                                motsCles: _motsClesController.text.trim(),
                                consigne: _consigneController.text.trim(),
                              ),
                            )
                        : null,
                    child: const Text('Continuer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSource extends StatelessWidget {
  final AiSource source;
  final bool selected;
  final String? disabledReason;
  final VoidCallback onTap;

  const _OptionSource({
    required this.source,
    required this.selected,
    required this.disabledReason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final indisponible = disabledReason != null;
    return Opacity(
      opacity: indisponible ? 0.5 : 1,
      child: ListTile(
        onTap: indisponible ? null : onTap,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.dashPrimary : AppColors.textSecondary,
        ),
        title: Text(source.label),
        subtitle: Text(
          disabledReason ?? source.hint,
          style: TextStyle(
            fontSize: 12,
            color: indisponible ? AppColors.dangerText : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Ce que l'utilisateur décide de faire d'une proposition.
enum AiProposalAction { accepter, modifier, relancer, ignorer }

class AiProposalOutcome {
  final AiProposalAction action;

  /// Texte éventuellement retouché avant acceptation.
  final ImageDescription? proposition;

  const AiProposalOutcome(this.action, [this.proposition]);
}

/// Présente la proposition de l'IA **avant** toute écriture dans le formulaire.
///
/// Rien n'est appliqué tant que l'utilisateur n'a pas dit oui. C'est la règle
/// qui protège son travail : une description écrite à la main ne peut pas être
/// écrasée par une génération qu'il n'a pas validée.
class AiProposalSheet extends StatefulWidget {
  final ImageDescription proposition;

  /// Champs du formulaire qui seraient écrasés si la proposition est acceptée.
  /// Listés explicitement pour que l'utilisateur sache ce qu'il perd.
  final List<String> champsEcrases;

  const AiProposalSheet({
    super.key,
    required this.proposition,
    this.champsEcrases = const [],
  });

  @override
  State<AiProposalSheet> createState() => _AiProposalSheetState();
}

class _AiProposalSheetState extends State<AiProposalSheet> {
  late final _descriptionController =
      TextEditingController(text: widget.proposition.description);
  bool _edition = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  ImageDescription get _resultat =>
      widget.proposition.copyWith(description: _descriptionController.text.trim());

  @override
  Widget build(BuildContext context) {
    final p = widget.proposition;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Proposition de l\'IA', style: AppTextStyles.h2),
              ],
            ),
            if (p.confianceFaible) ...[
              const SizedBox(height: 8),
              _Avertissement(
                'L\'IA est peu sûre de cette proposition. Relisez-la '
                'attentivement avant de l\'utiliser.',
              ),
            ],
            const SizedBox(height: 16),

            if (p.nom.isNotEmpty) _Champ('Nom', p.nom),
            if (p.unite.isNotEmpty) _Champ('Unité', p.unite),
            if (p.categorie.isNotEmpty) _Champ('Catégorie', p.categorie),

            const SizedBox(height: 12),
            Text('Description', style: AppTextStyles.labelCaps),
            const SizedBox(height: 6),
            if (_edition)
              TextField(
                controller: _descriptionController,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dashSurfaceLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _descriptionController.text.isEmpty
                      ? 'Aucune description proposée.'
                      : _descriptionController.text,
                  style: AppTextStyles.body,
                ),
              ),

            if (p.caracteristiques.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Caractéristiques', style: AppTextStyles.labelCaps),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in p.caracteristiques.entries)
                    Chip(
                      label: Text(
                        '${entry.key} : ${entry.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],

            if (widget.champsEcrases.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Avertissement(
                'Ces champs que vous avez saisis seront remplacés : '
                '${widget.champsEcrases.join(', ')}.',
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      AiProposalOutcome(AiProposalAction.accepter, _resultat),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Utiliser'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => setState(() => _edition = !_edition),
                  tooltip: _edition ? 'Terminer la retouche' : 'Modifier',
                  icon: Icon(_edition ? Icons.done : Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      const AiProposalOutcome(AiProposalAction.relancer),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Relancer'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      const AiProposalOutcome(AiProposalAction.ignorer),
                    ),
                    child: const Text('Ignorer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  final String label;
  final String valeur;

  const _Champ(this.label, this.valeur);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: AppTextStyles.labelCaps),
            ),
            Expanded(child: Text(valeur, style: AppTextStyles.body)),
          ],
        ),
      );
}

class _Avertissement extends StatelessWidget {
  final String message;

  const _Avertissement(this.message);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEA8C00).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 16, color: Color(0xFFEA8C00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
