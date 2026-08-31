import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/skeleton/skeleton.dart';
import '../../../auth/presentation/session_controller.dart';
import '../../../business/data/models/business.dart';
import '../../data/items_repository.dart';
import '../../data/models/category.dart';
import '../../utils/category_images.dart';
import 'category_detail_page.dart';
import 'new_category_page.dart';

/// Liste des catégories du catalogue.
class CategoriesListPage extends StatefulWidget {
  const CategoriesListPage({super.key});

  @override
  State<CategoriesListPage> createState() => _CategoriesListPageState();
}

class _CategoriesListPageState extends State<CategoriesListPage> {
  late final ItemsRepository _repository;
  late final Business _business;

  List<CategoryModel> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<ItemsRepository>();
    _business = context.read<SessionController>().currentBusiness!;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _repository.categories(_business.id);
      if (mounted) setState(() => _categories = categories);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewCategory() async {
    final created = await Navigator.of(context).push<CategoryModel>(
      MaterialPageRoute(builder: (_) => const NewCategoryPage()),
    );
    if (created != null && mounted) {
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catégorie « ${created.nom} » ajoutée.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashSurfaceLow,
      appBar: AppBar(
        backgroundColor: AppColors.dashSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Catégories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dashPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.dashPrimary),
            tooltip: 'Nouvelle catégorie',
            onPressed: _openNewCategory,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? Skeleton(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: 6,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, _) => const SkeletonCard(
                    padding: EdgeInsets.all(16),
                    radius: 16,
                    child: SkeletonListItem(),
                  ),
                ),
              )
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : _categories.isEmpty
                    ? _EmptyState(onCreate: _openNewCategory)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.dashSecondary,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return _CategoryCard(
                              category: category,
                              onTap: () async {
                                await Navigator.of(context).push<CategoryModel>(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryDetailPage(categoryId: category.id),
                                  ),
                                );
                                if (mounted) _load();
                              },
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = CategoryImages.getCategoryImage(
      localImage: category.image,
      categoryName: category.nom,
    );
    final isLocal = CategoryImages.isLocalImage(category.image);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dashOutlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image de la catégorie (locale ou distante) ou icône par défaut
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.dashPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isLocal
                        ? Image.file(
                            File(imageUrl),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.category_outlined,
                              size: 28,
                              color: AppColors.dashPrimary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Nom
                Expanded(
                  child: Text(
                    category.nom,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.dashOnSurface,
                        ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.dangerText),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune catégorie',
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créez votre première catégorie pour organiser votre catalogue.',
                    style: AppTextStyles.body.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une catégorie'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}