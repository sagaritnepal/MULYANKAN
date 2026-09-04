import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../core/photo_url.dart';
import '../core/upload_service.dart';

class EvidencePhoto {
  /// Null for a photo that already existed on the request before this
  /// session (edit mode) — only freshly captured photos have a local file.
  final String? localPath;
  bool uploading;
  String? uploadedUrl;
  int? bytes;

  EvidencePhoto.local(this.localPath) : uploading = true;
  EvidencePhoto.remote(String url)
      : localPath = null,
        uploadedUrl = url,
        uploading = false;
}

/// An unbounded, add-as-you-go photo list — unlike PhotoSlotGrid's fixed
/// required slots, this is for supplementary document/evidence photos
/// (repair receipts, billbook owner-transfer pages, tax clearance
/// stickers). Each photo starts uploading the moment it's captured, same
/// low-bandwidth pattern as the required slots. Shared across a few
/// sections in NewRequestScreen rather than duplicated per section.
class EvidencePhotoPicker extends StatefulWidget {
  final void Function(List<EvidencePhoto> photos) onChanged;
  /// Optional per-thumbnail caption, e.g. "Owner 1" for billbook pages.
  final String Function(int index)? labelFor;
  /// Pre-fills the list from an existing request when editing a draft.
  final List<String>? initialUrls;

  const EvidencePhotoPicker({super.key, required this.onChanged, this.labelFor, this.initialUrls});

  @override
  State<EvidencePhotoPicker> createState() => EvidencePhotoPickerState();
}

class EvidencePhotoPickerState extends State<EvidencePhotoPicker> {
  final List<EvidencePhoto> photos = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    for (final url in widget.initialUrls ?? const <String>[]) {
      photos.add(EvidencePhoto.remote(url));
    }
  }

  Future<void> _add(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    final photo = EvidencePhoto.local(file.path);
    setState(() => photos.add(photo));
    widget.onChanged(photos);

    try {
      final uploaded = await UploadService.uploadPhoto(file.path);
      if (!mounted) return;
      setState(() {
        photo.uploading = false;
        photo.uploadedUrl = uploaded.url;
        photo.bytes = uploaded.bytes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => photos.remove(photo));
    }
    widget.onChanged(photos);
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _add(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _add(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  void _remove(EvidencePhoto photo) {
    setState(() => photos.remove(photo));
    widget.onChanged(photos);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in photos.asMap().entries)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                child: entry.value.localPath != null
                    ? Image.file(File(entry.value.localPath!), fit: BoxFit.cover)
                    : Image.network(photoDisplayUrl(entry.value.uploadedUrl!), fit: BoxFit.cover),
              ),
              if (entry.value.uploading)
                const Positioned.fill(
                  child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
              if (widget.labelFor != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      widget.labelFor!(entry.key),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _remove(entry.value),
                  child: const CircleAvatar(radius: 11, backgroundColor: AppColors.ink, child: Icon(Icons.close, size: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        GestureDetector(
          onTap: _showSourcePicker,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
            child: const Icon(Icons.add_a_photo_outlined, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
