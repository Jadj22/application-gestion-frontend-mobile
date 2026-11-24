import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/items_repository.dart';
import '../../data/models/category.dart';
import '../../../../core/offline/offline_repository.dart';
import '../../data/item_assist_service.dart';
import '../../data/item_units_service.dart';
import '../../data/models/image_description.dart';
import '../widgets/ai_assist_sheets.dart';
import '../widgets/unit_field.dart';
import '../../data/models/item.dart';

/// Champs que l'analyse d'image peut pré-remplir : sert à afficher le badge
/// « IA » sur les champs concernés et à annuler le pré-remplissage d'un coup.
enum _ChampIa { nom, reference, description, unite, categorie, caracteristiques }

/// Création (US-06) ou modification (US-07) d'un article du catalogue.
///
/// À la création, le chemin le plus court est la photo : l'utilisateur cadre
/// l'article, et la fiche arrive remplie (nom, référence, description,
/// catégorie, unité, caractéristiques). Tout reste modifiable, et un seul
/// geste annule l'ensemble du pré-remplissage.
class AddItemPage extends StatefulWidget {
  final ItemModel? existing;

  const AddItemPage({super.key, this.existing});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  late final ItemsRepository _repository;
  late final ItemAssistService _assist;
  late final ItemUnitsService _unitsService;
  bool _generatingReference = false;

  /// Unites creees par l'equipe, chargees a l'ouverture de l'ecran.
  List<String> _unitesPersonnalisees = const [];
  late final Business _business;

  bool get _isEditing => widget.existing != null;

  final _nomController = TextEditingController();
  final _referenceController = TextEditingController();
  final _prixController = TextEditingController();
  final _uniteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantiteInitialeController = TextEditingController();

  bool _isPublished = false;

  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  String? _categoriesError;
  CategoryModel? _selectedCategory;
  bool? _entretienRequis;
  bool _submitting = false;
  String? _error;

  /// Photo choisie (appareil photo ou galerie), envoyée après la création.
  String? _photoPath;
  bool _uploadingPhoto = false;

  /// Analyse IA de la photo (Gemini via le backend).
  bool _describing = false;

  /// Dernière fiche proposée par l'IA, conservée pour la bannière de résumé.
  ImageDescription? _suggestion;

  /// Champs effectivement remplis par la dernière analyse.
  final Set<_ChampIa> _champsIa = {};

  /// Valeurs des champs avant pré-remplissage, pour pouvoir tout annuler.
  Map<_ChampIa, String>? _avantSuggestion;
  CategoryModel? _categorieAvantSuggestion;

  /// Caractéristiques relevées sur la photo, enregistrées avec l'article.
  Map<String, String> _caracteristiques = {};

  /// Catégorie proposée par l'IA mais absente du catalogue : on offre de la
  /// créer plutôt que de laisser l'article sans classement.
  String? _categorieACreer;
  bool _creatingCategory = false;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _assist = context.read<ItemAssistService>();
    _unitsService = context.read<ItemUnitsService>();
    _business = context.read<SessionController>().currentBusiness!;
    final existing = widget.existing;
    if (existing != null) {
      _nomController.text = existing.nom;
      _referenceController.text = existing.reference ?? '';
      if (existing.prix > 0) _prixController.text = '${existing.prix}';
      _uniteController.text = existing.unite;
      _descriptionController.text = existing.description;
      _entretienRequis = existing.entretienRequis;
      _isPublished = existing.isPublished;
    }
    _loadCategories();
    _chargerUnites();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _referenceController.dispose();
    _prixController.dispose();
    _uniteController.dispose();
    _descriptionController.dispose();
    _quantiteInitialeController.dispose();
    super.dispose();
  }

  /// Charge les unites personnalisees du business.
  ///
  /// Purement local : la liste doit s'afficher hors ligne comme en ligne, et
  /// une unite creee sans reseau doit rester proposee.
  Future<void> _chargerUnites() async {
    final unites = await _unitsService.customUnits(_business.id);
    if (mounted) setState(() => _unitesPersonnalisees = unites);
  }

  /// Memorise une unite creee par l'utilisateur pour les prochains articles.
  Future<void> _enregistrerUnite(String unite) async {
    await _unitsService.remember(_business.id, unite);
    await _chargerUnites();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final categories = await _repository.categories(_business.id);
      if (mounted) {
        setState(() {
          _categories = categories;
          final existing = widget.existing;
          if (existing != null && existing.categoryId != null) {
            _selectedCategory = categories
                .where((c) => c.id == existing.categoryId)
                .firstOrNull;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _categoriesError = e.message);
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  // --- Photo ---------------------------------------------------------------

  /// Demande la source de la photo. L'appareil photo est proposé en premier :
  /// c'est le geste attendu quand on a l'article sous les yeux.
  Future<ImageSource?> _choisirSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Cadrez l\'article, la fiche se remplit'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _capturer(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return picked?.path;
    } on Exception {
      if (mounted) {
        _signaler(
          source == ImageSource.camera
              ? 'Appareil photo indisponible. Autorisez-le dans les réglages '
                  'ou choisissez une photo dans la galerie.'
              : 'Impossible d\'ouvrir la galerie.',
        );
      }
      return null;
    }
  }

  /// Choisit une photo sans lancer l'analyse (bouton « Changer »).
  Future<void> _pickPhoto() async {
    final source = await _choisirSource();
    if (source == null) return;
    final path = await _capturer(source);
    if (path != null && mounted) setState(() => _photoPath = path);
  }

  /// Prend une photo. **Et rien d'autre.**
  ///
  /// Auparavant, cette action enchaînait automatiquement sur l'analyse IA :
  /// photographier revenait à déclencher un appel payant sans l'avoir demandé,
  /// et à voir des champs se remplir tout seuls. La photo est désormais une
  /// fonctionnalité indépendante — elle illustre l'article, elle ne le décrit
  /// pas. L'IA se demande explicitement, via le bouton dédié.
  Future<void> _photographier() async {
    final source = await _choisirSource();
    if (source == null) return;
    final path = await _capturer(source);
    if (path == null || !mounted) return;
    setState(() => _photoPath = path);
  }

  /// Parcours IA complet, déclenché **uniquement** par le bouton dédié.
  ///
  /// Trois étapes, dans cet ordre, dont aucune n'est automatique :
  /// choisir la source → générer → valider la proposition. Tant que
  /// l'utilisateur n'a pas accepté, rien n'est écrit dans le formulaire.
  Future<void> _lancerIa() async {
    final requete = await showModalBottomSheet<AiRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AiSourcePicker(
        disabled: _sourcesIndisponibles(),
        initial: _sourceParDefaut(),
      ),
    );
    if (requete == null || !mounted) return;
    await _genererEtProposer(requete);
  }

  /// Sources que le contexte actuel ne permet pas, avec la raison affichée.
  ///
  /// Les griser plutôt que les masquer apprend à l'utilisateur ce qui les
  /// débloquerait — prendre une photo, saisir un nom.
  Map<AiSource, String> _sourcesIndisponibles() {
    final indisponibles = <AiSource, String>{};
    if ((_photoPath ?? '').isEmpty) {
      indisponibles[AiSource.photo] = "Aucune photo pour l'instant";
    }
    if (_nomController.text.trim().isEmpty) {
      indisponibles[AiSource.nom] = "Saisissez d'abord un nom";
    }
    if (_descriptionController.text.trim().isEmpty) {
      indisponibles[AiSource.amelioration] = 'Aucune description à améliorer';
    }
    if (_nomController.text.trim().isEmpty &&
        _selectedCategory == null &&
        _prixController.text.trim().isEmpty) {
      indisponibles[AiSource.champs] = "Remplissez d'abord quelques champs";
    }
    return indisponibles;
  }

  /// Source pré-sélectionnée : la plus pertinente au vu de ce qui est déjà là.
  AiSource _sourceParDefaut() {
    if (_descriptionController.text.trim().isNotEmpty) {
      return AiSource.amelioration;
    }
    if ((_photoPath ?? '').isNotEmpty) return AiSource.photo;
    if (_nomController.text.trim().isNotEmpty) return AiSource.nom;
    return AiSource.motsCles;
  }

  /// Propose une référence libre pour l'article.
  ///
  /// Aucune IA n'intervient : c'est un calcul déterministe. En ligne, le
  /// serveur tranche car lui seul connaît toutes les références déjà prises ;
  /// hors ligne, le calcul se fait sur l'appareil avec un suffixe qui lui est
  /// propre, pour que deux téléphones ne fabriquent pas la même référence.
  Future<void> _genererReference() async {
    final nom = _nomController.text.trim();
    if (nom.isEmpty) {
      _signaler("Saisissez d'abord le nom de l'article.");
      return;
    }
    setState(() => _generatingReference = true);
    try {
      final reference = await _assist.suggestReference(_business.id, nom);
      if (!mounted) return;
      if (reference.isEmpty) {
        _signaler("Impossible de proposer une référence pour ce nom.");
        return;
      }
      setState(() => _referenceController.text = reference);
    } finally {
      if (mounted) setState(() => _generatingReference = false);
    }
  }

  ItemDraftContext get _contexteIa => ItemDraftContext(
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        categorie: _selectedCategory?.nom ?? '',
        reference: _referenceController.text.trim(),
        unite: _uniteController.text.trim(),
        prix: _prixController.text.trim(),
        caracteristiques: _caracteristiques,
        photoPath: _photoPath,
      );

  /// Appelle l'IA puis soumet sa proposition à l'utilisateur.
  Future<void> _genererEtProposer(AiRequest requete) async {
    setState(() => _describing = true);
    ImageDescription? fiche;
    try {
      fiche = await _assist.generate(
        requete.source,
        _contexteIa,
        motsCles: requete.motsCles,
        consigne: requete.consigne,
      );
    } on OfflineUnsupportedException catch (e) {
      // Hors ligne : on l'explique, et la saisie manuelle continue.
      if (mounted) _signaler(e.message);
    } on NetworkUnavailableException {
      if (mounted) {
        _signaler(
          'La génération avec l\'IA nécessite une connexion Internet.\n\n'
          'Vous pouvez continuer à remplir la fiche manuellement.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final message = (e.statusCode == 502 || e.statusCode == 503)
            ? 'La génération IA est temporairement indisponible. '
                'Réessayez dans quelques instants ou saisissez la fiche à la main.'
            : e.message;
        _signaler(message);
      }
    } catch (_) {
      if (mounted) {
        _signaler('Impossible de contacter le service IA. Vous pouvez renseigner la fiche manuellement.');
      }
    } finally {
      if (mounted) setState(() => _describing = false);
    }
    if (fiche == null || !mounted) return;

    if (!fiche.hasContent) {
      _signaler(
        "L'IA n'a rien pu proposer à partir de ces informations. "
        'Précisez votre demande ou remplissez la fiche à la main.',
      );
      return;
    }

    final verdict = await showModalBottomSheet<AiProposalOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AiProposalSheet(
        proposition: fiche!,
        champsEcrases: _champsQueLaPropositionEcraserait(fiche),
      ),
    );
    if (verdict == null || !mounted) return;

    switch (verdict.action) {
      case AiProposalAction.accepter:
        _appliquerSuggestion(verdict.proposition ?? fiche);
      case AiProposalAction.relancer:
        // Nouvelle tentative sur la même source : l'utilisateur n'a pas à
        // reparcourir tout le sélecteur pour obtenir une autre formulation.
        await _genererEtProposer(requete);
      case AiProposalAction.modifier:
      case AiProposalAction.ignorer:
        // Rien n'est appliqué : le formulaire reste exactement tel qu'il était.
        break;
    }
  }

  /// Champs déjà saisis que la proposition remplacerait si elle est acceptée.
  List<String> _champsQueLaPropositionEcraserait(ImageDescription fiche) {
    final ecrases = <String>[];
    void verifier(String libelle, String actuel, String propose) {
      if (propose.trim().isNotEmpty && actuel.trim().isNotEmpty) {
        ecrases.add(libelle);
      }
    }

    verifier('nom', _nomController.text, fiche.nom);
    verifier('description', _descriptionController.text, fiche.description);
    verifier('unité', _uniteController.text, fiche.unite);
    return ecrases;
  }

  void _appliquerSuggestion(ImageDescription fiche) {
    final avant = <_ChampIa, String>{
      _ChampIa.nom: _nomController.text,
      _ChampIa.reference: _referenceController.text,
      _ChampIa.description: _descriptionController.text,
      _ChampIa.unite: _uniteController.text,
    };
    final champs = <_ChampIa>{};

    // La proposition a ete explicitement acceptee, et la feuille a prevenu des
    // champs qui seraient remplaces : on applique donc aussi par-dessus une
    // saisie existante. L'ancienne valeur reste restaurable via « Annuler ».
    void remplir(_ChampIa champ, TextEditingController controller, String valeur) {
      if (valeur.isEmpty) return;
      if (controller.text.trim() == valeur.trim()) return;
      controller.text = valeur;
      champs.add(champ);
    }

    remplir(_ChampIa.nom, _nomController, fiche.nom);
    remplir(_ChampIa.reference, _referenceController, fiche.reference);
    remplir(_ChampIa.description, _descriptionController, fiche.description);
    remplir(_ChampIa.unite, _uniteController, fiche.unite);

    final categorieAvant = _selectedCategory;
    CategoryModel? categorieChoisie = _selectedCategory;
    String? categorieACreer;
    if (fiche.categoryId != null) {
      final trouvee =
          _categories.where((c) => c.id == fiche.categoryId).firstOrNull;
      if (trouvee != null && trouvee.id != _selectedCategory?.id) {
        categorieChoisie = trouvee;
        champs.add(_ChampIa.categorie);
      }
    } else if (fiche.proposeUneNouvelleCategorie && _selectedCategory == null) {
      categorieACreer = fiche.categorie;
    }

    final caracteristiques = Map<String, String>.from(_caracteristiques);
    if (fiche.caracteristiques.isNotEmpty && caracteristiques.isEmpty) {
      caracteristiques.addAll(fiche.caracteristiques);
      champs.add(_ChampIa.caracteristiques);
    }
    if (fiche.etat != 'INCONNU' && !caracteristiques.containsKey('État')) {
      caracteristiques['État'] = fiche.etatLisible;
      champs.add(_ChampIa.caracteristiques);
    }

    setState(() {
      _suggestion = fiche;
      _champsIa
        ..clear()
        ..addAll(champs);
      _avantSuggestion = avant;
      _categorieAvantSuggestion = categorieAvant;
      _selectedCategory = categorieChoisie;
      _categorieACreer = categorieACreer;
      _caracteristiques = caracteristiques;
    });
  }

  /// Rend au formulaire son état d'avant l'analyse.
  void _annulerSuggestion() {
    final avant = _avantSuggestion;
    if (avant == null) return;
    setState(() {
      if (_champsIa.contains(_ChampIa.nom)) {
        _nomController.text = avant[_ChampIa.nom] ?? '';
      }
      if (_champsIa.contains(_ChampIa.reference)) {
        _referenceController.text = avant[_ChampIa.reference] ?? '';
      }
      if (_champsIa.contains(_ChampIa.description)) {
        _descriptionController.text = avant[_ChampIa.description] ?? '';
      }
      if (_champsIa.contains(_ChampIa.unite)) {
        _uniteController.text = avant[_ChampIa.unite] ?? '';
      }
      if (_champsIa.contains(_ChampIa.categorie)) {
        _selectedCategory = _categorieAvantSuggestion;
      }
      if (_champsIa.contains(_ChampIa.caracteristiques)) {
        _caracteristiques = {};
      }
      _champsIa.clear();
      _suggestion = null;
      _avantSuggestion = null;
      _categorieACreer = null;
    });
  }

  /// Crée la catégorie proposée par l'IA et la sélectionne.
  Future<void> _creerCategorieSuggeree() async {
    final nom = _categorieACreer;
    if (nom == null || _creatingCategory) return;
    setState(() => _creatingCategory = true);
    try {
      final categorie =
          await _repository.createCategory(_business.id, nom: nom);
      if (!mounted) return;
      setState(() {
        _categories = [..._categories, categorie];
        _selectedCategory = categorie;
        _champsIa.add(_ChampIa.categorie);
        _categorieACreer = null;
      });
    } on ApiException catch (e) {
      if (mounted) _signaler(e.message);
    } finally {
      if (mounted) setState(() => _creatingCategory = false);
    }
  }

  void _signaler(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Enregistrement ------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Toute unite non standard reellement utilisee est memorisee, quelle
      // que soit son origine : saisie manuelle, proposition de l'IA, ou
      // reprise d'un article existant. Sans cela, une unite utilisee mais
      // jamais creee explicitement disparaitrait des propositions.
      await _unitsService.remember(_business.id, _uniteController.text);

      final ItemModel item;
      final existing = widget.existing;
      if (existing != null) {
        item = await _repository.update(
          _business.id,
          existing.id,
          nom: _nomController.text.trim(),
          reference: _referenceController.text.trim(),
          description: _descriptionController.text.trim(),
          prix: double.tryParse(_prixController.text.trim()),
          unite: _uniteController.text.trim(),
          categoryId: _selectedCategory?.id,
          entretienRequis: _entretienRequis,
          characteristics: _caracteristiques,
          isPublished: _isPublished,
        );
      } else {
        item = await _repository.create(
          _business.id,
          nom: _nomController.text.trim(),
          reference: _referenceController.text.trim(),
          description: _descriptionController.text.trim(),
          prix: double.tryParse(_prixController.text.trim()),
          unite: _uniteController.text.trim(),
          categoryId: _selectedCategory?.id,
          entretienRequis: _entretienRequis,
          characteristics: _caracteristiques,
          initialQuantity:
              int.tryParse(_quantiteInitialeController.text.trim()) ?? 0,
          isPublished: _isPublished,
        );
      }
      await _uploadPhoto(item.id);
      if (mounted) Navigator.of(context).pop(item);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Upload de la photo vers POST /items/{id}/photos/.
  Future<void> _uploadPhoto(String itemId) async {
    final path = _photoPath;
    if (path == null || path.isEmpty) return;
    if (mounted) setState(() => _uploadingPhoto = true);
    try {
      await _repository.addPhoto(_business.id, itemId, path);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // --- Rendu ---------------------------------------------------------------

  Widget? _badgeIa(_ChampIa champ) =>
      _champsIa.contains(champ) ? const _BadgeIa() : null;

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestion;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: null,
        leadingWidth: 120,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 20),
          label: const Text('Inventaire'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditing ? 'Modifier l\'article' : 'Ajouter un article',
                    style: AppTextStyles.h1),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Mettez à jour les informations de cet article.'
                      : 'Photographiez l\'article : la fiche se remplit toute '
                          'seule. Vous gardez la main sur chaque champ.',
                  style: AppTextStyles.body,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 20),
                  _CarteCapture(
                    photoPath: _photoPath,
                    analysing: _describing,
                    onCapture: _photographier,
                    onRelancer: _lancerIa,
                    onRetirer: () => setState(() {
                      _photoPath = null;
                      _suggestion = null;
                    }),
                  ),
                ],
                if (suggestion != null && _champsIa.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BanniereSuggestion(
                    suggestion: suggestion,
                    nombreChamps: _champsIa.length,
                    onAnnuler: _annulerSuggestion,
                  ),
                ],
                const SizedBox(height: 28),
                CustomInputField(
                  label: 'Nom *',
                  hint: 'Couteau de cuisine',
                  prefixIcon: Icons.inventory_2_outlined,
                  controller: _nomController,
                  suffixIcon: _badgeIa(_ChampIa.nom),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Le nom est requis';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Référence (facultative)',
                  hint: 'CHA-PLI-001',
                  prefixIcon: Icons.tag_outlined,
                  controller: _referenceController,
                  suffixIcon: _generatingReference
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Proposer une référence',
                          icon: const Icon(Icons.auto_awesome_motion_outlined),
                          onPressed: _genererReference,
                        ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomInputField(
                        label: 'Prix (FCFA)',
                        hint: '5000',
                        prefixIcon: Icons.payments_outlined,
                        controller: _prixController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return null;
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed < 0) {
                            return 'Prix invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: UnitField(
                        controller: _uniteController,
                        customUnits: _unitesPersonnalisees,
                        badge: _badgeIa(_ChampIa.unite),
                        onCreate: _enregistrerUnite,
                      ),
                    ),
                  ],
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 20),
                  CustomInputField(
                    label: 'Quantité initiale',
                    hint: '0',
                    prefixIcon: Icons.numbers_outlined,
                    controller: _quantiteInitialeController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null || n < 0) {
                        return 'Quantité invalide (entier ≥ 0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantité en stock à la création '
                    '(0 = aucun stock initial).',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.hint,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CustomInputField(
                  label: 'Description',
                  hint: 'Description optionnelle',
                  prefixIcon: Icons.notes_outlined,
                  controller: _descriptionController,
                  maxLines: 3,
                  suffixIcon: _badgeIa(_ChampIa.description),
                ),
                const SizedBox(height: 10),
                // Seul point d'entree vers l'IA. Elle ne part jamais d'elle-meme :
                // ni la prise de photo, ni la saisie d'un champ ne la declenchent.
                _BoutonIa(
                  busy: _describing,
                  hasDescription:
                      _descriptionController.text.trim().isNotEmpty,
                  onPressed: _describing ? null : _lancerIa,
                ),
                if (_caracteristiques.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('CARACTÉRISTIQUES',
                          style: AppTextStyles.fieldLabel),
                      if (_champsIa.contains(_ChampIa.caracteristiques)) ...[
                        const SizedBox(width: 8),
                        const _BadgeIa(compact: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _caracteristiques.entries
                        .map(
                          (e) => Chip(
                            label: Text('${e.key} : ${e.value}',
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.inputBackground,
                            side: const BorderSide(color: AppColors.border),
                            onDeleted: () => setState(
                                () => _caracteristiques.remove(e.key)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enregistrées avec l\'article. Retirez ce qui ne '
                    'correspond pas.',
                    style: AppTextStyles.body
                        .copyWith(fontSize: 12, color: AppColors.hint),
                  ),
                ],
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  Text('PHOTO', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: 8),
                  _PhotoPickerTile(
                    photoPath: _photoPath,
                    uploading: _uploadingPhoto,
                    describing: _describing,
                    onPick: _pickPhoto,
                    onDescribe: _lancerIa,
                    onRemove: () => setState(() => _photoPath = null),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('CATÉGORIE', style: AppTextStyles.fieldLabel),
                    if (_champsIa.contains(_ChampIa.categorie)) ...[
                      const SizedBox(width: 8),
                      const _BadgeIa(compact: true),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (_loadingCategories)
                  const Skeleton(
                    child: SkeletonBox(
                      height: 56,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  )
                else if (_categoriesError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(_categoriesError!,
                            style: const TextStyle(
                                color: AppColors.dangerText, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: _loadCategories,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<CategoryModel>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Aucune catégorie',
                      prefixIcon: Icon(Icons.category_outlined,
                          color: Colors.grey, size: 20),
                    ),
                    items: _categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.nom,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (category) =>
                        setState(() => _selectedCategory = category),
                  ),
                if (_categorieACreer != null) ...[
                  const SizedBox(height: 10),
                  _ProposerCategorie(
                    nom: _categorieACreer!,
                    creating: _creatingCategory,
                    onCreer: _creerCategorieSuggeree,
                    onIgnorer: () => setState(() => _categorieACreer = null),
                  ),
                ],
                const SizedBox(height: 20),
                Text('ENTRETIEN REQUIS', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool?>(
                  initialValue: _entretienRequis,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Hériter de la catégorie',
                    prefixIcon: Icon(Icons.build_outlined,
                        color: Colors.grey, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('Hériter de la catégorie')),
                    DropdownMenuItem(value: true, child: Text('Oui')),
                    DropdownMenuItem(value: false, child: Text('Non')),
                  ],
                  onChanged: (value) =>
                      setState(() => _entretienRequis = value),
                ),
                const SizedBox(height: 20),
                Text('VISIBILITÉ WEB', style: AppTextStyles.fieldLabel),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _isPublished,
                  onChanged: (value) => setState(() => _isPublished = value ?? false),
                  title: const Text('Visible sur la vitrine publique'),
                  subtitle: const Text(
                    'Coché = visible par les clients sur la page web du business.\n'
                    'Décoché = visible uniquement dans l\'app mobile (équipe).',
                    style: TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.dangerText, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: PrimaryButton(
          label: _isEditing ? 'Enregistrer les modifications' : 'Créer l\'article',
          icon: _isEditing ? Icons.save_outlined : Icons.add_box_outlined,
          isLoading: _submitting,
          onPressed: _submit,
        ),
      ),
    );
  }
}

/// Pastille « IA » posée sur les champs remplis par l'analyse de la photo.
class _BadgeIa extends StatelessWidget {
  final bool compact;

  const _BadgeIa({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final pastille = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: AppColors.successText),
          SizedBox(width: 4),
          Text(
            'IA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.successText,
            ),
          ),
        ],
      ),
    );
    if (compact) return pastille;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: pastille),
    );
  }
}

/// Point d'entrée de la création : cadrer l'article et laisser l'IA remplir.
class _CarteCapture extends StatelessWidget {
  final String? photoPath;
  final bool analysing;
  final VoidCallback onCapture;
  final VoidCallback onRelancer;
  final VoidCallback onRetirer;

  const _CarteCapture({
    required this.photoPath,
    required this.analysing,
    required this.onCapture,
    required this.onRelancer,
    required this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (path == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Créer depuis une photo',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Nom, référence, catégorie, unité et caractéristiques sont '
                  'proposés automatiquement.',
                  style: AppTextStyles.body
                      .copyWith(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: analysing
                        ? 'Analyse en cours...'
                        : 'Photographier l\'article',
                    icon: Icons.photo_camera_outlined,
                    isLoading: analysing,
                    onPressed: analysing ? null : onCapture,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 76,
                      height: 76,
                      color: AppColors.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.hint),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysing ? 'Analyse de la photo...' : 'Photo prête',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Elle sera jointe à l\'article.',
                        style: AppTextStyles.body.copyWith(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: analysing ? null : onRelancer,
                            icon: analysing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Relancer l\'analyse'),
                          ),
                          TextButton.icon(
                            onPressed: analysing ? null : onCapture,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Changer'),
                          ),
                          IconButton(
                            onPressed: analysing ? null : onRetirer,
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.dangerText, size: 20),
                            tooltip: 'Retirer la photo',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Résumé de ce que l'IA a rempli, avec le moyen de tout annuler.
class _BanniereSuggestion extends StatelessWidget {
  final ImageDescription suggestion;
  final int nombreChamps;
  final VoidCallback onAnnuler;

  const _BanniereSuggestion({
    required this.suggestion,
    required this.nombreChamps,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final incertain = suggestion.confianceFaible;
    final fond = incertain ? AppColors.warning : AppColors.success;
    final encre = incertain ? AppColors.warningText : AppColors.successText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(incertain ? Icons.error_outline : Icons.auto_awesome,
                  size: 18, color: encre),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$nombreChamps champ${nombreChamps > 1 ? 's' : ''} '
                  'pré-rempli${nombreChamps > 1 ? 's' : ''} · '
                  '${suggestion.confianceLisible}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: encre,
                  ),
                ),
              ),
            ],
          ),
          if (incertain) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'Relisez la fiche avant d\'enregistrer.',
                style: TextStyle(fontSize: 12, color: encre),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAnnuler,
              style: TextButton.styleFrom(foregroundColor: encre),
              child: const Text('Annuler le pré-remplissage'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Proposition de créer la catégorie suggérée quand elle n'existe pas encore.
class _ProposerCategorie extends StatelessWidget {
  final String nom;
  final bool creating;
  final VoidCallback onCreer;
  final VoidCallback onIgnorer;

  const _ProposerCategorie({
    required this.nom,
    required this.creating,
    required this.onCreer,
    required this.onIgnorer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catégorie suggérée : « $nom »',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Elle n\'existe pas encore dans votre catalogue.',
            style: AppTextStyles.body
                .copyWith(fontSize: 12, color: AppColors.textSecondary),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onIgnorer, child: const Text('Ignorer')),
              TextButton.icon(
                onPressed: creating ? null : onCreer,
                icon: creating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 16),
                label: const Text('Créer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tuile de sélection de photo (édition d'un article existant).
class _PhotoPickerTile extends StatelessWidget {
  final String? photoPath;
  final bool uploading;
  final bool describing;
  final VoidCallback onPick;
  final VoidCallback onDescribe;
  final VoidCallback onRemove;

  const _PhotoPickerTile({
    required this.photoPath,
    required this.uploading,
    required this.describing,
    required this.onPick,
    required this.onDescribe,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (uploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Envoi de la photo...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    if (path != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(path),
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    height: 88,
                    color: AppColors.inputBackground,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.hint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: onPick,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, 48),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Changer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.dangerText),
                      tooltip: 'Retirer la photo',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: describing ? null : onDescribe,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              icon: describing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                describing
                    ? 'Analyse de la photo en cours...'
                    : 'Compléter avec l\'IA',
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gemini identifie l\'article et complète les champs vides.',
            style: TextStyle(fontSize: 12, color: AppColors.hint),
          ),
        ],
      );
    }
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 32, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              'Ajouter une photo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Appareil photo ou galerie',
              style: TextStyle(fontSize: 12, color: AppColors.hint),
            ),
          ],
        ),
      ),
    );
  }
}


/// Point d'entrée unique vers l'IA.
///
/// Volontairement discret et placé sous la description : l'IA est une aide
/// facultative, pas le chemin principal. Un utilisateur doit pouvoir créer un
/// article complet sans jamais l'effleurer.
class _BoutonIa extends StatelessWidget {
  final bool busy;
  final bool hasDescription;
  final VoidCallback? onPressed;

  const _BoutonIa({
    required this.busy,
    required this.hasDescription,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('✨', style: TextStyle(fontSize: 14)),
        label: Text(
          busy
              ? 'Génération…'
              : hasDescription
                  ? "Améliorer avec l'IA"
                  : "Générer avec l'IA",
        ),
      ),
    );
  }
}
