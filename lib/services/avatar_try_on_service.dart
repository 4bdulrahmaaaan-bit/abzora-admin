import '../models/models.dart';

class AvatarBodyParams {
  const AvatarBodyParams({
    required this.heightScale,
    required this.chestMorph,
    required this.waistMorph,
    required this.hipMorph,
  });

  final double heightScale;
  final double chestMorph;
  final double waistMorph;
  final double hipMorph;
}

class AvatarTryOnService {
  const AvatarTryOnService();

  AvatarBodyParams mapFromProfile(BodyProfile? profile) {
    final height = (profile?.heightCm ?? 170).clamp(145, 205).toDouble();
    final chest = (profile?.chestCm ?? 96).clamp(76, 140).toDouble();
    final waist = (profile?.waistCm ?? 84).clamp(64, 130).toDouble();
    final hip = (profile?.hipCm ?? 96).clamp(76, 150).toDouble();

    double norm(double value, double min, double max) =>
        ((value - min) / (max - min)).clamp(0, 1).toDouble();

    return AvatarBodyParams(
      heightScale: (height / 170).clamp(0.88, 1.2).toDouble(),
      chestMorph: norm(chest, 76, 140),
      waistMorph: norm(waist, 64, 130),
      hipMorph: norm(hip, 76, 150),
    );
  }
}
