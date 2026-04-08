import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/network_provider.dart';
import '../services/backend_api_client.dart';
import '../theme.dart';

class AbzioOfflineView extends StatelessWidget {
  const AbzioOfflineView({
    super.key,
    this.title = 'No internet connection',
    this.subtitle = 'Check your connection and try again',
    this.onRetry,
    this.showRetry = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFC94D4D),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.abzioSecondaryText,
                      height: 1.45,
                    ),
                textAlign: TextAlign.center,
              ),
              if (showRetry) ...[
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AbzioRetryPanel extends StatelessWidget {
  const AbzioRetryPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.abzioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.abzioSecondaryText,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: loading ? null : onRetry,
            child: Text(loading ? 'Retrying...' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class AbzioNetworkBanner extends StatelessWidget {
  const AbzioNetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, network, child) {
        return ValueListenableBuilder<BackendAvailability>(
          valueListenable: BackendApiClient.backendAvailability,
          builder: (context, backendStatus, _) {
            final showBackendBanner = !backendStatus.isAvailable;
            final showNetworkBanner = network.showStatusBanner;
            if (!showBackendBanner && !showNetworkBanner) {
              return const SizedBox.shrink();
            }
            final offline = network.isOffline;
            final isBackend = showBackendBanner;
            final bannerColor = isBackend
                ? const Color(0xFFB26A00)
                : (offline ? const Color(0xFFC94D4D) : const Color(0xFF218B5B));
            final message = isBackend
                ? (backendStatus.message.isEmpty
                    ? 'Backend unavailable. Pull to retry.'
                    : backendStatus.message)
                : network.statusMessage;

            return SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    color: bannerColor,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBackend
                                ? Icons.cloud_off_rounded
                                : (offline ? Icons.wifi_off_rounded : Icons.wifi_rounded),
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isBackend) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: BackendApiClient.clearBackendAvailability,
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
