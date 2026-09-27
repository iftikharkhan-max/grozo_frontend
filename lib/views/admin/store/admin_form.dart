import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/api.dart';
import '../../common/product_widgets.dart';

/// Small building blocks shared by the admin store screens.

const adminColor = Colors.indigo;

AppBar adminAppBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title),
      backgroundColor: adminColor,
      foregroundColor: Colors.white,
      actions: actions,
    );

Widget adminText(TextEditingController c, String label,
        {String? hint, bool required = false, int maxLines = 1, TextInputType? keyboard, TextDirection? direction}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : null),
        textDirection: direction,
        decoration: InputDecoration(labelText: required ? '$label *' : label, hintText: hint, alignLabelWithHint: maxLines > 1),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      ),
    );

/// Number field. [required] rejects empty; non-empty values must be numbers.
Widget adminNumber(TextEditingController c, String label, {String? hint, bool required = false, bool decimal = true}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: required ? '$label *' : label, hintText: hint),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return required ? 'Required' : null;
          return (decimal ? double.tryParse(t) : int.tryParse(t)) == null ? 'Enter a valid number' : null;
        },
      ),
    );

Widget adminSection(String title) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: adminColor, fontSize: 15)),
    );

String? blankToNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

void adminToast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

/// Shows the server's error (admin screens are English-only).
void adminError(BuildContext context, ApiResult res) => adminToast(
      context,
      res.isNetworkError ? 'No internet connection.' : (res.message ?? 'Save failed (error ${res.status}).'),
    );

/// Image chooser: shows the current image, lets the admin pick a new one.
class AdminImagePicker extends StatelessWidget {
  final String? currentUrl;
  final File? picked;
  final ValueChanged<File> onPicked;
  const AdminImagePicker({super.key, this.currentUrl, this.picked, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: picked != null ? Image.file(picked!, fit: BoxFit.cover) : NetImage(currentUrl, fallbackEmoji: '🖼️'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.image_outlined),
            label: Text(picked == null && (currentUrl ?? '').isEmpty ? 'Choose image' : 'Change image'),
            onPressed: () async {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
              if (x != null) onPicked(File(x.path));
            },
          ),
        ),
      ]),
    );
  }
}

/// Date picker field that stores `YYYY-MM-DD HH:MM:SS` (end of day) or null.
class AdminDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const AdminDateField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'Not set' : '${value!.day}/${value!.month}/${value!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(children: [
          Expanded(child: Text(text)),
          TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 3),
              );
              if (d != null) onChanged(DateTime(d.year, d.month, d.day, 23, 59, 59));
            },
            child: const Text('Pick'),
          ),
          if (value != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
        ]),
      ),
    );
  }
}

String? sqlDate(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

DateTime? parseServerDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String numText(dynamic v) {
  if (v == null) return '';
  final d = double.tryParse(v.toString());
  if (d == null) return v.toString();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
}

bool truthy(dynamic v) => v == true || v == 1 || v == '1';

/// Standard save button with a busy state.
class AdminSaveButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;
  final String label;
  const AdminSaveButton({super.key, required this.busy, required this.onPressed, this.label = 'SAVE'});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: adminColor, foregroundColor: Colors.white),
              onPressed: busy ? null : onPressed,
              child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
            ),
          ),
        ),
      );
}
