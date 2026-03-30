import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../theme.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final DatabaseService _database = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<FaqItem> _faqs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFaqs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFaqs() async {
    try {
      final items = await _database.getFaqItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _faqs = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _faqs.where((faq) {
      final haystack = '${faq.question} ${faq.answer} ${faq.category}'.toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(title: const Text('FAQs')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.abzioBorder.withValues(alpha: 0.72)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search by question or category',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5DA),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Icon(Icons.help_outline_rounded, color: AbzioTheme.accentColor, size: 32),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _faqs.isEmpty ? 'No FAQs available yet' : 'No matching answers found',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _faqs.isEmpty
                                      ? 'Support articles will appear here as the team publishes them.'
                                      : 'Try another keyword or start a support chat for personal help.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.abzioSecondaryText, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final faq = filtered[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.abzioBorder.withValues(alpha: 0.68)),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  faq.question,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  faq.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: AbzioTheme.accentColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      faq.answer,
                                      style: TextStyle(
                                        color: context.abzioSecondaryText,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
