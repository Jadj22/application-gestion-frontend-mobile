import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/item_units.dart';
import '../../data/item_units_service.dart';

/// Champ « Unité » : liste standard, unités créées par l'équipe, et création
/// d'une nouvelle unité à la volée.
///
/// **Ce que l'unité veut dire** : elle répond à « la quantité compte quoi ? ».
/// `25` + `kg` se lit « 25 kilogrammes » ; `24` + `bouteille` se lit
/// « 24 bouteilles ». Sans elle, un chiffre de stock est ambigu.
///
/// **Pourquoi une liste, et pourquoi elle reste ouverte** : en saisie
/// totalement libre, la même unité s'écrit `kg`, `Kg`, `kilo`, et les stocks
/// deviennent incomparables d'un membre de l'équipe à l'autre. Mais aucune
/// liste fermée ne peut couvrir tous les métiers servis par l'application :
/// l'utilisateur peut donc créer la sienne, qui est **enregistrée** et
/// réapparaît aux créations suivantes.
class UnitField extends StatefulWidget {
  final TextEditingController controller;

  /// Unités personnalisées déjà connues pour ce business.
  final List<String> customUnits;

  /// Appelé quand l'utilisateur crée une unité, pour qu'elle soit mémorisée.
  final Future<void> Function(String unit) onCreate;

  final Widget? badge;

  const UnitField({
    super.key,
    required this.controller,
    required this.customUnits,
    required this.onCreate,
    this.badge,
  });

  @override
  State<UnitField> createState() => _UnitFieldState();
}

class _UnitFieldState extends State<UnitField> {
  /// Unités créées pendant cette session, avant rechargement de la liste.
  final List<String> _ajoutees = [];

  /// Unités de l'équipe, hors doublons et hors équivalents standard.
  ///
  /// Le filtre sur les équivalents standard est ce qui empêche le crash :
  /// saisir « sac » ou « kg » comme unité personnalisée produisait deux entrées
  /// de même valeur dans le menu — une venant de la liste standard, l'autre de
  /// la liste personnalisée — et le menu déroulant exige qu'une valeur
  /// sélectionnée corresponde à **exactement une** entrée.
  List<String> get _personnalisees {
    final vues = <String>{};
    final resultat = <String>[];
    for (final unite in [...widget.customUnits, ..._ajoutees]) {
      final propre = unite.trim();
      if (propre.isEmpty) continue;
      // Déjà présente dans la liste standard, sous une graphie ou une autre.
      if (ItemUnits.normalize(propre) != null) continue;
      if (!vues.add(propre.toLowerCase())) continue;
      resultat.add(propre);
    }
    resultat.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return resultat;
  }

  /// Valeur courante telle qu'elle doit apparaître dans la liste.
  ///
  /// `null` uniquement si le champ est vide : une unité inconnue de la liste
  /// est ajoutée aux propositions plutôt que d'être perdue — c'est ce qui
  /// évite qu'ouvrir un article existant efface son unité.
  String? get _valeurCourante {
    final brute = widget.controller.text.trim();
    if (brute.isEmpty) return null;
    return ItemUnits.normalize(brute) ?? brute;
  }

  /// Unités affichées en plus des standards : celles de l'équipe, et celle de
  /// l'article en cours si elle n'est encore répertoriée nulle part.
  List<String> get _proposeesEnPlus {
    final liste = [..._personnalisees];
    final courante = _valeurCourante;
    if (courante != null &&
        !ItemUnits.isKnown(courante) &&
        !liste.any((u) => u.toLowerCase() == courante.toLowerCase())) {
      liste.insert(0, courante);
    }
    return liste;
  }

  Future<void> _ouvrirCreation() async {
    final unite = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogueNouvelleUnite(),
    );
    if (unite == null || !mounted) return;

    await widget.onCreate(unite);
    if (!mounted) return;
    setState(() {
      if (!_ajoutees.any((u) => u.toLowerCase() == unite.toLowerCase())) {
        _ajoutees.add(unite);
      }
      widget.controller.text = unite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enPlus = _proposeesEnPlus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('UNITÉ', style: AppTextStyles.fieldLabel),
            if (widget.badge != null) ...[
              const SizedBox(width: 8),
              widget.badge!,
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _valeurCourante,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.straighten_outlined),
            hintText: 'Choisir',
          ),
          items: [
            if (enPlus.isNotEmpty) ...[
              _entete('Vos unités'),
              for (final unite in enPlus)
                DropdownMenuItem<String>(
                  value: unite,
                  child: Text(unite),
                ),
            ],
            for (final groupe in ItemUnits.groups) ...[
              _entete(groupe),
              for (final unite in ItemUnits.inGroup(groupe))
                DropdownMenuItem<String>(
                  value: unite.value,
                  child: Text(unite.label),
                ),
            ],
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => widget.controller.text = value);
          },
        ),
        // Bouton distinct plutôt qu'une entrée du menu : le menu s'ouvre
        // centré sur l'unité sélectionnée et ne rend que ce qui est visible,
        // si bien qu'une commande placée dans la liste devenait inatteignable
        // dès qu'un article avait déjà une unité.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _ouvrirCreation,
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Ajouter une unité',
              style: TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<String> _entete(String libelle) => DropdownMenuItem<String>(
        enabled: false,
        child: Text(
          libelle.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

/// Saisie d'une nouvelle unité, validée avant d'être acceptée.
class _DialogueNouvelleUnite extends StatefulWidget {
  const _DialogueNouvelleUnite();

  @override
  State<_DialogueNouvelleUnite> createState() => _DialogueNouvelleUniteState();
}

class _DialogueNouvelleUniteState extends State<_DialogueNouvelleUnite> {
  final _controller = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    final validation = ItemUnitsService.validate(_controller.text);
    if (!validation.valid) {
      setState(() => _erreur = validation.error);
      return;
    }
    Navigator.of(context).pop(validation.value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle unité'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment comptez-vous cet article ?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: ItemUnits.maxLength,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            onSubmitted: (_) => _valider(),
            decoration: InputDecoration(
              hintText: 'botte, plateau, bobine…',
              border: const OutlineInputBorder(),
              errorText: _erreur,
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elle sera enregistrée et vous sera proposée pour vos prochains '
            'articles.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Ajouter')),
      ],
    );
  }
}
