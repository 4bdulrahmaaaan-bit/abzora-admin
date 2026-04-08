class AbzoraText {
  static const brandName = 'ABZORA';
  static const brandTagline = 'Style Near You';
  static const premiumMarketplaceBadge = 'Premium Fashion Marketplace';
  static const customNavLabel = 'Atelier';
  static const heroSearchTitlePrefix = 'Search in';
  static const profileSetupTitle = 'Complete your profile for perfect fit ✨';
  static const profileSetupNameLabel = 'Name';
  static const profileSetupAddressLabel = 'Address';
  static const locationDetectError = 'Unable to detect location';
  static const useGps = 'Use GPS';
  static const save = 'Save';
  static const remove = 'REMOVE';
  static const total = 'TOTAL';

  static const locationLoggedOutTitle = 'Set your delivery location';
  static const locationSubtext = 'Find styles near you';
  static const locationLoggedOutSubtitle = 'Choose your location to discover premium stores nearby';
  static const locationManualSubtitle = 'Using your selected city for nearby style discovery';

  static const homeLoadingTitle = 'Loading premium fashion near you';
  static const homeLoadingSubtitle = 'Curating nearby stores, fresh arrivals, and custom styles.';

  static const storesNearYou = 'Stores near you';
  static const storesLoading = 'Discovering styles near you...';
  static const storesFallbackTitle = 'Showing the closest stores for you';
  static const storesFallbackSubtitle =
      'We could not find stores in your current radius, so we picked the nearest available options.';
  static const storesEmptyTitle = 'No stores near you yet';
  static const storesEmptySubtitle = 'Try updating your location or expanding your search.';
  static const changeLocation = 'Change location';
  static const expandTo25Km = 'Expand to 25 km';

  static const customClothingTitle = 'Tailored Just for You';
  static const customClothingSubtitle =
      'Choose a designer first, then create a made-to-measure look';
  static const customClothingCta = 'Enter Atelier';

  static const trendingNearYouTitle = 'Trending Near You';
  static const trendingNearYouSubtitle = 'Popular picks from nearby stores';
  static const justForYouTitle = 'Just For You';
  static const justForYouSubtitle = 'Based on your style';
  static const recentlyViewedTitle = 'Recently Viewed';
  static const recentlyViewedSubtitle = 'Pick up where you left off';

  static const homeEmptyTitle = 'Discover premium styles near you';
  static const homeEmptySubtitle = 'Update your location to unlock the best edits from nearby stores.';
  static const homeEmptyCta = 'Shop Now';

  static const wishlistTitle = 'Wishlist';
  static const wishlistLoadingTitle = 'Loading your saved styles';
  static const wishlistLoadingSubtitle = 'Bringing back the pieces you loved.';
  static const wishlistEmptyTitle = 'Save styles you love';
  static const wishlistEmptySubtitle = 'Tap the heart on any product to build your personal fashion edit.';

  static const cartTitle = 'YOUR BAG';
  static const cartEmptyTitle = 'Your bag is waiting';
  static const cartEmptySubtitle = 'Add standout pieces from nearby stores and return here for a smooth checkout.';
  static const cartEmptyCta = 'Shop Now';

  static const searchHint = 'Search styles, brands, or stores';
  static const searchRecentTitle = 'Recent searches';
  static const searchRecentEmpty = 'Your recent searches will appear here';
  static const searchTrendingTitle = 'Trending searches';
  static const searchSuggestedCategoriesTitle = 'Suggested categories';
  static const searchEmptyTitle = 'No results found';
  static const searchEmptySubtitle = 'Try another keyword or browse the suggested categories.';

  static const bagReminderSuccess = 'We will remind you to return to your bag later.';

  static const oneStoreBagNotice =
      'Your bag supports one store at a time so pricing, delivery, and support stay precise.';

  static const completeTheLookTitle = 'COMPLETE THE LOOK';
  static const addToBag = 'ADD';
  static const remindMeLater = 'REMIND ME LATER';
  static const proceedToCheckout = 'PROCEED TO CHECKOUT';
  static const startShopping = 'START SHOPPING';
}

class HomeCategoryCopy {
  final String title;
  final String subtitle;

  const HomeCategoryCopy({
    required this.title,
    required this.subtitle,
  });
}

class HeroBannerCopy {
  final String title;
  final String cta;

  const HeroBannerCopy({
    required this.title,
    required this.cta,
  });
}

class PromoBannerCopy {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String cta;

  const PromoBannerCopy({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.cta,
  });
}

class AbzoraCopySets {
  static const heroBanners = <HeroBannerCopy>[
    HeroBannerCopy(title: 'Style that defines you', cta: 'Explore Collection'),
    HeroBannerCopy(title: 'Curated fashion from stores near you', cta: 'Shop Now'),
    HeroBannerCopy(title: 'Discover premium looks around you', cta: 'Explore Collection'),
  ];

  static const categories = <HomeCategoryCopy>[
    HomeCategoryCopy(title: 'MEN', subtitle: 'Everyday & formal'),
    HomeCategoryCopy(title: 'WOMEN', subtitle: 'Trendy & elegant'),
    HomeCategoryCopy(title: 'WEDDING', subtitle: 'Celebrate in style'),
    HomeCategoryCopy(title: 'ACCESSORIES', subtitle: 'Complete your look'),
  ];

  static const promoBanners = <PromoBannerCopy>[
    PromoBannerCopy(
      eyebrow: 'Brand Spotlight',
      title: 'New arrivals from Mizaj',
      subtitle: 'Modern occasion wear, refined for every celebration.',
      cta: 'Explore Now',
    ),
    PromoBannerCopy(
      eyebrow: 'Limited Offer',
      title: 'Intro offer on atelier tailoring',
      subtitle: 'Choose your designer, personalize the details, and enjoy a sharper reason to order today.',
      cta: 'Enter Atelier',
    ),
    PromoBannerCopy(
      eyebrow: 'Local Discovery',
      title: 'Top-rated stores near your city',
      subtitle: 'Handpicked edits from the best-reviewed fashion stores nearby.',
      cta: 'View Stores',
    ),
  ];
}
