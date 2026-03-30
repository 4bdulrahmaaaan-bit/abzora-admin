import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_config.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/abzio_motion.dart';
import '../../widgets/tap_scale.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final DatabaseService _database = DatabaseService();
  bool _codeCopied = false;

  Future<void> _copyText(String text, {String message = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    setState(() => _codeCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _codeCopied = false);
    }
  }

  String _shareMessage(String code) {
    return 'Get Rs 75 on ABZORA\nUse my code: $code\nDownload now: ${AppConfig.appDownloadLink}';
  }

  Future<void> _shareWhatsApp(String code) async {
    final message = Uri.encodeComponent(_shareMessage(code));
    final url = 'https://wa.me/?text=$message';
    if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened right now.')),
      );
    }
  }

  Future<void> _shareSystem(String code) async {
    await Share.share(_shareMessage(code));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        appBar: AppBar(
          title: const Text('Refer & Earn'),
        ),
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<ReferralDashboardData>(
                future: _database.getReferralDashboard(user),
                builder: (context, snapshot) {
                  final dashboard = snapshot.data;
                  final code = dashboard?.referralCode ?? (user.referralCode ?? '');
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFFFFFCF4),
                                AbzioTheme.accentColor.withValues(alpha: 0.08),
                                const Color(0xFFFFFBF7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AbzioStaggerItem(
                              index: 0,
                              child: _heroCard(context, code),
                            ),
                            const SizedBox(height: 18),
                            AbzioStaggerItem(
                              index: 1,
                              child: _inviteCodeCard(context, code),
                            ),
                            const SizedBox(height: 18),
                            AbzioStaggerItem(
                              index: 2,
                              child: _shareCard(context, code),
                            ),
                            const SizedBox(height: 18),
                            AbzioStaggerItem(
                              index: 3,
                              child: _rewardSnapshot(
                                context,
                                invitedCount: dashboard?.invitedCount ?? 0,
                                earnedCredits: dashboard?.earnedCredits ?? 0,
                                walletBalance: dashboard?.walletBalance ?? user.walletBalance,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AbzioStaggerItem(
                              index: 4,
                              child: _tierCard(
                                context,
                                tier: dashboard?.tier ?? 'Bronze',
                                progress: dashboard?.nextTierProgress ?? 0,
                                invitesToNextTier: dashboard?.invitesToNextTier ?? 4,
                                completedCount: dashboard?.completedCount ?? 0,
                              ),
                            ),
                            const SizedBox(height: 18),
                            AbzioStaggerItem(
                              index: 5,
                              child: _howItWorks(context),
                            ),
                            if ((dashboard?.history.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 18),
                              AbzioStaggerItem(
                                index: 6,
                                child: _historyCard(context, dashboard!.history),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
        bottomNavigationBar: user == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: context.abzioBorder)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: TapScale(
                    onTap: () async {
                      final code = await _database.ensureReferralCode(user);
                      if (!mounted) {
                        return;
                      }
                      await _shareSystem(code);
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE1C768), AbzioTheme.accentColor],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final code = await _database.ensureReferralCode(user);
                          if (!mounted) {
                            return;
                          }
                          await _shareSystem(code);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Invite & Earn Rs 75',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF7E3),
            AbzioTheme.accentColor.withValues(alpha: 0.16),
            Colors.white,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2CC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Limited time',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AbzioTheme.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Earn Rs 75 for every friend',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            'They get Rs 75. You get Rs 75 when they place their first order of Rs 499 or more.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.abzioSecondaryText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: AbzioTheme.accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  code.isEmpty ? 'Generating your invite code...' : 'Share your premium invite and grow ABZORA smarter.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inviteCodeCard(BuildContext context, String code) {
    return _shell(
      context,
      title: 'Invite Code',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AbzioTheme.accentColor.withValues(alpha: 0.36), width: 1.4),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFFFFAEF),
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code.isEmpty ? 'Loading...' : code,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 28,
                      letterSpacing: 2,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            TapScale(
              onTap: code.isEmpty ? null : () => _copyText(code, message: 'Copied ✓'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _codeCopied ? const Color(0xFF2E9E5B) : AbzioTheme.accentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _codeCopied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _codeCopied ? 'Copied' : 'Copy',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareCard(BuildContext context, String code) {
    return _shell(
      context,
      title: 'Share',
      subtitle: 'Make it effortless for friends to join with your code.',
      child: Row(
        children: [
          Expanded(
            child: _shareButton(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp',
              onTap: code.isEmpty ? null : () => _shareWhatsApp(code),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shareButton(
              context,
              icon: Icons.link_rounded,
              label: 'Copy Link',
              onTap: () => _copyText(AppConfig.appDownloadLink, message: 'Link copied ✓'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _shareButton(
              context,
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onTap: code.isEmpty ? null : () => _shareSystem(code),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardSnapshot(
    BuildContext context, {
    required int invitedCount,
    required double earnedCredits,
    required double walletBalance,
  }) {
    return _shell(
      context,
      title: 'Reward Snapshot',
      child: Row(
        children: [
          Expanded(child: _statCard(context, 'Friends invited', '$invitedCount')),
          const SizedBox(width: 12),
          Expanded(child: _statCard(context, 'Credits earned', 'Rs ${earnedCredits.toStringAsFixed(0)}', highlight: true)),
          const SizedBox(width: 12),
          Expanded(child: _statCard(context, 'Wallet balance', 'Rs ${walletBalance.toStringAsFixed(0)}')),
        ],
      ),
    );
  }

  Widget _tierCard(
    BuildContext context, {
    required String tier,
    required double progress,
    required int invitesToNextTier,
    required int completedCount,
  }) {
    final helper = invitesToNextTier == 0
        ? 'You are already in Gold tier with the highest reward per invite.'
        : '$invitesToNextTier more completed invite${invitesToNextTier == 1 ? '' : 's'} to reach the next tier.';
    return _shell(
      context,
      title: 'Reward Tiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _tierPill(context, 'Bronze', 'Rs 75', tier == 'Bronze')),
              const SizedBox(width: 10),
              Expanded(child: _tierPill(context, 'Silver', 'Rs 100', tier == 'Silver')),
              const SizedBox(width: 10),
              Expanded(child: _tierPill(context, 'Gold', 'Rs 150', tier == 'Gold')),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: context.abzioMuted,
              valueColor: const AlwaysStoppedAnimation<Color>(AbzioTheme.accentColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$completedCount successful referral${completedCount == 1 ? '' : 's'} so far.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
          ),
        ],
      ),
    );
  }

  Widget _howItWorks(BuildContext context) {
    final steps = [
      ('1', 'Share your code', 'Send your premium invite code to friends.'),
      ('2', 'They sign up', 'Your friend joins ABZORA using your code.'),
      ('3', 'They place an order', 'Their first order must be Rs 499 or more.'),
      ('4', 'Both earn credits', 'You both receive ABZORA Credits automatically.'),
    ];
    return _shell(
      context,
      title: 'How It Works',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _stepRow(context, steps[i].$1, steps[i].$2, steps[i].$3),
            if (i != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(BuildContext context, List<ReferralRecord> history) {
    return _shell(
      context,
      title: 'Recent Invites',
      subtitle: 'Track who is pending and who has already unlocked rewards.',
      child: Column(
        children: history.take(6).map((item) {
          final completed = item.rewardGiven;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: completed ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: completed
                      ? AbzioTheme.accentColor.withValues(alpha: 0.22)
                      : context.abzioBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? AbzioTheme.accentColor.withValues(alpha: 0.16)
                          : context.abzioMuted,
                    ),
                    child: Icon(
                      completed ? Icons.workspace_premium_rounded : Icons.person_add_alt_1_rounded,
                      color: completed ? AbzioTheme.accentColor : context.abzioSecondaryText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed ? 'Referral completed' : 'Pending reward',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          completed
                              ? 'You earned Rs ${item.referrerReward.toStringAsFixed(0)} from this referral.'
                              : 'Waiting for the friend\'s first qualifying order.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.abzioSecondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _shell(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.abzioBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.abzioSecondaryText),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _shareButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.abzioBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AbzioTheme.accentColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? AbzioTheme.accentColor.withValues(alpha: 0.22) : context.abzioBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: highlight ? AbzioTheme.accentColor : AbzioTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
          ),
        ],
      ),
    );
  }

  Widget _tierPill(BuildContext context, String name, String reward, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFFBF0) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AbzioTheme.accentColor : context.abzioBorder,
          width: active ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: active ? AbzioTheme.accentColor : AbzioTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            reward,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.abzioSecondaryText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(BuildContext context, String number, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AbzioTheme.accentColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(color: AbzioTheme.accentColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
