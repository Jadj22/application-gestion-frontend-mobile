import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/maintenance_task.dart';

/// Widget pour capturer et afficher les photos avant/après - Sprint 2.
/// Permet de prendre ou sélectionner des photos pour documenter les étapes.
class StepPhotoWidget extends StatelessWidget {
  final List<TaskStepPhotoModel> photos;
  final bool canAdd;
  final void Function(File file, String type)? onPhotoAdded;
  final void Function(String photoId)? onPhotoDeleted;

  const StepPhotoWidget({
    super.key,
    required this.photos,
    this.canAdd = true,
    this.onPhotoAdded,
    this.onPhotoDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final avantPhotos = photos.where((p) => p.type == 'AVANT').toList();
    final apresPhotos = photos.where((p) => p.type == 'APRES').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PhotoSection(
                title: 'Avant',
                type: 'AVANT',
                photos: avantPhotos,
                canAdd: canAdd,
                onPhotoAdded: onPhotoAdded,
                onPhotoDeleted: onPhotoDeleted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PhotoSection(
                title: 'Après',
                type: 'APRES',
                photos: apresPhotos,
                canAdd: canAdd,
                onPhotoAdded: onPhotoAdded,
                onPhotoDeleted: onPhotoDeleted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final String type;
  final List<TaskStepPhotoModel> photos;
  final bool canAdd;
  final void Function(File file, String type)? onPhotoAdded;
  final void Function(String photoId)? onPhotoDeleted;

  const _PhotoSection({
    required this.title,
    required this.type,
    required this.photos,
    required this.canAdd,
    this.onPhotoAdded,
    this.onPhotoDeleted,
  });

  Future<void> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      onPhotoAdded?.call(File(image.path), type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                type == 'AVANT' ? Icons.photo_camera_back : Icons.photo_camera_front,
                size: 16,
                color: type == 'AVANT' ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: type == 'AVANT' ? Colors.blue : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (photos.isEmpty)
            if (canAdd)
              InkWell(
                onTap: () => _pickImage(context),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajouter',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Aucune photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              )
          else
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length + (canAdd ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == photos.length && canAdd) {
                    return _AddPhotoButton(onTap: () => _pickImage(context));
                  }
                  return _PhotoThumbnail(
                    photo: photos[index],
                    onDelete: canAdd ? onPhotoDeleted : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final TaskStepPhotoModel photo;
  final void Function(String photoId)? onDelete;

  const _PhotoThumbnail({
    required this.photo,
    this.onDelete,
  });

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Image.network(
                  photo.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 48),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            if (photo.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  photo.caption,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullImage(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                photo.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onDelete!(photo.id),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

/// Widget compact pour afficher le nombre de photos.
class PhotoCountBadge extends StatelessWidget {
  final int count;

  const PhotoCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
