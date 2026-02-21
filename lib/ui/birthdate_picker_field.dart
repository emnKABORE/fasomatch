import 'package:flutter/material.dart';
import 'primary_button.dart';

class BirthdatePickerField extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  const BirthdatePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<BirthdatePickerField> createState() => _BirthdatePickerFieldState();
}

class _BirthdatePickerFieldState extends State<BirthdatePickerField> {
  String _format(DateTime? d) {
    if (d == null) return "";
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return "$dd/$mm/${d.year}";
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) return;

    final now = DateTime.now();
    final init = widget.value ?? DateTime(now.year - 20, 1, 1);

    int selectedDay = init.day;
    int selectedMonth = init.month;
    int selectedYear = init.year;

    final years = List.generate(100, (i) => now.year - i); // 100 années
    final months = List.generate(12, (i) => i + 1);

    int daysInMonth(int y, int m) {
      final firstNext = (m == 12) ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
      return firstNext.subtract(const Duration(days: 1)).day;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final maxDays = daysInMonth(selectedYear, selectedMonth);
            final days = List.generate(maxDays, (i) => i + 1);
            if (selectedDay > maxDays) selectedDay = maxDays;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Date de naissance",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedDay,
                          items: days
                              .map((d) => DropdownMenuItem(value: d, child: Text(d.toString())))
                              .toList(),
                          onChanged: (v) => setSheet(() => selectedDay = v ?? selectedDay),
                          decoration: const InputDecoration(labelText: "Jour"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          items: months
                              .map((m) => DropdownMenuItem(value: m, child: Text(m.toString())))
                              .toList(),
                          onChanged: (v) => setSheet(() => selectedMonth = v ?? selectedMonth),
                          decoration: const InputDecoration(labelText: "Mois"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          items: years
                              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (v) => setSheet(() => selectedYear = v ?? selectedYear),
                          decoration: const InputDecoration(labelText: "Année"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: "OK",
                    width: double.infinity,
                    onPressed: () {
                      final picked = DateTime(selectedYear, selectedMonth, selectedDay);
                      widget.onChanged(picked);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      enabled: widget.enabled,
      onTap: _openPicker,
      decoration: InputDecoration(
        labelText: "Date de naissance",
        hintText: "JJ/MM/AAAA",
        suffixIcon: const Icon(Icons.calendar_month),
        filled: true,
        fillColor: Colors.white.withOpacity(0.75),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      controller: TextEditingController(text: _format(widget.value)),
    );
  }
}