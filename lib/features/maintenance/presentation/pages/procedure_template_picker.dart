import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/procedure.dart';
import '../../data/procedure_templates.dart';
import 'procedure_form_page.dart';
import 'procedure_wizard_page.dart';

/// Selecteur de template pour creer une nouvelle procedure.
/// Affiche les templates predefinies et l'option "creer de zero".
class ProcedureTemplatePicker extends StatelessWidget {
  const ProcedureTemplatePicker({super.key});

  Future<void> _selectTemplate(
      BuildContext context, ProcedureTemplate? template) async {
    final result = await Navigator.of(context).push<ProcedureModel>(
      MaterialPageRoute(
        builder: (_) => ProcedureFormPage(template: template),
      ),
    );
    // Retourner le resultat au screen appelant
    if (context.mounted && result != null) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _openWizard(BuildContext context) async {
    final result = await Navigator.of(context).push<ProcedureModel>(
      MaterialPageRoute(
        builder: (_) => const ProcedureWizardPage(),
      ),
    );
    if (context.mounted && result != null) {
      Navigator.of(context).pop(result);
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
        title: const Text('Nouvelle procedure', style: AppTextStyles.h2),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () => _openWizard(context),
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Assistant'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gagnez du temps',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choisissez un modele et personnalisez-le selon vos besoins.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section templates
            const Text(
              'Modeles populaires',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Grille de templates
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: ProcedureTemplates.all.length,
              itemBuilder: (context, index) {
                final template = ProcedureTemplates.all[index];
                return _TemplateCard(
                  template: template,
                  onTap: () => _selectTemplate(context, template),
                );
              },
            ),

            const SizedBox(height: 24),

            // Option creer de zero
            const Text(
              'Ou commencez de zero',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _CreateFromScratchCard(
              onTap: () => _selectTemplate(context, null),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un template.
class _TemplateCard extends StatelessWidget {
  final ProcedureTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: template.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      template.icon,
                      color: template.color,
                      size: 20,
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
                      '${template.steps.length} etapes',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                template.nom,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                template.description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte "creer de zero".
class _CreateFromScratchCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateFromScratchCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Procedure personnalisee',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Definissez vos propres etapes',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
