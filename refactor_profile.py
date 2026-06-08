import os
import re

file_path = r'c:\Users\AAA\Documents\abzio\lib\screens\user\profile_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Rename _buildEliteCard to _buildProfileHeaderCard
content = content.replace('Widget _buildEliteCard(', 'Widget _buildProfileHeaderCard(')
content = content.replace('_buildEliteCard(', '_buildProfileHeaderCard(')

# 2. Remove _eliteBadge() usage and definition
content = content.replace('child: _eliteBadge(),', '')

elite_badge_def_start = content.find('  Widget _eliteBadge() {')
if elite_badge_def_start != -1:
    elite_badge_def_end = content.find('  Widget _buildValueStrip', elite_badge_def_start)
    content = content[:elite_badge_def_start] + content[elite_badge_def_end:]

# 3. Profile Completion Logic in _buildProfileHeaderCard
completion_target = """          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: completionScore / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.abzioBorder.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color(0xFFD6BA67),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completionScore%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Complete your profile to unlock faster checkout',
            style: TextStyle(
              color: context.abzioSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),"""

completion_replacement = """          const SizedBox(height: 12),
          if (completionScore >= 100)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFFC6A769), size: 18),
                  SizedBox(width: 8),
                  Text('Profile Verified', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111111))),
                ],
              ),
            )
          else ...[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: completionScore / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.abzioBorder.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFFD6BA67),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$completionScore%',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Complete your profile to unlock faster checkout',
              style: TextStyle(
                color: context.abzioSecondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],"""
content = content.replace(completion_target, completion_replacement)

# 4. Remove _vendorOnboardingCard
vendor_card_start = content.find('  Widget _vendorOnboardingCard(')
if vendor_card_start != -1:
    vendor_card_end = content.find('  Widget _buildShoppingEssentials', vendor_card_start)
    if vendor_card_end == -1:
        vendor_card_end = content.find('  Widget _buildSettingsList', vendor_card_start)
    
    # Actually wait, let's just find exactly where _vendorOnboardingCard ends.
    # It ends when we see "  Widget _buildShoppingEssentials"
    pass

# Let's replace _buildGrowthSection and _vendorOnboardingCard with _buildRewardsSection and _buildSellerEntry
growth_section_start = content.find('  Widget _vendorOnboardingCard(')
growth_section_end = content.find('  Widget _buildAiSupportState(')

new_widgets = """  Widget _buildRewardsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildListItem(
            icon: Icons.card_giftcard_rounded,
            title: 'Refer & Earn',
            subtitle: 'Invite friends and unlock style credits',
            onTap: () => _push(context, const ReferralScreen()),
            minimal: true,
          ),
          _minimalDivider(context),
          _buildListItem(
            icon: Icons.local_offer_outlined,
            title: 'Offers & Rewards',
            subtitle: 'Private drops, loyalty perks, and seasonal edits',
            onTap: () => _showComingSoon(
              context,
              title: 'Offers & rewards',
              message: 'Curated rewards and luxury member offers will be available here.',
            ),
            minimal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSellerEntry(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildListItem(
        icon: Icons.storefront_outlined,
        title: 'Sell on Abianzo',
        subtitle: 'Start selling fashion products on the marketplace',
        onTap: () => _push(context, const VendorRegistrationScreen()),
        minimal: true,
      ),
    );
  }

  Widget _buildPremiumEliteCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFC6A769),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC6A769).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ABIANZO ELITE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 12),
                Text('• Priority delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('• Exclusive drops', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('• Bonus rewards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Join Elite →',
              style: TextStyle(
                color: Color(0xFFC6A769),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

"""

if growth_section_start != -1 and growth_section_end != -1:
    content = content[:growth_section_start] + new_widgets + content[growth_section_end:]

# 5. Compress Fit Profile (_styleSection)
fit_profile_target = """  Widget _styleSection(BuildContext context, AppUser user) {
    return StreamBuilder<UserStyleSnapshot>(
      stream: _database.watchUserStyleSnapshot(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _styleHighlightCard(
            context,
            icon: Icons.error_outline_rounded,
            title: 'Style snapshot unavailable',
            subtitle:
                'Measurements and smart-fit details could not be loaded, but the rest of your profile is still available.',
          );
        }

        final styleSnapshot = snapshot.data;
        final measurementProfiles =
            styleSnapshot?.measurementProfiles ?? const <MeasurementProfile>[];
        final bodyProfile = styleSnapshot?.bodyProfile;

        final savedProfileSubtitle = snapshot.connectionState ==
                ConnectionState.waiting
            ? 'Checking your saved fit details'
            : bodyProfile == null && measurementProfiles.isEmpty
            ? 'View and edit your fit details'
            : bodyProfile != null
            ? '${bodyProfile.recommendedSize.isNotEmpty ? bodyProfile.recommendedSize : 'M'} fit • Updated ${_relativeScanTime(bodyProfile.updatedAt)}'
            : '${measurementProfiles.length} saved profile${measurementProfiles.length == 1 ? '' : 's'}';

        return Column(
          children: [
            _styleHighlightCard(
              context,
              icon: Icons.straighten_rounded,
              title: 'Saved Fit Profile',
              subtitle: savedProfileSubtitle,
              onTap: () => _push(context, const TailorProfileScreen()),
              loading: snapshot.connectionState == ConnectionState.waiting,
            ),
          ],
        );
      },
    );
  }"""

fit_profile_replacement = """  Widget _styleSection(BuildContext context, AppUser user) {
    return StreamBuilder<UserStyleSnapshot>(
      stream: _database.watchUserStyleSnapshot(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        final styleSnapshot = snapshot.data;
        final bodyProfile = styleSnapshot?.bodyProfile;
        
        final subtitle = bodyProfile != null
            ? '${bodyProfile.recommendedSize.isNotEmpty ? bodyProfile.recommendedSize : 'M'} Fit • Updated ${_relativeScanTime(bodyProfile.updatedAt)}'
            : 'View and manage your saved measurements';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildListItem(
            icon: Icons.straighten_rounded,
            title: 'Saved Fit Profile',
            subtitle: subtitle,
            onTap: () => _push(context, const TailorProfileScreen()),
            minimal: true,
          ),
        );
      },
    );
  }"""
content = content.replace(fit_profile_target, fit_profile_replacement)

# 6. Simplify Legal Section (_buildLegalPolicyEntry)
legal_target = """  Widget _buildLegalPolicyEntry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          eyebrow: 'Legal',
          title: 'Policies and Compliance',
          subtitle:
              'View terms, privacy, refunds, delivery policy, and request account deletion.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Legal & Policy Center'),
                subtitle: const Text('All customer legal documents'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalPolicyHubScreen(
                      audience: LegalAudience.customer,
                      title: 'Customer Legal Center',
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Terms & Privacy Consent'),
                subtitle: const Text('Review and accept legal consent'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalConsentScreen(
                      audience: LegalAudience.customer,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Request Account Deletion'),
                subtitle: const Text('Permanently remove your account data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAccountDeletionDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }"""

legal_replacement = """  Widget _buildLegalPolicyEntry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          eyebrow: 'Legal',
          title: 'Legal & Policies',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildListItem(
            icon: Icons.gavel_rounded,
            title: 'Legal & Policies',
            subtitle: 'Manage legal documents and privacy settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPolicyHubScreen(
                  audience: LegalAudience.customer,
                  title: 'Customer Legal Center',
                ),
              ),
            ),
            minimal: true,
          ),
        ),
      ],
    );
  }"""
content = content.replace(legal_target, legal_replacement)

# 7. Quick Action Grid Refinement (2 column)
grid_target = """  Widget _quickActionGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.inventory_2_outlined,
                title: 'My Orders',
                onTap: () => _push(context, const ConsumerOrdersScreen()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.favorite_border_rounded,
                title: 'Wishlist',
                onTap: () => _push(context, const ConsumerWishlistScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.local_activity_outlined,
                title: 'Coupons',
                onTap: () => _showComingSoon(
                  context,
                  title: 'Coupons',
                  message: 'Your active coupons will appear here.',
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.help_outline_rounded,
                title: 'Support',
                onTap: () => _push(context, const FaqScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }"""

# No changes needed here actually, it's already 2 column.

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Phase 1 and 2 Refactoring executed.")
