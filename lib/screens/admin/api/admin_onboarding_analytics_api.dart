class AdminOnboardingAnalyticsApi {
  static Future<Map<String, dynamic>> fetchAnalytics() async {
    // Simulated mock data, matching the structure for funnel and KPIs.
    // In production, uncomment the BackendApiClient call below.
    // final payload = await const BackendApiClient().get('/admin/onboarding-analytics', authenticated: true);
    // return Map<String, dynamic>.from(payload['data'] ?? {});

    await Future.delayed(const Duration(milliseconds: 800));

    return {
      'vendorKpis': {
        'applicationsToday': 42,
        'conversionRate': 68.5,
        'avgApprovalTimeHours': 24.5,
        'avgActivationTimeDays': 3.2,
      },
      'riderKpis': {
        'applicationsToday': 128,
        'conversionRate': 45.2,
        'avgApprovalTimeHours': 12.0,
        'avgActivationTimeDays': 1.8,
      },
      'vendorFunnel': [
        {'stage': 'Applied', 'count': 500, 'conversion': 100.0, 'dropoff': 0.0},
        {
          'stage': 'OCR Review',
          'count': 450,
          'conversion': 90.0,
          'dropoff': 10.0,
        },
        {
          'stage': 'Business Review',
          'count': 400,
          'conversion': 88.9,
          'dropoff': 11.1,
        },
        {
          'stage': 'Finance Review',
          'count': 360,
          'conversion': 90.0,
          'dropoff': 10.0,
        },
        {'stage': 'Approved', 'count': 350, 'conversion': 97.2, 'dropoff': 2.8},
        {'stage': 'Active', 'count': 342, 'conversion': 97.7, 'dropoff': 2.3},
      ],
      'riderFunnel': [
        {
          'stage': 'Applied',
          'count': 1200,
          'conversion': 100.0,
          'dropoff': 0.0,
        },
        {
          'stage': 'KYC Review',
          'count': 1000,
          'conversion': 83.3,
          'dropoff': 16.7,
        },
        {
          'stage': 'Verification Review',
          'count': 800,
          'conversion': 80.0,
          'dropoff': 20.0,
        },
        {
          'stage': 'Training',
          'count': 600,
          'conversion': 75.0,
          'dropoff': 25.0,
        },
        {
          'stage': 'Fleet Approval',
          'count': 550,
          'conversion': 91.7,
          'dropoff': 8.3,
        },
        {'stage': 'Active', 'count': 542, 'conversion': 98.5, 'dropoff': 1.5},
      ],
      'executiveInsights': {
        'biggestDropoffPoints': [
          'Rider Training (25.0% drop-off)',
          'Rider Verification (20.0% drop-off)',
        ],
        'fastestStages': [
          'Vendor OCR Review (2 mins)',
          'Rider KYC Review (5 mins)',
        ],
        'slowestStages': [
          'Vendor Business Review (12 hours)',
          'Rider Training (24 hours)',
        ],
        'alerts': [
          'Vendor activation rate dropped by 5% this week.',
          'Spike in Rider KYC rejections detected.',
        ],
      },
    };
  }
}
