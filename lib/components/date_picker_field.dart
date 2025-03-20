import 'package:flutter/material.dart';

/// A reusable date picker field component that displays a date and allows selecting a new date.
class DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    Key? key,
    required this.selectedDate,
    required this.onDateChanged,
    this.label = 'Date',
    this.firstDate,
    this.lastDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2101),
        );
        if (picked != null && picked != selectedDate) {
          onDateChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          "${selectedDate.toLocal()}".split(' ')[0],
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
