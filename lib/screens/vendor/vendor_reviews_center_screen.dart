import 'package:flutter/material.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_metric_card.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../services/review_api.dart';
import '../../services/review_analytics_api.dart';

class VendorReviewsCenterScreen extends StatefulWidget {
  const VendorReviewsCenterScreen({super.key});

  @override
  State<VendorReviewsCenterScreen> createState() =>
      _VendorReviewsCenterScreenState();
}

class _VendorReviewsCenterScreenState extends State<VendorReviewsCenterScreen> {
  final ReviewApi _reviewApi = ReviewApi();
  final ReviewAnalyticsApi _analyticsApi = ReviewAnalyticsApi();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _analytics = {};
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _reviews = [];
      });
    }

    try {
      final analyticsData = await _analyticsApi.getAnalytics();
      final reviewData = await _reviewApi.getReviews(page: _page, limit: 10);
      final List<dynamic> fetchedReviews = reviewData['data']['reviews'] ?? [];

      setState(() {
        _analytics = analyticsData['data'] ?? {};
        if (loadMore) {
          _reviews.addAll(fetchedReviews.cast<Map<String, dynamic>>());
        } else {
          _reviews = fetchedReviews.cast<Map<String, dynamic>>();
        }
        _hasMore = _page < (reviewData['data']['totalPages'] ?? 1);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadNextPage() {
    if (_hasMore && !_isLoading) {
      setState(() {
        _page++;
      });
      _fetchData(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Reviews Center',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _page == 1) {
      return const Center(
        child: CircularProgressIndicator(color: VendorTheme.primary),
      );
    }
    if (_error != null && _reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load data: $_error', textAlign: TextAlign.center),
            const SizedBox(height: VendorTheme.spacing16),
            ElevatedButton(
              onPressed: () => _fetchData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchData(),
      color: VendorTheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(VendorTheme.spacing16),
        itemCount: _reviews.length + 2, // Analytics + Reviews + Loader
        itemBuilder: (context, index) {
          if (index == 0) return _buildAnalyticsGrid();
          if (index == _reviews.length + 1) {
            if (_hasMore) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: OutlinedButton(
                    onPressed: _loadNextPage,
                    child: const Text('Load More'),
                  ),
                ),
              );
            }
            return const SizedBox(height: 32);
          }

          final review = _reviews[index - 1];
          return _buildReviewCard(review);
        },
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    final rating = _analytics['averageRating']?.toDouble() ?? 0.0;
    final count = _analytics['reviewCount'] ?? 0;
    final positive = _analytics['positivePercent']?.toDouble() ?? 0.0;
    final tbyb = _analytics['tbyb'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Avg Rating',
                value: rating.toStringAsFixed(1),
                icon: Icons.star_rounded,
                trend: 0,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'Total Reviews',
                value: count.toString(),
                icon: Icons.comment_outlined,
                trend: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing16),
        Row(
          children: [
            Expanded(
              child: VendorMetricCard(
                title: 'Positive (%)',
                value: '${positive.toStringAsFixed(0)}%',
                icon: Icons.thumb_up_alt_outlined,
                trend: 0,
              ),
            ),
            const SizedBox(width: VendorTheme.spacing16),
            Expanded(
              child: VendorMetricCard(
                title: 'TBYB Reviews',
                value: (tbyb['trialReviews'] ?? 0).toString(),
                icon: Icons.checkroom_outlined,
                trend: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing24),
        Text(
          'Recent Reviews',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: VendorTheme.spacing16),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final comment = review['review'] ?? 'No comment provided';
    final isTrial = review['isTrialOrder'] == true;
    final outcome = review['trialOutcome'];
    final reply = review['reply'];

    return PremiumVendorCard(
      margin: const EdgeInsets.only(bottom: VendorTheme.spacing16),
      padding: const EdgeInsets.all(VendorTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
              ),
              if (isTrial)
                VendorStatusBadge(
                  label: 'TBYB: ${outcome ?? 'Unknown'}',
                  type: VendorBadgeType.info,
                ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing8),
          Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          if (reply != null) ...[
            const SizedBox(height: VendorTheme.spacing16),
            Container(
              padding: const EdgeInsets.all(VendorTheme.spacing12),
              decoration: BoxDecoration(
                color: VendorTheme.grey100,
                borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Reply:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: VendorTheme.spacing4),
                  Text(
                    reply['message'] ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          if (reply == null) ...[
            const SizedBox(height: VendorTheme.spacing16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showReplyDialog(review['_id']),
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: const Text('Reply'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReplyDialog(String reviewId) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to Review'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your reply here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _reviewApi.addReply(reviewId, controller.text);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to reply: $e')),
                  );
                }
              }
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (result == true) {
      _fetchData(); // Refresh to show reply
    }
  }
}
