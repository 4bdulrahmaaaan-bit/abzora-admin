import 'package:flutter/material.dart';

class RefundTimelineScreen extends StatelessWidget {
  const RefundTimelineScreen({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund Timeline')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: steps.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (_, index) => ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: Text(steps[index]),
        ),
      ),
    );
  }
}
