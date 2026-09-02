import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/models/valuation_request.dart';
import '../../widgets/evidence_photo_picker.dart';
import '../../widgets/photo_slot_grid.dart';

const _brands = [
  'Bajaj', 'Honda', 'Hero', 'Yamaha', 'TVS', 'Royal Enfield',
  'KTM', 'Suzuki', 'Aprilia', 'Benelli', 'CFMoto', 'Other',
];
const _windowOptions = {180: '3 min', 300: '5 min', 600: '10 min'};

/// Same form for both flows: creating a bike from scratch (broadcasts
/// immediately) and editing an already-uploaded draft (still awaiting
/// "Start Valuation", so its fields aren't visible to any valuer yet).
class NewRequestScreen extends StatefulWidget {
  final ValuationRequestDetail? editing;
  const NewRequestScreen({super.key, this.editing});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _photoGridKey = GlobalKey<PhotoSlotGridState>();
  final _billbookPhotosKey = GlobalKey<EvidencePhotoPickerState>();
  final _taxClearancePhotosKey = GlobalKey<EvidencePhotoPickerState>();
  final _repairPhotosKey = GlobalKey<EvidencePhotoPickerState>();

  String _brand = _brands.first;
  final _model = TextEditingController();
  final _engineCc = TextEditingController();
  final _mfgYearAd = TextEditingController();
  final _plateNumber = TextEditingController();
  final _regZone = TextEditingController();
  final _kmRun = TextEditingController();
  int _ownerCount = 1;
  String _billBookStatus = 'original';
  String _accidentHistory = 'none';
  final _accidentNotes = TextEditingController();
  String _modifications = 'stock';
  final _modificationNotes = TextEditingController();
  final _colour = TextEditingController();
  final _conditionNotes = TextEditingController();
  final _maintenanceNotes = TextEditingController();
  final _customerAskingPrice = TextEditingController();
  final _targetBikeDescription = TextEditingController();
  final _targetBikePrice = TextEditingController();
  final _customerTopup = TextEditingController();
  String _urgency = 'now';
  int _windowSeconds = 300;

  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;

    _brand = _brands.contains(e.brand) ? e.brand : 'Other';
    _model.text = e.model;
    _engineCc.text = e.engineCc?.toString() ?? '';
    _mfgYearAd.text = e.mfgYearAd.toString();
    _plateNumber.text = e.plateNumber;
    _regZone.text = e.regZone ?? '';
    _kmRun.text = e.kmRun.toString();
    _ownerCount = e.ownerCount;
    _billBookStatus = e.billBookStatus;
    _accidentHistory = e.accidentHistory;
    _accidentNotes.text = e.accidentNotes ?? '';
    _modifications = e.modifications;
    _modificationNotes.text = e.modificationNotes ?? '';
    _colour.text = e.colour ?? '';
    _conditionNotes.text = e.conditionNotes ?? '';
    _maintenanceNotes.text = e.maintenanceNotes ?? '';
    _customerAskingPrice.text = e.customerAskingPrice?.toString() ?? '';
    _targetBikeDescription.text = e.targetBikeDescription ?? '';
    _targetBikePrice.text = e.targetBikePrice?.toString() ?? '';
    _customerTopup.text = e.customerTopup?.toString() ?? '';
    _urgency = e.urgency;
    _windowSeconds = _windowOptions.containsKey(e.windowSeconds) ? e.windowSeconds : 300;
  }

  static const _requiredSlotTypes = {'front', 'left', 'right', 'rear', 'odometer'};

  Map<String, String> get _requiredPhotoUrls => {
        for (final p in widget.editing?.photos ?? const [])
          if (_requiredSlotTypes.contains(p.type)) p.type: p.url,
      };

  List<String> _photoUrlsByType(String type) =>
      (widget.editing?.photos ?? const []).where((p) => p.type == type).map((p) => p.url).toList();

  int? _asInt(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

  Future<void> _submit({bool force = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final grid = _photoGridKey.currentState!;
    if (!grid.allCaptured) {
      setState(() => _error = 'Capture all 5 bike photos before broadcasting');
      return;
    }
    final billbookPhotos = _billbookPhotosKey.currentState?.photos ?? const [];
    if (billbookPhotos.isEmpty) {
      setState(() => _error = 'Add at least one bill book page (owner 1)');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Only URLs that have already finished uploading go with the create
    // call; the rest are attached as their uploads land — the request
    // still goes live immediately (low-bandwidth requirement).
    final readyPhotos = grid.slots
        .where((s) => s.state == SlotState.done)
        .map((s) => {'type': s.type, 'url': s.uploadedUrl})
        .toList();
    final pendingSlots = grid.slots.where((s) => s.state != SlotState.done).toList();

    // Bill book pages, tax clearance and repair evidence are all supplementary
    // photo lists — only ones already uploaded by now go with the broadcast;
    // any still mid-upload are simply skipped rather than delaying the whole
    // request (unlike the 5 required slots).
    for (final photo in billbookPhotos) {
      if (photo.uploadedUrl != null) {
        readyPhotos.add({'type': 'billbook', 'url': photo.uploadedUrl});
      }
    }
    for (final photo in _taxClearancePhotosKey.currentState?.photos ?? const []) {
      if (photo.uploadedUrl != null) {
        readyPhotos.add({'type': 'tax_clearance', 'url': photo.uploadedUrl});
      }
    }
    for (final photo in _repairPhotosKey.currentState?.photos ?? const []) {
      if (photo.uploadedUrl != null) {
        readyPhotos.add({'type': 'extra', 'url': photo.uploadedUrl});
      }
    }

    final body = {
      'brand': _brand,
      'model': _model.text.trim(),
      'engineCc': _asInt(_engineCc.text),
      'mfgYearAd': _asInt(_mfgYearAd.text),
      'plateNumber': _plateNumber.text.trim(),
      'regZone': _regZone.text.trim().isEmpty ? null : _regZone.text.trim(),
      'kmRun': _asInt(_kmRun.text) ?? 0,
      'ownerCount': _ownerCount,
      'billBookStatus': _billBookStatus,
      'accidentHistory': _accidentHistory,
      'accidentNotes': _accidentNotes.text.trim().isEmpty ? null : _accidentNotes.text.trim(),
      'modifications': _modifications,
      'modificationNotes': _modificationNotes.text.trim().isEmpty ? null : _modificationNotes.text.trim(),
      'colour': _colour.text.trim().isEmpty ? null : _colour.text.trim(),
      'conditionNotes': _conditionNotes.text.trim().isEmpty ? null : _conditionNotes.text.trim(),
      'maintenanceNotes': _maintenanceNotes.text.trim().isEmpty ? null : _maintenanceNotes.text.trim(),
      'customerAskingPrice': _asInt(_customerAskingPrice.text),
      'targetBikeDescription':
          _targetBikeDescription.text.trim().isEmpty ? null : _targetBikeDescription.text.trim(),
      'targetBikePrice': _asInt(_targetBikePrice.text),
      'customerTopup': _asInt(_customerTopup.text),
      'urgency': _urgency,
      'windowSeconds': _windowSeconds,
      'force': force,
      'photos': readyPhotos,
    };

    try {
      final String requestId;
      if (_isEditing) {
        await ApiClient.instance.dio.post('/requests/${widget.editing!.id}/edit', data: body);
        requestId = widget.editing!.id;
      } else {
        final res = await ApiClient.instance.dio.post('/requests', data: body);
        requestId = res.data['id'] as String;
      }

      // Attach the still-uploading photos as they finish, without blocking
      // the save — the request (or its live broadcast) already has
      // whichever photos were ready.
      for (final slot in pendingSlots) {
        slot.uploadFuture?.then((uploaded) {
          ApiClient.instance.dio.post('/requests/$requestId/photos', data: {
            'type': slot.type,
            'url': uploaded.url,
            'bytes': uploaded.bytes,
          });
        });
      }

      if (mounted) Navigator.of(context).pop(requestId);
    } on Object catch (e) {
      final existingId = _extractExistingRequestId(e);
      if (existingId != null && mounted) {
        final proceed = await _confirmDuplicate(existingId);
        if (proceed == true) return _submit(force: true);
        if (proceed == false && mounted) Navigator.of(context).pop();
        return;
      }
      setState(() => _error = _isEditing
          ? 'Could not save changes — check your connection and try again.'
          : 'Could not broadcast — check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _extractExistingRequestId(Object e) {
    try {
      final data = (e as dynamic).response.data;
      return data['existingRequestId'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _confirmDuplicate(String existingId) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Posted recently'),
        content: const Text('This plate was posted in the last 24 hours. Post a new request anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post anyway')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Valuation' : 'New Valuation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('Photos'),
            PhotoSlotGrid(key: _photoGridKey, onChanged: (_) {}, initialUrls: _requiredPhotoUrls),
            const SizedBox(height: 24),
            _SectionTitle('Bike details'),
            DropdownButtonFormField<String>(
              value: _brand,
              decoration: const InputDecoration(labelText: 'Brand'),
              items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _brand = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _mfgYearAd,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Manufacture year (AD)'),
                  validator: (v) => _asInt(v ?? '') == null ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _engineCc,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Engine CC'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Plate number', hintText: 'Ba 34 Pa 5271'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _regZone, decoration: const InputDecoration(labelText: 'Registration zone/province')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmRun,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kilometers run'),
              validator: (v) => _asInt(v ?? '') == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _billBookStatus,
              decoration: const InputDecoration(labelText: 'Bill book status'),
              items: const [
                DropdownMenuItem(value: 'original', child: Text('Original')),
                DropdownMenuItem(value: 'copy', child: Text('Copy')),
                DropdownMenuItem(value: 'blue_book_only', child: Text('Blue book only')),
                DropdownMenuItem(value: 'missing', child: Text('Missing')),
              ],
              onChanged: (v) => setState(() => _billBookStatus = v!),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Bill book — owner history'),
            Text(
              'Photograph each owner-transfer page in order. We work out '
              '${_ownerCount >= 4 ? '4th+' : _ordinal(_ownerCount)} hand from how many pages you add.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            EvidencePhotoPicker(
              key: _billbookPhotosKey,
              labelFor: (i) => 'Owner ${i + 1}',
              initialUrls: _photoUrlsByType('billbook'),
              onChanged: (photos) => setState(() => _ownerCount = photos.isEmpty ? 1 : photos.length),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Tax clearance'),
            EvidencePhotoPicker(
              key: _taxClearancePhotosKey,
              initialUrls: _photoUrlsByType('tax_clearance'),
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _accidentHistory,
              decoration: const InputDecoration(labelText: 'Accident history'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'minor', child: Text('Minor')),
                DropdownMenuItem(value: 'major', child: Text('Major')),
              ],
              onChanged: (v) => setState(() => _accidentHistory = v!),
            ),
            if (_accidentHistory != 'none') ...[
              const SizedBox(height: 12),
              TextFormField(controller: _accidentNotes, decoration: const InputDecoration(labelText: 'Accident notes')),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _modifications,
              decoration: const InputDecoration(labelText: 'Modifications'),
              items: const [
                DropdownMenuItem(value: 'stock', child: Text('Stock')),
                DropdownMenuItem(value: 'modified', child: Text('Modified')),
              ],
              onChanged: (v) => setState(() => _modifications = v!),
            ),
            if (_modifications == 'modified') ...[
              const SizedBox(height: 12),
              TextFormField(controller: _modificationNotes, decoration: const InputDecoration(labelText: 'Modification notes')),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _colour, decoration: const InputDecoration(labelText: 'Colour')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _conditionNotes,
              decoration: const InputDecoration(labelText: 'Condition notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _SectionTitle('Repair needed'),
            TextFormField(
              controller: _maintenanceNotes,
              decoration: const InputDecoration(labelText: 'Servicing / repair history'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            EvidencePhotoPicker(
              key: _repairPhotosKey,
              initialUrls: _photoUrlsByType('extra'),
              onChanged: (_) {},
            ),
            const SizedBox(height: 24),
            _SectionTitle('Deal context'),
            TextFormField(
              controller: _customerAskingPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Customer's asking price (NPR)"),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetBikeDescription,
              decoration: const InputDecoration(labelText: 'Bike from your stock they want'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetBikePrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'That bike\'s price (NPR)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerTopup,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cash top-up customer will add (NPR)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _urgency,
              decoration: const InputDecoration(labelText: 'Urgency'),
              items: const [
                DropdownMenuItem(value: 'now', child: Text('Customer waiting now')),
                DropdownMenuItem(value: 'later', child: Text('Decides later')),
              ],
              onChanged: (v) => setState(() => _urgency = v!),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Window'),
            SegmentedButton<int>(
              segments: _windowOptions.entries
                  .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                  .toList(),
              selected: {_windowSeconds},
              onSelectionChanged: (s) => setState(() => _windowSeconds = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : () => _submit(),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save changes' : 'Broadcast to valuers', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
