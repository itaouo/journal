import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/collection_grid_item.dart';
import '../models/picture.dart';

class CollectionListTile extends StatelessWidget {
  final CollectionGridItem item;
  final VoidCallback onTap;

  const CollectionListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  ImageProvider? _imageProvider(Picture? picture) {
    if (picture == null) return null;
    final display = picture.withDisplayFallback();
    if (!display.isValid()) return null;
    return display.isLocalFile
        ? FileImage(File(display.pictureUrl))
        : NetworkImage(display.pictureUrl);
  }

  @override
  Widget build(BuildContext context) {
    final cover = item.coverPicture;
    final imageProvider = _imageProvider(cover);
    final hasImage = imageProvider != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.journalColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          Image(image: imageProvider, fit: BoxFit.cover)
                        else
                          ColoredBox(
                            color: Colors.white,
                            child: Icon(
                              item.placeholderIcon,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        if (item.isLocked && hasImage)
                          ImageFiltered(
                            imageFilter:
                                ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (item.isLocked)
                          ColoredBox(color: Colors.black.withValues(alpha: 0.15)),
                        if (item.isLocked)
                          const Center(
                            child: Icon(
                              Icons.lock,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
