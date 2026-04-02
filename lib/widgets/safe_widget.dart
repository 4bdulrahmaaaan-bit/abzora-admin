import 'package:flutter/material.dart';

import '../theme.dart';

typedef AbzioWidgetBuilder = Widget Function(BuildContext context);
typedef AbzioFallbackBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

class AbzioGlobalErrorView extends StatelessWidget {
  const AbzioGlobalErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please try again. The app is still safe to use.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EA),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AbzioTheme.accentColor,
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
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.abzioSecondaryText,
                        height: 1.45,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
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
      ),
    );
  }
}

class AbzioSafeWidget extends StatelessWidget {
  const AbzioSafeWidget({
    super.key,
    required this.builder,
    this.fallbackBuilder,
  });

  final AbzioWidgetBuilder builder;
  final AbzioFallbackBuilder? fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'abzio_safe_widget',
          context: ErrorDescription('while building a protected widget'),
        ),
      );
      return fallbackBuilder?.call(context, error, stackTrace) ??
          const AbzioGlobalErrorView();
    }
  }
}

class AbzioSafeFutureBuilder<T> extends StatelessWidget {
  const AbzioSafeFutureBuilder({
    super.key,
    required this.future,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmpty,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              const AbzioGlobalErrorView(
                message: 'We could not load this section right now.',
              );
        }
        final data = snapshot.data;
        if (data == null || (isEmpty != null && isEmpty!(data))) {
          return emptyBuilder?.call(context) ??
              const SizedBox.shrink();
        }
        return dataBuilder(context, data);
      },
    );
  }
}

class AbzioSafeStreamBuilder<T> extends StatelessWidget {
  const AbzioSafeStreamBuilder({
    super.key,
    required this.stream,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmpty,
  });

  final Stream<T>? stream;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    final streamSource = stream;
    return StreamBuilder<T>(
      stream: streamSource == null
          ? null
          : (streamSource.isBroadcast
              ? streamSource
              : streamSource.asBroadcastStream()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              const AbzioGlobalErrorView(
                message: 'We could not load this live section right now.',
              );
        }
        final data = snapshot.data;
        if (data == null || (isEmpty != null && isEmpty!(data))) {
          return emptyBuilder?.call(context) ??
              const SizedBox.shrink();
        }
        return dataBuilder(context, data);
      },
    );
  }
}

class AbzioSafeNetworkImage extends StatelessWidget {
  const AbzioSafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF7F3EA),
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          color: AbzioTheme.accentColor,
        ),
      ),
    );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }
}
