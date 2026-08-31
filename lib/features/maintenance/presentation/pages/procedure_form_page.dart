import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/custom_input_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/maintenance_repository.dart';
import '../../data/models/procedure.dart';
import '../../data/procedure_templates.dart';

/// Formulaire de creation/edition d'une procedure (US-13, US-14).
class ProcedureFormPage extends StatefulWidget {
  /// Si fourni, on edite cette procedure.
  final ProcedureModel? procedure;

  /// Si fourni (creation), pre-remplit avec ce template.
  final ProcedureTemplate? template;

  const ProcedureFormPage({super.key, this.procedure, this.template});

  bool get isEditing => procedure != null;

  @override
  State<ProcedureFormPage> createState() => _ProcedureFormPageState();
}

class _ProcedureFormPageState extends State<ProcedureFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final MaintenanceRepository _repository;
  late final Business _business;

  bool _estActif = true;
  List<_StepDraft> _steps = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MaintenanceRepository>();
    _business = context.read<SessionController>().currentBusiness!;

    if (widget.isEditing) {
      // Edition : charger les donnees existantes
      final p = widget.procedure!;
      _nomController.text = p.nom;
      _descriptionController.text = p.description;
      _estActif = p.estActif;
      _steps = p.steps
          .map((s) => _StepDraft(
                nom: s.nom,
                type: s.type,
                obligatoire: s.obligatoire,
                description: s.description,
              ))
          .toList();
    } else if (widget.template != null) {
      // Creation depuis template : pre-remplir
      final t = widget.template!;
      _nomController.text = t.nom;
      _descriptionController.text = t.description;
      _steps = t.steps
          .map((s) => _StepDraft(
                nom: s.nom,
                type: s.type,
                obligatoire: s.obligatoire,
                description: s.description,
              ))
          .toList();
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(_StepDraft());
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_steps.isEmpty) {
      setState(() => _error = 'Ajoutez au moins une etape.');
      return;
    }

    // Valider les noms des etapes
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].nom.trim().isEmpty) {
        setState(() => _error = 'L\'etape ${i + 1} n\'a pas de nom.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final stepsData = _steps
          .asMap()
          .entries
          .map((e) => {
                'nom': e.value.nom.trim(),
                'ordre': e.key,
                'obligatoire': e.value.obligatoire,
                'type': e.value.type,
                'description': e.value.description.trim(),
              })
          .toList();

      ProcedureModel result;
      if (widget.isEditing) {
        result = await _repository.updateProcedure(
          _business.id,
          widget.procedure!.id,
          nom: _nomController.text.trim(),
          description: _descriptionController.text.trim(),
          estActif: _estActif,
          steps: stepsData,
        );
      } else {
        result = await _repository.createProcedure(
          _business.id,
          nom: _nomController.text.trim(),
          description: _descriptionController.text.trim(),
          steps: stepsData,
        );
      }

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
        title: Text(
          widget.isEditing ? 'Modifier la procedure' : 'Nouvelle procedure',
          style: AppTextStyles.h2,
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge template si utilise
                    if (widget.template != null && !widget.isEditing) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.template!.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.template!.icon,
                              size: 16,
                              color: widget.template!.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Base sur: ${widget.template!.nom}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.template!.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nom
                    CustomInputField(
                      label: 'Nom de la procedure *',
                      hint: 'Ex: Nettoyage complet',
                      controller: _nomController,
                      prefixIcon: Icons.assignment_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        if (value.length > 200) {
                          return 'Maximum 200 caracteres';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Description
                    CustomInputField(
                      label: 'Description (optionnel)',
                      hint: 'Decrivez cette procedure...',
                      controller: _descriptionController,
                      prefixIcon: Icons.notes_outlined,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Actif (seulement en edition)
                    if (widget.isEditing)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.toggle_on_outlined,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Procedure active',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _estActif
                                        ? 'Peut etre utilisee pour creer des taches'
                                        : 'N\'apparait plus dans la liste',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _estActif,
                              onChanged: (v) => setState(() => _estActif = v),
                              activeTrackColor:
                                  AppColors.primary.withValues(alpha: 0.5),
                              thumbColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.primary;
                                }
                                return null;
                              }),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Section etapes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Etapes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addStep,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_steps.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.playlist_add,
                                size: 40, color: AppColors.hint),
                            SizedBox(height: 8),
                            Text(
                              'Aucune etape',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ajoutez des etapes pour definir le processus.',
                              style: TextStyle(
                                fontSize: 12,
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
                        itemCount: _steps.length,
                        onReorderItem: _reorderSteps,
                        itemBuilder: (context, index) {
                          return _StepCard(
                            key: ValueKey(index),
                            index: index,
                            step: _steps[index],
                            onChanged: (updated) {
                              setState(() => _steps[index] = updated);
                            },
                            onRemove: () => _removeStep(index),
                          );
                        },
                      ),

                    // Erreur
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _error!),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bouton sauvegarder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label:
                      widget.isEditing ? 'Enregistrer' : 'Creer la procedure',
                  icon: Icons.check,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brouillon d'une etape (avant sauvegarde).
class _StepDraft {
  String nom;
  String type;
  bool obligatoire;
  String description;

  _StepDraft({
    this.nom = '',
    this.type = 'OPERATION',
    this.obligatoire = true,
    this.description = '',
  });
}

/// Carte d'une etape dans le formulaire avec auto-completion.
class _StepCard extends StatefulWidget {
  final int index;
  final _StepDraft step;
  final ValueChanged<_StepDraft> onChanged;
  final VoidCallback onRemove;

  const _StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.step.nom;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(_controller.text);
    } else {
      setState(() => _showSuggestions = false);
    }
  }

  void _updateSuggestions(String query) {
    final suggestions = ProcedureTemplates.searchSuggestions(query);
    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    widget.onChanged(_StepDraft(
      nom: suggestion,
      type: widget.step.type,
      obligatoire: widget.step.obligatoire,
      description: widget.step.description,
    ));
    setState(() => _showSuggestions = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
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
                    // Handle pour reorder
                    ReorderableDragStartListener(
                      index: widget.index,
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
                        '${widget.index + 1}',
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
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (v) {
                          _updateSuggestions(v);
                          widget.onChanged(_StepDraft(
                            nom: v,
                            type: widget.step.type,
                            obligatoire: widget.step.obligatoire,
                            description: widget.step.description,
                          ));
                        },
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
                      onPressed: widget.onRemove,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Type et obligatoire
                Row(
                  children: [
                    // Type: Operation ou Controle
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onChanged(_StepDraft(
                                  nom: widget.step.nom,
                                  type: 'OPERATION',
                                  obligatoire: widget.step.obligatoire,
                                  description: widget.step.description,
                                )),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: widget.step.type == 'OPERATION'
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_circle_outline,
                                        size: 14,
                                        color: widget.step.type == 'OPERATION'
                                            ? AppColors.primary
                                            : AppColors.hint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Operation',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: widget.step.type == 'OPERATION'
                                              ? AppColors.primary
                                              : AppColors.hint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => widget.onChanged(_StepDraft(
                                  nom: widget.step.nom,
                                  type: 'CONTROLE',
                                  obligatoire: widget.step.obligatoire,
                                  description: widget.step.description,
                                )),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: widget.step.type == 'CONTROLE'
                                        ? AppColors.surface
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 14,
                                        color: widget.step.type == 'CONTROLE'
                                            ? AppColors.warningText
                                            : AppColors.hint,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Controle',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: widget.step.type == 'CONTROLE'
                                              ? AppColors.warningText
                                              : AppColors.hint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Obligatoire
                    GestureDetector(
                      onTap: () => widget.onChanged(_StepDraft(
                        nom: widget.step.nom,
                        type: widget.step.type,
                        obligatoire: !widget.step.obligatoire,
                        description: widget.step.description,
                      )),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.step.obligatoire
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.step.obligatoire
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 14,
                              color: widget.step.obligatoire
                                  ? AppColors.primary
                                  : AppColors.hint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Requis',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.step.obligatoire
                                    ? AppColors.primary
                                    : AppColors.hint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Suggestions
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _suggestions.map((s) {
                  return InkWell(
                    onTap: () => _selectSuggestion(s),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.toLowerCase().contains('controle') ||
                                    s.toLowerCase().contains('verification') ||
                                    s.toLowerCase().contains('inspection')
                                ? Icons.verified_outlined
                                : Icons.play_circle_outline,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banniere d'erreur.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerText.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.dangerText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.dangerText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
