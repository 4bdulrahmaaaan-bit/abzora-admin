using System;
using System.Collections.Generic;
using UnityEngine;

namespace Abzora.TryOn
{
    public class FitApplier : MonoBehaviour
    {
        public void ApplyBlendShapes(GameObject garmentRoot, TemplateConfig template, GarmentConfig config, MeasurementMap measurements)
        {
            if (garmentRoot == null)
            {
                return;
            }

            var blendValues = new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase);
            if (template != null)
            {
                foreach (var kv in template.BlendShapes)
                {
                    blendValues[kv.Key] = kv.Value;
                }
            }
            if (config != null)
            {
                foreach (var kv in config.BlendShapeOverrides)
                {
                    blendValues[kv.Key] = kv.Value;
                }
            }

            if (measurements != null)
            {
                AddBlend(blendValues, "chest_expand", Mathf.Clamp((measurements.ChestCm - 96f) * 0.7f, -25f, 40f));
                AddBlend(blendValues, "waist_expand", Mathf.Clamp((measurements.WaistCm - 84f) * 0.7f, -25f, 40f));
                AddBlend(blendValues, "hip_expand", Mathf.Clamp((measurements.HipCm - 98f) * 0.65f, -25f, 40f));
                AddBlend(blendValues, "length_adjust", Mathf.Clamp((measurements.HeightCm - 170f) * 0.22f, -18f, 24f));
            }

            var skinnedMeshes = garmentRoot.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            foreach (var meshRenderer in skinnedMeshes)
            {
                if (meshRenderer.sharedMesh == null)
                {
                    continue;
                }
                for (var i = 0; i < meshRenderer.sharedMesh.blendShapeCount; i++)
                {
                    var shapeName = meshRenderer.sharedMesh.GetBlendShapeName(i);
                    if (blendValues.TryGetValue(shapeName, out var value))
                    {
                        meshRenderer.SetBlendShapeWeight(i, Mathf.Clamp(value, -100f, 100f));
                    }
                }
            }
        }

        public void ApplyScale(GameObject garmentRoot, GarmentConfig config, MeasurementMap measurements, AlignmentConfig alignment)
        {
            if (garmentRoot == null || measurements == null)
            {
                return;
            }

            var fitMultiplier = FitPresetScaleMultiplier(config?.Fit);
            var factor = alignment?.ScaleFactor ?? 1f;
            var x = Mathf.Clamp((measurements.ChestCm / 96f) * (alignment?.WidthFactor ?? 1f) * fitMultiplier, 0.78f, 1.5f);
            var y = Mathf.Clamp((measurements.HeightCm / 170f) * (alignment?.HeightFactor ?? 1f), 0.78f, 1.35f);
            var z = Mathf.Clamp((measurements.WaistCm / 84f) * fitMultiplier, 0.78f, 1.5f);
            var targetScale = new Vector3(x * factor, y * factor, z * factor);
            var motionController = garmentRoot.GetComponent<GarmentMotionController>();
            if (motionController == null)
            {
                garmentRoot.transform.localScale = targetScale;
                return;
            }
            motionController.SetTargetScale(targetScale);
        }

        public FitData CalculateFitData(TryOnPayload payload)
        {
            var measurements = payload?.Measurements ?? new MeasurementMap();
            var chestDelta = Mathf.Abs(measurements.ChestCm - 96f);
            var waistDelta = Mathf.Abs(measurements.WaistCm - 84f);
            var hipDelta = Mathf.Abs(measurements.HipCm - 98f);
            var penalty = (chestDelta * 0.6f) + (waistDelta * 0.7f) + (hipDelta * 0.5f);
            var fitScore = Mathf.Clamp(Mathf.RoundToInt(96f - penalty), 55, 99);
            var confidence = Mathf.Clamp01((fitScore - 50f) / 50f);
            var bodyType = ClassifyBodyType(measurements);
            var warnings = BuildFitWarnings(measurements, fitScore);
            var riskLevel = fitScore >= 86 ? "low" : fitScore >= 74 ? "medium" : "high";

            return new FitData
            {
                RecommendedSize = RecommendSize(measurements, payload?.Category ?? string.Empty),
                FitScore = fitScore,
                Confidence = confidence,
                FitLabel = FitLabel(fitScore),
                BodyType = bodyType,
                RiskLevel = riskLevel,
                FitWarnings = warnings,
            };
        }

        private static string RecommendSize(MeasurementMap measurements, string category)
        {
            if (string.Equals(category, "pants", StringComparison.OrdinalIgnoreCase))
            {
                var waist = measurements.WaistCm;
                if (waist < 74) return "XS";
                if (waist < 82) return "S";
                if (waist < 90) return "M";
                if (waist < 98) return "L";
                if (waist < 106) return "XL";
                return "XXL";
            }

            var chest = measurements.ChestCm;
            if (chest < 88) return "XS";
            if (chest < 96) return "S";
            if (chest < 104) return "M";
            if (chest < 112) return "L";
            if (chest < 120) return "XL";
            return "XXL";
        }

        private static string FitLabel(int score)
        {
            if (score >= 92) return "Excellent fit";
            if (score >= 84) return "Great fit";
            if (score >= 72) return "Good fit";
            return "Needs adjustment";
        }

        private static string ClassifyBodyType(MeasurementMap measurements)
        {
            var shoulderHipRatio = measurements.ShoulderCm / Mathf.Max(1f, measurements.HipCm);
            var chestWaistRatio = measurements.ChestCm / Mathf.Max(1f, measurements.WaistCm);

            if (measurements.WaistCm >= 102f || chestWaistRatio < 1.05f) return "plus";
            if (shoulderHipRatio > 1.08f && chestWaistRatio > 1.18f) return "athletic";
            if (measurements.ChestCm < 92f && measurements.WaistCm < 80f) return "slim";
            return "regular";
        }

        private static List<string> BuildFitWarnings(MeasurementMap measurements, int fitScore)
        {
            var warnings = new List<string>();
            if (measurements.ChestCm > 110f)
            {
                warnings.Add("Slightly tight on chest");
            }
            if (measurements.WaistCm > 96f)
            {
                warnings.Add("Waist area may feel snug");
            }
            if (measurements.HeightCm > 188f)
            {
                warnings.Add("Length may run short");
            }
            if (fitScore < 74 && warnings.Count == 0)
            {
                warnings.Add("Try one size up for comfort");
            }
            return warnings;
        }

        private static float FitPresetScaleMultiplier(string fitPreset)
        {
            var fit = (fitPreset ?? "regular").Trim().ToLowerInvariant();
            if (fit == "slim") return 0.96f;
            if (fit == "relaxed") return 1.03f;
            if (fit == "oversized") return 1.07f;
            if (fit == "athletic") return 1.01f;
            return 1f;
        }

        private static void AddBlend(IDictionary<string, float> map, string key, float value)
        {
            if (map.TryGetValue(key, out var existing))
            {
                map[key] = existing + value;
            }
            else
            {
                map[key] = value;
            }
        }
    }
}
