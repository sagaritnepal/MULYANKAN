import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/models/valuation_request.dart';
import '../core/photo_url.dart';

/// Swipeable photo viewer with a "n/total · type" caption — shared by
/// every screen that shows a request's photos (quote entry, request
/// detail). Falls back to a placeholder tile when there are no photos
/// yet (a freshly-created draft, for instance).
class PhotoCarousel extends StatefulWidget {
  final List<RequestPhoto> photos;
  const PhotoCarousel({super.key, required this.photos});

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
          child: const Center(child: Icon(Icons.photo_camera_outlined, color: AppColors.muted, size: 40)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          PageView.builder(
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Image.network(
              photoDisplayUrl(widget.photos[i].url),
              fit: BoxFit.cover,
              width: double.infinity,
              // A dead URL must not take the carousel down with it.
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surface,
                child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.muted, size: 36)),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('${_index + 1}/${widget.photos.length} · ${widget.photos[_index].type}',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
