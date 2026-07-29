import 'package:flutter/material.dart';

class CreatePollResult {
  final String question;
  final List<String> options;
  final bool allowMultiple;
  CreatePollResult(this.question, this.options, this.allowMultiple);
}

Future<CreatePollResult?> showCreatePollDialog(BuildContext context) {
  final questionController = TextEditingController();
  final optionControllers = [TextEditingController(), TextEditingController()];
  bool allowMultiple = false;

  return showDialog<CreatePollResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Create Poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              ...optionControllers.asMap().entries.map((entry) {
                final i = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: 'Option ${i + 1}',
                      suffixIcon: optionControllers.length > 2
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: () => setState(() => optionControllers.removeAt(i)),
                            )
                          : null,
                    ),
                  ),
                );
              }),
              if (optionControllers.length < 8)
                TextButton.icon(
                  onPressed: () => setState(() => optionControllers.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow multiple answers'),
                value: allowMultiple,
                onChanged: (v) => setState(() => allowMultiple = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final question = questionController.text.trim();
              final options = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
              if (question.isEmpty || options.length < 2) return;
              Navigator.pop(context, CreatePollResult(question, options, allowMultiple));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}
