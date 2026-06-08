import re

file_path = r'c:\Users\AAA\Documents\abzio\lib\screens\user\profile_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

def extract_method(content, start_str):
    start = content.find(start_str)
    if start == -1: return content, None
    brace_count = 0
    in_method = False
    for i in range(start, len(content)):
        if content[i] == '{':
            brace_count += 1
            in_method = True
        elif content[i] == '}':
            brace_count -= 1
        
        if in_method and brace_count == 0:
            return content[:start] + content[i+1:], content[start:i+1]
    return content, None

# 1. Rename EliteCard and remove elite badge
content = content.replace('Widget _buildEliteCard(', 'Widget _buildProfileHeaderCard(')
content = content.replace('_buildEliteCard(', '_buildProfileHeaderCard(')
content = content.replace('child: _eliteBadge(),', '')
content, _ = extract_method(content, '  Widget _eliteBadge() {')

# 2. Profile Completion Logic in Header
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

# 3. Replace _styleSection (removes duplicate Address/Payments)
content, _ = extract_method(content, '  Widget _styleSection(BuildContext context, AppUser? user) {')
new_style_section = """  Widget _styleSection(BuildContext context, AppUser? user) {
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<_StyleProfileSnapshot>(
      stream: _database.watchUserStyleSnapshot(user.id).map(
        (s) => _StyleProfileSnapshot(s.bodyProfile, s.measurementProfiles, null)
      ),
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
  }
"""
insert_pos = content.find('  Widget _buildAiSupportState(')
content = content[:insert_pos] + new_style_section + content[insert_pos:]

# 4. Create new widgets
new_widgets = """  Widget _buildShoppingEssentials(BuildContext context, String city) {
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
            icon: Icons.location_on_outlined,
            title: 'Addresses',
            subtitle: city == 'Location pending'
                ? 'Add your preferred delivery spot'
                : 'Deliver to $city',
            onTap: () => _editAddress(context),
            minimal: true,
          ),
          _minimalDivider(context),
          _buildListItem(
            icon: Icons.credit_card_outlined,
            title: 'Payment Methods',
            subtitle: 'Secure cards and UPI options',
            onTap: () => _showPaymentMethodsSheet(context),
            minimal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(BuildContext context) {
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
content = content[:insert_pos] + new_widgets + content[insert_pos:]

# 5. Clean up _buildSettingsList (Remove Addresses and Payments)
content, _ = extract_method(content, '  Widget _buildSettingsList(')
new_settings = """  Widget _buildSettingsList(
    BuildContext context,
    String city, {
    required bool showCompleteProfileCard,
    required bool showCompletionLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (showCompletionLoading) ...[
            const ShimmerListItem(),
            _minimalDivider(context),
          ] else if (showCompleteProfileCard) ...[
            _buildListItem(
              icon: Icons.verified_rounded,
              title: 'Complete Your Profile',
              subtitle: 'Address, fit profile, and payment in one guided flow',
              onTap: _openProfileCompletion,
              minimal: true,
            ),
            _minimalDivider(context),
          ],
          _buildListItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Order, offer, and delivery alerts',
            onTap: () => _push(context, const NotificationsScreen()),
            minimal: true,
          ),
        ],
      ),
    );
  }
"""
content = content[:insert_pos] + new_settings + content[insert_pos:]

# 6. Replace _buildLegalPolicyEntry
content, _ = extract_method(content, '  Widget _buildLegalPolicyEntry(BuildContext context) {')
new_legal = """  Widget _buildLegalPolicyEntry(BuildContext context) {
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
  }
"""
content = content[:insert_pos] + new_legal + content[insert_pos:]

# 7. Remove vendor cards and growth section
content, _ = extract_method(content, '  Widget _vendorOnboardingCard(')
content, _ = extract_method(content, '  Widget _buildGrowthSection(')


# 8. Rebuild the `build` method delegate
ai_support_start = content.find('StreamBuilder<List<SupportChat>>(')
ai_support_end_str = "                        },\n                      ),"
ai_support_end = content.find(ai_support_end_str, ai_support_start) + len(ai_support_end_str)
ai_builder_code = content[ai_support_start:ai_support_end-len("                      ),")].strip()

logout_start = content.find('OutlinedButton.icon(')
logout_end_str = "                      ),"
logout_end = content.find(logout_end_str, logout_start) + len(logout_end_str)
logout_code = content[logout_start:logout_end-len("                      ),")].strip()

new_delegate = f"""_reveal(
                      0.00,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good evening, $firstName',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your next outfit is waiting',
                            style: TextStyle(
                              color: context.abzioSecondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(
                      0.02,
                      _buildProfileHeaderCard(
                        context,
                        auth: auth,
                        user: user,
                        name: name,
                        phone: phone,
                        city: city,
                        address: address,
                        profileImageProvider: _cachedProfileImageProvider,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(0.03, _buildPremiumEliteCard(context)),
                    const SizedBox(height: 18),
                    _reveal(0.04, _buildValueStrip(context, user)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.06,
                      _sectionTitle(
                        eyebrow: 'AI Support',
                        title: 'Instant help for styling and orders',
                        subtitle:
                            'A premium assistant for fit questions, order support, and next-look guidance.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(
                      0.08,
                      {ai_builder_code}
                    ),
                    const SizedBox(height: 24),
                    _reveal(0.14, _quickActionGrid(context)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.22,
                      _sectionTitle(
                        eyebrow: 'Profile • Fit Profile',
                        title: 'Your Fit Profile',
                        subtitle:
                            'Personalized sizing recommendations for better shopping.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(0.28, _styleSection(context, user)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.32,
                      _sectionTitle(
                        eyebrow: 'Account • Essentials',
                        title: 'Shopping Essentials',
                        subtitle: 'Manage delivery locations and payment preferences.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(0.34, _buildShoppingEssentials(context, city)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.38,
                      _sectionTitle(
                        eyebrow: 'Rewards',
                        title: 'Referrals & Offers',
                        subtitle: 'Invite friends, earn style credits, and unlock drops.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(0.40, _buildRewardsSection(context)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.44,
                      _sectionTitle(
                        eyebrow: 'Sell',
                        title: 'Join the Marketplace',
                        subtitle: 'Onboard as a premium fashion vendor.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(0.46, _buildSellerEntry(context)),
                    const SizedBox(height: 24),
                    _reveal(
                      0.50,
                      _sectionTitle(
                        eyebrow: 'Account',
                        title: 'Manage your preferences',
                        subtitle:
                            'Delivery, payments, and notifications tuned for a seamless shopping flow.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _reveal(
                      0.56,
                      FutureBuilder<_ProfileSetupSnapshot>(
                        future: _profileSetupFor(user.id),
                        builder: (context, snapshot) {{
                          final loading =
                              snapshot.connectionState == ConnectionState.waiting;
                          final setup = snapshot.data;
                          return _buildSettingsList(
                            context,
                            city,
                            showCompleteProfileCard: !loading &&
                                !(setup?.isComplete ?? false),
                            showCompletionLoading: loading,
                          );
                        }},
                      ),
                    ),
                    const SizedBox(height: 24),
                    _reveal(0.60, _buildLegalPolicyEntry(context)),
                    const SizedBox(height: 28),
                    _reveal(
                      0.68,
                      {logout_code}
                    ),
                    const SizedBox(height: 12),"""

start_marker = "delegate: SliverChildListDelegate(["
end_marker = "                  ]),\n                ),\n              ),"

delegate_start = content.find(start_marker)
delegate_end = content.find(end_marker, delegate_start)

content = content[:delegate_start + len(start_marker)] + "\n" + new_delegate + "\n" + content[delegate_end:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Rebuild perfect script executed.")
