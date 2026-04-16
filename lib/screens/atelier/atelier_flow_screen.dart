import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/atelier_models.dart';
import '../../providers/atelier_flow_provider.dart';
import '../tailoring/custom_brand_flow_screen.dart';

class AtelierFlowScreen extends StatelessWidget {
  const AtelierFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AtelierFlowProvider(),
      child: const _AtelierFlowBody(),
    );
  }
}

class _AtelierFlowBody extends StatefulWidget {
  const _AtelierFlowBody();

  @override
  State<_AtelierFlowBody> createState() => _AtelierFlowBodyState();
}

class _AtelierFlowBodyState extends State<_AtelierFlowBody> {
  static const Color _bg = Color(0xFFF6F0E6);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AtelierFlowProvider>();
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: provider.step == AtelierStep.home
          ? null
          : _StickyPriceBar(provider: provider),
      body: SafeArea(
        child: Column(
          children: [
            _AtelierTopBar(
              title: provider.step == AtelierStep.home
                  ? 'ABZORA Atelier'
                  : 'ABZORA Atelier - ${provider.step.name}',
              canGoBack: provider.step != AtelierStep.home,
              onBack: () => provider.goToStep(AtelierStep.home),
            ),
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AtelierFlowProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return _EmptyState(
        title: 'Studio unavailable',
        subtitle: provider.error!,
        onRetry: () => provider.setError(null),
      );
    }
    if (provider.designers.isEmpty) {
      return _EmptyState(
        title: 'No designers available',
        subtitle: 'We are onboarding new ateliers near you.',
        onRetry: () => provider.setError(null),
      );
    }

    if (provider.step != AtelierStep.home) {
      return _buildStepsBody(provider);
    }

    return _AtelierHome(provider: provider);
  }

  Widget _buildStepsBody(AtelierFlowProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(step: provider.step),
          const SizedBox(height: 12),
          _stepWidgetFor(provider),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _stepWidgetFor(AtelierFlowProvider provider) {
    switch (provider.step) {
      case AtelierStep.style:
        return _StyleStep(provider: provider);
      case AtelierStep.fabric:
        return _FabricStep(provider: provider);
      case AtelierStep.measurements:
        return _MeasurementStep(provider: provider);
      case AtelierStep.design:
        return _DesignStep(provider: provider);
      case AtelierStep.preview:
        return _PreviewStep(provider: provider);
      case AtelierStep.summary:
        return _SummaryStep(provider: provider);
      case AtelierStep.home:
        return const SizedBox.shrink();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final AtelierStep step;

  @override
  Widget build(BuildContext context) {
    final titles = <AtelierStep, String>{
      AtelierStep.style: 'Style',
      AtelierStep.fabric: 'Fabric',
      AtelierStep.measurements: 'Measurements',
      AtelierStep.design: 'Design',
      AtelierStep.preview: 'Preview',
      AtelierStep.summary: 'Summary',
    };
    final orderedSteps = <AtelierStep>[
      AtelierStep.style,
      AtelierStep.fabric,
      AtelierStep.measurements,
      AtelierStep.design,
      AtelierStep.preview,
      AtelierStep.summary,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  titles[step] ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                ),
                const Spacer(),
                Text(
                  '${step.index}/6',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6C6459),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(orderedSteps.length, (index) {
                final item = orderedSteps[index];
                final isActive = item == step;
                final isComplete = item.index < step.index;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == orderedSteps.length - 1 ? 0 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive || isComplete ? const Color(0xFFC8A96A) : const Color(0xFFE9E0D2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          titles[item]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isActive || isComplete ? const Color(0xFF8C6D2E) : const Color(0xFF9A8F7E),
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtelierTopBar extends StatelessWidget {
  const _AtelierTopBar({
    required this.title,
    required this.canGoBack,
    required this.onBack,
  });

  final String title;
  final bool canGoBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: const Color(0xFFF6F0E6),
      child: Row(
        children: [
          if (canGoBack)
            SizedBox(
              width: 40,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: const Color(0xFF111111),
              ),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                ),
                if (!canGoBack)
                  Text(
                    'Luxury tailoring, designer-led',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6C6459),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _AtelierHome extends StatelessWidget {
  const _AtelierHome({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    final selectedDesigner = provider.selectedDesigner;
    final selectedCategory = provider.selectedCategory;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroBanner(
            selectedDesigner: selectedDesigner?.name,
            onTap: () => _openSteps(context, provider),
          ),
          const SizedBox(height: 18),
          _AtelierValueStrip(
            selectedDesigner: selectedDesigner?.name,
            selectedCategory: selectedCategory?.title,
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Choose Your Atelier',
            subtitle: 'Begin with a designer you trust, then shape the garment around your occasion and fit.',
          ),
          const SizedBox(height: 16),
          ...provider.designers.map(
            (designer) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DesignerCard(
                designer: designer,
                selected: provider.selectedDesigner?.id == designer.id,
                onTap: () => provider.selectDesigner(designer),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Curated Categories',
            subtitle: 'Formal, occasion, and couture silhouettes tailored for a more personal wardrobe.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: provider.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = provider.categories[index];
                return _CategoryCard(
                  category: category,
                  selected: provider.selectedCategory?.id == category.id,
                  onTap: () => provider.selectCategory(category),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _AtelierTrustPanel(designer: selectedDesigner),
          const SizedBox(height: 20),
          _PrimaryButton(
            label: selectedDesigner == null ? 'Begin Atelier Journey' : 'Customize With This Atelier',
            onTap: () => _openSteps(context, provider),
          ),
          const SizedBox(height: 12),
          Text(
            selectedDesigner == null
                ? 'Preview styles, fabrics, and pricing before confirming.'
                : 'Your selected atelier will carry your style, fabric, and fit choices into the studio.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6C6459),
                ),
          ),
        ],
      ),
    );
  }
}

void _openSteps(BuildContext context, AtelierFlowProvider provider) {
  provider.goToStep(AtelierStep.home);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CustomBrandFlowScreen(),
    ),
  );
}

class _StyleStep extends StatelessWidget {
  const _StyleStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Select Style',
      subtitle: 'Start with a silhouette designed for you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: provider.categories.map((category) {
              return _CategoryChip(
                category: category,
                selected: provider.selectedCategory?.id == category.id,
                onTap: () => provider.selectCategory(category),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _SelectedSummaryCard(
            title: 'Selected Style',
            description: provider.selectedCategory?.title ?? 'Formal Shirts',
          ),
        ],
      ),
    );
  }
}

class _FabricStep extends StatelessWidget {
  const _FabricStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Fabric',
      subtitle: 'Choose a premium fabric that defines drape, comfort, and the final presence of the piece.',
      child: provider.fabrics.isEmpty
          ? const _StepEmptyMessage(
              title: 'No fabrics loaded',
              subtitle: 'Please go back and try again.',
            )
          : Column(
              children: provider.fabrics.map((fabric) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FabricCard(
                    fabric: fabric,
                    selected: provider.selectedFabric?.id == fabric.id,
                    onTap: () => provider.selectFabric(fabric),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _MeasurementStep extends StatelessWidget {
  const _MeasurementStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    final measurements = provider.measurements;
    return _StepScaffold(
      title: 'Measurements',
      subtitle: 'Capture precise measurements with premium guidance and alteration confidence built in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF191510),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fit intelligence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use AI body scan or refine manually. Your atelier will keep these measurements attached to the final piece.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD1C5B6),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
                _OutlinedButton(
                  label: 'AI Body Scan',
                  icon: Icons.document_scanner_outlined,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _SecondaryButton(
                  label: 'Manual Input',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Measurement profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter key dimensions in centimeters for a cleaner first fit.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6C6459),
                      ),
                ),
                const SizedBox(height: 16),
                _MeasurementFields(
                  measurements: measurements,
                  onChanged: provider.updateMeasurement,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _HelperPanel(),
        ],
      ),
    );
  }
}

class _DesignStep extends StatelessWidget {
  const _DesignStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Design Details',
      subtitle: 'Shape the garment through the details that define the finish.',
      child: provider.designGroups.isEmpty
          ? const _StepEmptyMessage(
              title: 'No design options',
              subtitle: 'Please go back and try again.',
            )
          : Column(
              children: provider.designGroups.map((group) {
                return _DesignGroupSection(
                  group: group,
                  selected: provider.designChoices[group.id],
                  onSelect: (option) =>
                      provider.selectDesignChoice(group.id, option),
                );
              }).toList(),
            ),
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Preview Your Piece',
      subtitle: 'Review your custom build in one polished editorial view.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewCard(provider: provider),
          const SizedBox(height: 16),
          Text(
            'Stylist note: This pairing enhances structure while keeping the look effortless.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C6459),
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    final designer = provider.selectedDesigner;
    final category = provider.selectedCategory;
    final fabric = provider.selectedFabric;
    return _StepScaffold(
      title: 'Confirm Atelier Order',
      subtitle: 'Everything is aligned and ready for your atelier to begin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16120D), Color(0xFF46331A)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Atelier Look',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${category?.title ?? 'Selected style'} in ${fabric?.name ?? 'premium fabric'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDCCFB9),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Style', value: category?.title ?? '-'),
          _SummaryRow(label: 'Fabric', value: fabric?.name ?? '-'),
          _SummaryRow(label: 'Atelier', value: designer?.name ?? '-'),
          _SummaryRow(label: 'Measurements', value: 'Saved measurements'),
          const SizedBox(height: 12),
          _SectionHeader(title: 'Design choices', subtitle: ''),
          const SizedBox(height: 8),
          ...provider.designChoices.entries.map(
            (entry) => _SummaryRow(
              label: entry.key.toUpperCase(),
              value: entry.value.title,
            ),
          ),
          const SizedBox(height: 20),
          _PrimaryButton(label: 'Add to Cart', onTap: () {}),
        ],
      ),
    );
  }
}

class _StickyPriceBar extends StatelessWidget {
  const _StickyPriceBar({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7EF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StickyPriceMeta(
                          totalPrice: provider.totalPrice,
                          supportingLine: _supportingLine(provider.step),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryButton(
                            label: _ctaLabel(provider.step),
                            onTap: provider.nextStep,
                            compact: true,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _StickyPriceMeta(
                            totalPrice: provider.totalPrice,
                            supportingLine: _supportingLine(provider.step),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _PrimaryButton(
                          label: _ctaLabel(provider.step),
                          onTap: provider.nextStep,
                          compact: true,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  String _ctaLabel(AtelierStep step) {
    switch (step) {
      case AtelierStep.style:
        return 'Next: Fabric';
      case AtelierStep.fabric:
        return 'Next: Measure';
      case AtelierStep.measurements:
        return 'Next: Design';
      case AtelierStep.design:
        return 'Next: Preview';
      case AtelierStep.preview:
        return 'Next: Summary';
      case AtelierStep.summary:
        return 'Confirm Look';
      case AtelierStep.home:
        return 'Start';
    }
  }

  String _supportingLine(AtelierStep step) {
    switch (step) {
      case AtelierStep.style:
        return 'Next, refine the fabric story';
      case AtelierStep.fabric:
        return 'Next, set the fit profile';
      case AtelierStep.measurements:
        return 'Next, shape the details';
      case AtelierStep.design:
        return 'Next, review the piece';
      case AtelierStep.preview:
        return 'Next, confirm your atelier order';
      case AtelierStep.summary:
        return 'Ready for atelier checkout';
      case AtelierStep.home:
        return 'Begin your atelier journey';
    }
  }
}

class _StickyPriceMeta extends StatelessWidget {
  const _StickyPriceMeta({
    required this.totalPrice,
    required this.supportingLine,
  });

  final int totalPrice;
  final String supportingLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Atelier Total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6C6459),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          '₹$totalPrice',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          supportingLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A7D6A),
              ),
        ),
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF1E1913),
                fontWeight: FontWeight.w800,
              ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6C6459),
                ),
          ),
        ],
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.onTap,
    this.selectedDesigner,
  });

  final String? selectedDesigner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 244),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF15120D), Color(0xFF4E3B20), Color(0xFF8A6A34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAE7AA).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ABZORA Atelier',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFFEADAB5),
                          letterSpacing: 1.1,
                        ),
                  ),
                ),
                const Spacer(),
                if (selectedDesigner != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      selectedDesigner!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Designed around your body.\nCrafted for the way you arrive.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose your atelier, refine the silhouette, and step into a custom journey that feels personal from the first detail.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _HeroPill(label: 'Designer-first'),
                _HeroPill(label: 'Made to measure'),
                _HeroPill(label: 'Premium fabrics'),
              ],
            ),
            const SizedBox(height: 14),
            _PrimaryButton(label: 'Start Customizing', onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFF4E7C7),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AtelierValueStrip extends StatelessWidget {
  const _AtelierValueStrip({
    this.selectedDesigner,
    this.selectedCategory,
  });

  final String? selectedDesigner;
  final String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value})>[
      (label: 'Atelier', value: selectedDesigner ?? 'Choose one'),
      (label: 'Category', value: selectedCategory ?? 'Ready to explore'),
      (label: 'Experience', value: 'Luxury guided flow'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: compact
              ? Column(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
                      child: _ValueStripItem(label: item.label, value: item.value),
                    );
                  }),
                )
              : Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    return Expanded(
                      child: Row(
                        children: [
                          if (index > 0)
                            Container(
                              width: 1,
                              height: 34,
                              margin: const EdgeInsets.only(right: 12),
                              color: const Color(0xFFE7DDCD),
                            ),
                          Expanded(
                            child: _ValueStripItem(label: item.label, value: item.value),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        );
      },
    );
  }
}

class _ValueStripItem extends StatelessWidget {
  const _ValueStripItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A7D6A),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _AtelierTrustPanel extends StatelessWidget {
  const _AtelierTrustPanel({this.designer});

  final AtelierDesigner? designer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1612),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A more trustworthy tailoring experience',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            designer == null
                ? 'Select an atelier first to personalize fabrics, fit notes, and design details around a single studio.'
                : '${designer!.name} will carry your measurements, design notes, and fit preferences through one continuous atelier journey.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD1C5B6),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(label: 'Verified atelier'),
              _MiniChip(label: 'Fit-focused process'),
              _MiniChip(label: 'Premium finish'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesignerCard extends StatelessWidget {
  const _DesignerCard({
    required this.designer,
    required this.selected,
    required this.onTap,
  });

  final AtelierDesigner designer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final headlineTag = designer.tags.isNotEmpty ? designer.tags.first : 'Premium atelier';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7E8) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0x26C8A96A) : const Color(0x14000000),
              blurRadius: selected ? 20 : 16,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFF0E8DB),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: NetworkImage(designer.bannerUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EFDC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      headlineTag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8C6D2E),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    designer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${designer.city} · ${designer.priceBand}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6C6459),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected
                        ? 'Selected for your atelier journey'
                        : 'Boutique tailoring with a premium, made-to-measure workflow.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6C6459),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: designer.tags
                        .map((tag) => _MiniChip(label: tag))
                        .toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final AtelierCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6EEDC) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFF0E8DB),
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0x1FC8A96A) : const Color(0x14000000),
              blurRadius: selected ? 18 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 92,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: selected
                        ? const [Color(0xFFEFD8A0), Color(0xFFF8ECCA)]
                        : const [Color(0xFFF7F1E6), Color(0xFFF3EBDD)],
                  ),
                ),
                child: category.imageUrl.trim().isNotEmpty
                    ? Image.network(
                        category.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.checkroom_rounded,
                          size: 28,
                          color: selected ? const Color(0xFF7F5E17) : const Color(0xFF8F7A56),
                        ),
                      )
                    : Icon(
                        Icons.checkroom_rounded,
                        size: 28,
                        color: selected ? const Color(0xFF7F5E17) : const Color(0xFF8F7A56),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              category.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF1E1913),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              category.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6C6459),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              selected ? 'Selected' : 'Explore style',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? const Color(0xFF8C6D2E) : const Color(0xFF8A7D6A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final AtelierCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFE5D4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : Colors.transparent,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          category.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _FabricCard extends StatelessWidget {
  const _FabricCard({
    required this.fabric,
    required this.selected,
    required this.onTap,
  });

  final FabricOption fabric;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7E8) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFF0E8DB),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0x22C8A96A) : const Color(0x14000000),
              blurRadius: selected ? 18 : 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EFDC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    selected ? 'Selected fabric' : 'Fabric pick',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8C6D2E),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  '+₹${fabric.priceDelta}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFC8A96A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fabric.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: fabric.tags.map((tag) => _MiniChip(label: tag)).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              fabric.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6C6459),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '+₹${fabric.priceDelta}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFC8A96A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementFields extends StatelessWidget {
  const _MeasurementFields({
    required this.measurements,
    required this.onChanged,
  });

  final MeasurementData measurements;
  final void Function({
    String? chest,
    String? waist,
    String? hips,
    String? shoulder,
    String? height,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MeasurementInput(
          label: 'Chest',
          value: measurements.chest,
          onChanged: (value) => onChanged(chest: value),
        ),
        const SizedBox(height: 12),
        _MeasurementInput(
          label: 'Waist',
          value: measurements.waist,
          onChanged: (value) => onChanged(waist: value),
        ),
        const SizedBox(height: 12),
        _MeasurementInput(
          label: 'Hips',
          value: measurements.hips,
          onChanged: (value) => onChanged(hips: value),
        ),
        const SizedBox(height: 12),
        _MeasurementInput(
          label: 'Shoulder',
          value: measurements.shoulder,
          onChanged: (value) => onChanged(shoulder: value),
        ),
        const SizedBox(height: 12),
        _MeasurementInput(
          label: 'Height',
          value: measurements.height,
          onChanged: (value) => onChanged(height: value),
        ),
      ],
    );
  }
}

class _MeasurementInput extends StatelessWidget {
  const _MeasurementInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF1E1913),
          ),
      cursorColor: const Color(0xFF8C6D2E),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter in cm',
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6C6459),
              fontWeight: FontWeight.w600,
            ),
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9A8F7E),
            ),
        filled: true,
        fillColor: const Color(0xFFFBF7EF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _HelperPanel extends StatelessWidget {
  const _HelperPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          _HelperRow(text: 'Precision fit guaranteed'),
          SizedBox(height: 8),
          _HelperRow(text: 'Free alteration included'),
          SizedBox(height: 8),
          _HelperRow(text: 'Your atelier keeps these measurements linked to the order'),
        ],
      ),
    );
  }
}

class _DesignGroupSection extends StatelessWidget {
  const _DesignGroupSection({
    required this.group,
    required this.selected,
    required this.onSelect,
  });

  final DesignOptionGroup group;
  final DesignOption? selected;
  final ValueChanged<DesignOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: group.title, subtitle: ''),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: group.options.map((option) {
              return _DesignOptionCard(
                option: option,
                selected: selected?.id == option.id,
                onTap: () => onSelect(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DesignOptionCard extends StatelessWidget {
  const _DesignOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DesignOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6EEDC) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0x20C8A96A) : const Color(0x12000000),
              blurRadius: selected ? 16 : 12,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: selected ? const Color(0xFFC8A96A) : const Color(0xFFF0E8DB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFD8A0) : const Color(0xFFF7F1E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(option.iconKey),
                size: 20,
                color: selected ? const Color(0xFF7F5E17) : const Color(0xFF8F7A56),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              option.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1E1913),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              option.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6C6459),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              selected ? 'Selected detail' : 'Tap to apply',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? const Color(0xFF8C6D2E) : const Color(0xFF8A7D6A),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'collar':
        return Icons.checkroom_outlined;
      case 'cuff':
        return Icons.crop_16_9_outlined;
      case 'button':
        return Icons.circle_outlined;
      case 'pocket':
        return Icons.wallet_outlined;
      default:
        return Icons.auto_awesome_outlined;
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.provider});

  final AtelierFlowProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 208,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFF5D4A2A), Color(0xFF8A6A34)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: _MiniChip(label: 'Editorial preview'),
                ),
                const Spacer(),
                const Center(
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 42),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Your atelier is now seeing the piece the way your final look will be built.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            provider.selectedCategory?.title ?? 'Formal Shirts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.selectedFabric?.name ?? 'Egyptian Cotton',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFC8A96A),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Design selections',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...provider.designChoices.values.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      option.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6C6459),
                          ),
                    ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6C6459),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111111),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSummaryCard extends StatelessWidget {
  const _SelectedSummaryCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E8DB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EBCB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFC8A96A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A7D6A),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1E1913),
                        fontWeight: FontWeight.w700,
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E7D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6C6459),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 52,
      width: compact ? null : double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE0C36C), Color(0xFFC89D34)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC89D34).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: const Color(0xFF111111),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Color(0xFFE0D6C4)),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1E1913),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF111111)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF111111),
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _HelperRow extends StatelessWidget {
  const _HelperRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Color(0xFFC8A96A), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6C6459),
                ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6C6459),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _PrimaryButton(label: 'Retry', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _StepEmptyMessage extends StatelessWidget {
  const _StepEmptyMessage({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6C6459),
                ),
          ),
        ],
      ),
    );
  }
}
