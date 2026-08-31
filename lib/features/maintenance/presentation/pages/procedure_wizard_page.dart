import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/maintenance_repository.dart';
import '../../data/procedure_templates.dart';

/// Assistant guide pour creer une procedure etape par etape.
/// Offre une experience plus guidee que le formulaire standard.
class ProcedureWizardPage extends StatefulWidget {
  const ProcedureWizardPage({super.key});

  @override
  State<ProcedureWizardPage> createState() => _ProcedureWizardPageState();
}

class _ProcedureWizardPageState extends State<ProcedureWizardPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Donnees du wizard
  ProcedureTemplate? _selectedTemplate;
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<_WizardStep> _steps = [];

  late final MaintenanceRepository _repository;
  late final Business _business;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MaintenanceRepository>();
    _business = context.read<SessionController>().currentBusiness!;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedTemplate != null) {
      // Pre-remplir depuis le template
      _nomController.text = _selectedTemplate!.nom;
      _descriptionController.text = _selectedTemplate!.description;
      _steps = _selectedTemplate!.steps
          .map((s) => _WizardStep(
                nom: s.nom,
                type: s.type,
                obligatoire: s.obligatoire,
                description: s.description,
              ))
          .toList();
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return true; // Template optionnel
      case 1:
        return _nomController.text.trim().isNotEmpty;
      case 2:
        return _steps.isNotEmpty &&
            _steps.every((s) => s.nom.trim().isNotEmpty);
      case 3:
        return true;
      default:
        return false;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final stepsData = _steps.asMap().entries.map((e) => {
        'nom': e.value.nom.trim(),
        'ordre': e.key,
        'obligatoire': e.value.obligatoire,
        'type': e.value.type,
        'description': e.value.description.trim(),
      }).toList();

      final result = await _repository.createProcedure(
        _business.id,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        steps: stepsData,
      );

      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Assistant de creation', style: AppTextStyles.h2),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Indicateur de progression
          _ProgressIndicator(
            currentStep: _currentStep,
            steps: const [
              'Modele',
              'Informations',
              'Etapes',
              'Confirmation',
            ],
          ),

          // Contenu des etapes
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepTemplate(
                  selectedTemplate: _selectedTemplate,
                  onSelect: (t) => setState(() => _selectedTemplate = t),
                ),
                _StepInfo(
                  nomController: _nomController,
                  descriptionController: _descriptionController,
                  onChanged: () => setState(() {}),
                ),
                _StepSteps(
                  steps: _steps,
                  onAdd: () => setState(() => _steps.add(_WizardStep())),
                  onRemove: (i) => setState(() => _steps.removeAt(i)),
                  onUpdate: (i, s) => setState(() => _steps[i] = s),
                  onReorderItem: (oldIdx, newIdx) {
                    setState(() {
                      final step = _steps.removeAt(oldIdx);
                      _steps.insert(newIdx, step);
                    });
                  },
                ),
                _StepReview(
                  nom: _nomController.text,
                  description: _descriptionController.text,
                  template: _selectedTemplate,
                  steps: _steps,
                  error: _error,
                ),
              ],
            ),
          ),

          // Boutons de navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retour'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 1,
                    child: _currentStep == 3
                        ? PrimaryButton(
                            label: 'Creer la procedure',
                            icon: Icons.check,
                            isLoading: _saving,
                            onPressed: _canProceed && !_saving ? _save : null,
                          )
                        : PrimaryButton(
                            label: 'Continuer',
                            icon: Icons.arrow_forward,
                            onPressed: _canProceed ? _nextStep : null,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Donnees d'une etape dans le wizard.
class _WizardStep {
  String nom;
  String type;
  bool obligatoire;
  String description;

  _WizardStep({
    this.nom = '',
    this.type = 'OPERATION',
    this.obligatoire = true,
    this.description = '',
  });
}

/// Indicateur de progression.
class _ProgressIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const _ProgressIndicator({
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: i <= currentStep
                    ? AppColors.primary
                    : AppColors.inputBackground,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: i < currentStep
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: i <= currentStep
                              ? Colors.white
                              : AppColors.hint,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etape 1: Selection du template.
class _StepTemplate extends StatelessWidget {
  final ProcedureTemplate? selectedTemplate;
  final ValueChanged<ProcedureTemplate?> onSelect;

  const _StepTemplate({
    required this.selectedTemplate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choisissez un modele',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selectionnez un modele pre-defini pour gagner du temps, '
            'ou continuez sans modele pour creer une procedure personnalisee.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Option sans template
          _TemplateOption(
            title: 'Procedure personnalisee',
            subtitle: 'Partir de zero et tout definir',
            icon: Icons.add_circle_outline,
            color: AppColors.textSecondary,
            selected: selectedTemplate == null,
            onTap: () => onSelect(null),
          ),

          const SizedBox(height: 16),
          const Text(
            'Ou utilisez un modele',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Templates
          ...ProcedureTemplates.all.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TemplateOption(
                  title: t.nom,
                  subtitle: '${t.steps.length} etapes - ${t.description}',
                  icon: t.icon,
                  color: t.color,
                  selected: selectedTemplate == t,
                  onTap: () => onSelect(t),
                ),
              )),
        ],
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etape 2: Informations de base.
class _StepInfo extends StatelessWidget {
  final TextEditingController nomController;
  final TextEditingController descriptionController;
  final VoidCallback onChanged;

  const _StepInfo({
    required this.nomController,
    required this.descriptionController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations de base',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Donnez un nom et une description a votre procedure.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'NOM DE LA PROCEDURE *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nomController,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Ex: Nettoyage complet',
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.assignment_outlined,
                  color: AppColors.hint, size: 20),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'DESCRIPTION (OPTIONNEL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Decrivez cette procedure...',
              filled: true,
              fillColor: AppColors.inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etape 3: Definition des etapes.
class _StepSteps extends StatelessWidget {
  final List<_WizardStep> steps;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, _WizardStep) onUpdate;
  final void Function(int, int) onReorderItem;

  const _StepSteps({
    required this.steps,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.onReorderItem,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Definissez les etapes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ajoutez les etapes de votre procedure dans l\'ordre.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (steps.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.playlist_add, size: 48, color: AppColors.hint),
                  SizedBox(height: 12),
                  Text(
                    'Aucune etape',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cliquez sur "Ajouter" pour creer votre premiere etape.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              onReorderItem: onReorderItem,
              itemBuilder: (context, index) {
                final step = steps[index];
                return _WizardStepCard(
                  key: ValueKey(index),
                  index: index,
                  step: step,
                  onUpdate: (s) => onUpdate(index, s),
                  onRemove: () => onRemove(index),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WizardStepCard extends StatelessWidget {
  final int index;
  final _WizardStep step;
  final ValueChanged<_WizardStep> onUpdate;
  final VoidCallback onRemove;

  const _WizardStepCard({
    super.key,
    required this.index,
    required this.step,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: AppColors.hint),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: step.nom),
                  onChanged: (v) => onUpdate(_WizardStep(
                    nom: v,
                    type: step.type,
                    obligatoire: step.obligatoire,
                    description: step.description,
                  )),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nom de l\'etape',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.dangerText),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Type toggle
              ChoiceChip(
                label: const Text('Operation'),
                selected: step.type == 'OPERATION',
                onSelected: (_) => onUpdate(_WizardStep(
                  nom: step.nom,
                  type: 'OPERATION',
                  obligatoire: step.obligatoire,
                  description: step.description,
                )),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: step.type == 'OPERATION'
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Controle'),
                selected: step.type == 'CONTROLE',
                onSelected: (_) => onUpdate(_WizardStep(
                  nom: step.nom,
                  type: 'CONTROLE',
                  obligatoire: step.obligatoire,
                  description: step.description,
                )),
                selectedColor: AppColors.warning.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: step.type == 'CONTROLE'
                      ? AppColors.warningText
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Obligatoire toggle
              FilterChip(
                label: const Text('Requis'),
                selected: step.obligatoire,
                onSelected: (v) => onUpdate(_WizardStep(
                  nom: step.nom,
                  type: step.type,
                  obligatoire: v,
                  description: step.description,
                )),
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: step.obligatoire
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Etape 4: Revue finale.
class _StepReview extends StatelessWidget {
  final String nom;
  final String description;
  final ProcedureTemplate? template;
  final List<_WizardStep> steps;
  final String? error;

  const _StepReview({
    required this.nom,
    required this.description,
    required this.template,
    required this.steps,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verifiez votre procedure',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Relisez les informations avant de creer votre procedure.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Resume
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (template?.color ?? AppColors.primary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        template?.icon ?? Icons.assignment_outlined,
                        color: template?.color ?? AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nom.isEmpty ? '(Sans nom)' : nom,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (template != null)
                            Text(
                              'Base sur: ${template!.nom}',
                              style: TextStyle(
                                fontSize: 12,
                                color: template!.color,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Liste des etapes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Etapes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${steps.length} etape${steps.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...steps.asMap().entries.map((e) {
                  final i = e.key;
                  final step = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: step.type == 'CONTROLE'
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: step.type == 'CONTROLE'
                                  ? AppColors.warningText
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.nom.isEmpty ? '(Sans nom)' : step.nom,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!step.obligatoire)
                          const Text(
                            'Optionnel',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.hint,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Erreur
          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.dangerText.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.dangerText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.dangerText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
