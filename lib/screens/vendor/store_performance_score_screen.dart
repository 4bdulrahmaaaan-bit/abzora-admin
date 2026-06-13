import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StorePerformanceScoreScreen extends StatelessWidget {
  const StorePerformanceScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const score = 78;
    final factors = <_Factor>[
      const _Factor('Order Acceptance Rate', 20, 16),
      const _Factor('Delivery Speed', 20, 15),
      const _Factor('Conversion Rate', 20, 14),
      const _Factor('Stock Availability', 20, 18),
      const _Factor('Return Rate', 20, 15),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        title: Text(
          'Store Score',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 11,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF2E9C55),
                        ),
                        backgroundColor: const Color(0xFFE7DECF),
                      ),
                      Center(
                        child: Text(
                          '$score / 100',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _statusBadge(score),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score Factors',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...factors.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${f.name} -> ${f.weight}%',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '+${f.points}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: f.points / f.weight,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFEDE3D4),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFD0A84F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actionable Insights',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _insight('Improve acceptance rate to gain +10 points'),
                _insight('Low stock is reducing your score'),
                _insight('Faster dispatch can boost conversions'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'High score unlocks better visibility, priority dispatch, and future lower commission tiers.',
                  style: GoogleFonts.inter(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _button('Improve Score', filled: true)),
              const SizedBox(width: 10),
              Expanded(child: _button('View Details', filled: false)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Live updates based on orders, delivery and returns.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6D665A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(int score) {
    final (label, color) = score >= 90
        ? ('Excellent', const Color(0xFFD0A84F))
        : score >= 70
        ? ('Good', const Color(0xFF2E9C55))
        : score >= 50
        ? ('Needs Improvement', const Color(0xFFC98A1D))
        : ('Critical', const Color(0xFFC03C2E));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8DECE)),
    ),
    child: child,
  );

  Widget _insight(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          size: 16,
          color: Color(0xFFD0A84F),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter())),
      ],
    ),
  );

  Widget _button(String text, {required bool filled}) => SizedBox(
    height: 44,
    child: filled
        ? ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A84F),
              foregroundColor: Colors.white,
            ),
            child: Text(text),
          )
        : OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD0A84F),
              side: const BorderSide(color: Color(0xFFD0A84F)),
            ),
            child: Text(text),
          ),
  );
}

class _Factor {
  const _Factor(this.name, this.weight, this.points);
  final String name;
  final int weight;
  final int points;
}
