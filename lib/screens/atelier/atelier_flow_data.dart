import 'package:flutter/material.dart';

class AtelierStore {
  const AtelierStore({
    required this.name,
    required this.tagline,
    required this.rating,
    required this.distance,
    required this.startPrice,
    required this.image,
  });

  final String name;
  final String tagline;
  final String rating;
  final String distance;
  final int startPrice;
  final String image;
}

class AtelierStyle {
  const AtelierStyle({
    required this.name,
    required this.subtitle,
    required this.basePrice,
    required this.image,
  });

  final String name;
  final String subtitle;
  final int basePrice;
  final String image;
}

class AtelierFabric {
  const AtelierFabric({
    required this.name,
    required this.material,
    required this.occasion,
    required this.delta,
    required this.description,
    required this.swatch,
    required this.image,
  });

  final String name;
  final String material;
  final String occasion;
  final int delta;
  final String description;
  final Color swatch;
  final String image;
}

class AtelierTrackingMilestone {
  const AtelierTrackingMilestone({
    required this.title,
    required this.completed,
  });

  final String title;
  final bool completed;
}

const List<AtelierStore> atelierRecommendedStores = <AtelierStore>[
  AtelierStore(
    name: 'Noir Line Atelier',
    tagline: 'Couture discipline, modern drape',
    rating: '4.9',
    distance: '2.2 km',
    startPrice: 4200,
    image:
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
  ),
  AtelierStore(
    name: 'Saffron Cut Studio',
    tagline: 'Festive tailoring with soft luxury',
    rating: '4.8',
    distance: '3.7 km',
    startPrice: 3800,
    image:
        'https://images.unsplash.com/photo-1551232864-3f0890e580d9?auto=format&fit=crop&w=1200&q=80',
  ),
];

const List<AtelierStore> atelierNearbyStores = <AtelierStore>[
  AtelierStore(
    name: 'Loom Room',
    tagline: 'Heritage fabrics, precision finishing',
    rating: '4.7',
    distance: '1.8 km',
    startPrice: 3600,
    image:
        'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=1200&q=80',
  ),
  AtelierStore(
    name: 'River Atelier',
    tagline: 'Clean lines and breathable tailoring',
    rating: '4.6',
    distance: '4.1 km',
    startPrice: 3400,
    image:
        'https://images.unsplash.com/photo-1485230895905-ec40ba36b9bc?auto=format&fit=crop&w=1200&q=80',
  ),
];

const List<AtelierStore> atelierDesignerStores = <AtelierStore>[
  AtelierStore(
    name: 'Atelier 11',
    tagline: 'Designer-led bespoke silhouettes',
    rating: '5.0',
    distance: 'By appointment',
    startPrice: 8200,
    image:
        'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
  ),
  AtelierStore(
    name: 'Arya Signature House',
    tagline: 'Occasion couture and bridal craft',
    rating: '4.9',
    distance: 'Designer visit',
    startPrice: 9600,
    image:
        'https://images.unsplash.com/photo-1551803091-e20673f15770?auto=format&fit=crop&w=1200&q=80',
  ),
];

const List<AtelierStyle> atelierStyles = <AtelierStyle>[
  AtelierStyle(
    name: 'Shirt',
    subtitle: 'Daily luxury',
    basePrice: 3200,
    image:
        'https://images.unsplash.com/photo-1598032895397-b9472444bf93?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierStyle(
    name: 'Kurta',
    subtitle: 'Festive elegance',
    basePrice: 3900,
    image:
        'https://images.unsplash.com/photo-1617137968427-85924c800a22?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierStyle(
    name: 'Suit',
    subtitle: 'Formal structure',
    basePrice: 7900,
    image:
        'https://images.unsplash.com/photo-1593032465171-8bd7f85f1a0f?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierStyle(
    name: 'Dress',
    subtitle: 'Fluid couture',
    basePrice: 6400,
    image:
        'https://images.unsplash.com/photo-1495385794356-15371f348c31?auto=format&fit=crop&w=900&q=80',
  ),
];

const List<AtelierFabric> atelierFabrics = <AtelierFabric>[
  AtelierFabric(
    name: 'Italian Cotton Satin',
    material: 'Cotton',
    occasion: 'Office',
    delta: 800,
    description: 'Crisp handfeel and soft sheen.',
    swatch: Color(0xFFD8D2C8),
    image:
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierFabric(
    name: 'Belgian Linen',
    material: 'Linen',
    occasion: 'Festive',
    delta: 1200,
    description: 'Breathable weave with graceful drape.',
    swatch: Color(0xFFBBAA8E),
    image:
        'https://images.unsplash.com/photo-1445205170230-053b83016050?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierFabric(
    name: 'Super 130 Wool',
    material: 'Wool',
    occasion: 'Formal',
    delta: 2400,
    description: 'Fine structure with premium fall.',
    swatch: Color(0xFF38404A),
    image:
        'https://images.unsplash.com/photo-1617127365659-c47fa864d8bc?auto=format&fit=crop&w=900&q=80',
  ),
  AtelierFabric(
    name: 'Mulberry Silk Blend',
    material: 'Silk',
    occasion: 'Wedding',
    delta: 3100,
    description: 'Luminous celebration texture.',
    swatch: Color(0xFF7F4B40),
    image:
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
  ),
];
