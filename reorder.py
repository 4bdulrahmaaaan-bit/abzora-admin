import re

file_path = r'c:\Users\AAA\Documents\abzio\lib\screens\user\profile_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Extract StreamBuilder for AI Support
ai_support_start = content.find('StreamBuilder<List<SupportChat>>(')
if ai_support_start != -1:
    # Find the end of this StreamBuilder
    # It ends with: "                        }," then "                      )," inside _reveal
    ai_support_end_str = "                        },\n                      ),"
    ai_support_end = content.find(ai_support_end_str, ai_support_start) + len(ai_support_end_str)
    ai_builder_code = content[ai_support_start:ai_support_end-len("                      ),")].strip()
else:
    print("Could not find AI Support stream builder")
    exit(1)

# 2. Extract Logout Button
logout_start = content.find('OutlinedButton.icon(')
if logout_start != -1:
    logout_end_str = "                      ),"
    logout_end = content.find(logout_end_str, logout_start) + len(logout_end_str)
    logout_code = content[logout_start:logout_end-len("                      ),")].strip()
else:
    print("Could not find Logout button")
    exit(1)

# Construct the new delegate list
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

# Now replace the entire delegate content
start_marker = "delegate: SliverChildListDelegate(["
end_marker = "                  ]),\n                ),\n              ),"

delegate_start = content.find(start_marker)
delegate_end = content.find(end_marker, delegate_start)

if delegate_start != -1 and delegate_end != -1:
    new_content = content[:delegate_start + len(start_marker)] + "\n" + new_delegate + "\n" + content[delegate_end:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Reordering successful.")
else:
    print("Could not find SliverChildListDelegate bounds")
