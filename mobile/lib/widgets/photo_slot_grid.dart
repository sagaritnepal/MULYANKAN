import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../core/upload_service.dart';

enum SlotState { empty, capturing, uploading, done, error }

class PhotoSlot {
  final String type;
  final String label;
  SlotState state = SlotState.empty;
  String? localPath;
  String? uploadedUrl;
  Future<UploadedFile>? uploadFuture;

  PhotoSlot(this.type, this.label);

  bool get isReady => state == SlotState.done;
}

/// The 5 required photo slots. Capture starts an upload immediately in the
/// background (parallel across slots, low-bandwidth requirement) so the
/// request can go live the moment the form is submitted, using whichever
/// URLs have already landed — see NewRequestScreen._submit. Bill book pages
/// are captured separately (BillbookPhotoPicker) since a bill book can have
/// several owner-transfer pages, not one fixed photo.
class PhotoSlotGrid extends StatefulWidget {
  final void Function(List<PhotoSlot> slots) onChanged;
  /// Pre-fills slots from an existing request when editing a draft, keyed
  /// by slot type. The slot starts already "done" with no local file —
  /// tapping it still lets the poster replace the photo.
  final Map<String, String>? initialUrls;

  const PhotoSlotGrid({super.key, required this.onChanged, this.initialUrls});

  @override
  State<PhotoSlotGrid> createState() => PhotoSlotGridState();
}

class PhotoSlotGridState extends State<PhotoSlotGrid> {
  final List<PhotoSlot> slots = [
    PhotoSlot('front', 'Front'),
    PhotoSlot('left', 'Left side'),
    PhotoSlot('right', 'Right side'),
    PhotoSlot('rear', 'Rear'),
    PhotoSlot('odometer', 'Odometer'),
  ];

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final initialUrls = widget.initialUrls;
    if (initialUrls != null) {
      for (final slot in slots) {
        final url = initialUrls[slot.type];
        if (url != null) {
          slot.uploadedUrl = url;
          slot.state = SlotState.done;
        }
      }
    }
  }

  bool get allCaptured => slots.every((s) => s.state != SlotState.empty);

  Future<void> _capture(PhotoSlot slot, ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;
    setState(() {
      slot.localPath = file.path;
      slot.state = SlotState.uploading;
    });
    widget.onChanged(slots);

    final future = UploadService.uploadPhoto(file.path);
    slot.uploadFuture = future;
    try {
      final uploaded = await future;
      if (!mounted) return;
      setState(() {
        slot.uploadedUrl = uploaded.url;
        slot.state = SlotState.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => slot.state = SlotState.error);
    }
    widget.onChanged(slots);
  }

  void _showSourcePicker(PhotoSlot slot) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _capture(slot, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _capture(slot, ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) {
        final slot = slots[i];
        return GestureDetector(
          onTap: () => _showSourcePicker(slot),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: slot.state == SlotState.error ? AppColors.urgent : AppColors.divider,
              ),
              image: slot.localPath != null
                  ? DecorationImage(image: FileImage(File(slot.localPath!)), fit: BoxFit.cover)
                  : (slot.uploadedUrl != null
                      ? DecorationImage(image: NetworkImage(slot.uploadedUrl!), fit: BoxFit.cover)
                      : null),
            ),
            child: (slot.localPath == null && slot.uploadedUrl == null)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppColors.muted),
                      const SizedBox(height: 6),
                      Text(slot.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.black54,
                      child: _StatusBadge(slot: slot),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PhotoSlot slot;
  const _StatusBadge({required this.slot});

  @override
  Widget build(BuildContext context) {
    switch (slot.state) {
      case SlotState.uploading:
        return const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      case SlotState.done:
        return const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16);
      case SlotState.error:
        return const Icon(Icons.error, color: Colors.redAccent, size: 16);
      default:
        return Text(slot.label, style: const TextStyle(color: Colors.white, fontSize: 11));
    }
  }
}
