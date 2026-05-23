using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Abzora.TryOn
{
    [Serializable]
    public sealed class TryOnPayload
    {
        public string ProductId = string.Empty;
        public string Name = string.Empty;
        public string Category = "shirt";
        public string Model3dUrl = string.Empty;
        public string UnityAssetBundleUrl = string.Empty;
        public string RigProfile = string.Empty;
        public string MaterialProfile = string.Empty;
        public string OverlayAssetUrl = string.Empty;
        public string TemplateId = string.Empty;
        public TemplateConfig Template = new TemplateConfig();
        public GarmentConfig GarmentConfig = new GarmentConfig();
        public AlignmentConfig Alignment = new AlignmentConfig();
        public MeasurementMap Measurements = new MeasurementMap();
    }

    [Serializable]
    public sealed class TemplateConfig
    {
        public string Id = string.Empty;
        public string Slug = string.Empty;
        public string Name = string.Empty;
        public string Category = string.Empty;
        public string BundleUrl = string.Empty;
        public string RigProfile = string.Empty;
        public Dictionary<string, List<string>> CustomizableParts = new Dictionary<string, List<string>>();
        public Dictionary<string, float> BlendShapes = new Dictionary<string, float>();
        public List<string> SupportedFits = new List<string>();
        public LodModelUrls Lods = new LodModelUrls();
    }

    [Serializable]
    public sealed class GarmentConfig
    {
        public string TemplateId = string.Empty;
        public string FabricTextureUrl = string.Empty;
        public string NormalMapUrl = string.Empty;
        public string Fit = "regular";
        public string FabricPreset = "cotton";
        public string ColorHex = "#C6A769";
        public Dictionary<string, string> DesignOptions = new Dictionary<string, string>();
        public Dictionary<string, float> BlendShapeOverrides = new Dictionary<string, float>();
        public string LodPreference = "auto";
        public LodModelUrls LodModels = new LodModelUrls();
    }

    [Serializable]
    public struct LodSource
    {
        public int Level;
        public string Url;
    }

    [Serializable]
    public sealed class LodModelUrls
    {
        public string Lod0 = string.Empty;
        public string Lod1 = string.Empty;
        public string Lod2 = string.Empty;

        public IEnumerable<LodSource> EnumerateByPreference(string preference)
        {
            var normalized = (preference ?? "auto").Trim().ToLowerInvariant();
            if (normalized == "high")
            {
                yield return new LodSource { Level = 0, Url = Lod0 };
                yield return new LodSource { Level = 1, Url = Lod1 };
                yield return new LodSource { Level = 2, Url = Lod2 };
                yield break;
            }
            if (normalized == "medium")
            {
                yield return new LodSource { Level = 1, Url = Lod1 };
                yield return new LodSource { Level = 0, Url = Lod0 };
                yield return new LodSource { Level = 2, Url = Lod2 };
                yield break;
            }
            if (normalized == "low")
            {
                yield return new LodSource { Level = 2, Url = Lod2 };
                yield return new LodSource { Level = 1, Url = Lod1 };
                yield return new LodSource { Level = 0, Url = Lod0 };
                yield break;
            }

            yield return new LodSource { Level = 0, Url = Lod0 };
            yield return new LodSource { Level = 1, Url = Lod1 };
            yield return new LodSource { Level = 2, Url = Lod2 };
        }
    }

    [Serializable]
    public sealed class AlignmentConfig
    {
        public string AnchorTemplate = "torso_template";
        public float ScaleFactor = 1f;
        public float WidthFactor = 1f;
        public float HeightFactor = 1f;
    }

    [Serializable]
    public sealed class MeasurementMap
    {
        public float HeightCm = 170f;
        public float ShoulderCm = 42f;
        public float ChestCm = 96f;
        public float WaistCm = 84f;
        public float HipCm = 98f;
        public float InseamCm = 78f;

        public float Get(string key)
        {
            switch (key)
            {
                case "heightcm":
                    return HeightCm;
                case "shouldercm":
                    return ShoulderCm;
                case "chestcm":
                    return ChestCm;
                case "waistcm":
                    return WaistCm;
                case "hipcm":
                    return HipCm;
                case "inseamcm":
                    return InseamCm;
                default:
                    return 0f;
            }
        }
    }

    public static class TryOnPayloadParser
    {
        public static TryOnPayload Parse(string json)
        {
            var root = MiniJson.Deserialize(json) as IDictionary<string, object>;
            if (root == null)
            {
                return null;
            }

            var payload = new TryOnPayload
            {
                ProductId = ReadString(root, "productId", "id"),
                Name = ReadString(root, "name"),
                Category = ReadString(root, "category", fallback: "shirt").ToLowerInvariant(),
                Model3dUrl = ReadString(root, "model3dUrl", "model3d"),
                UnityAssetBundleUrl = ReadString(root, "unityAssetBundleUrl"),
                RigProfile = ReadString(root, "rigProfile"),
                MaterialProfile = ReadString(root, "materialProfile"),
                OverlayAssetUrl = ReadString(root, "overlayAssetUrl"),
                TemplateId = ReadString(root, "templateId"),
                Measurements = ParseMeasurements(ReadMap(root, "measurements")),
            };

            payload.Template = ParseTemplate(ReadMap(root, "template"));
            payload.GarmentConfig = ParseGarmentConfig(ReadMap(root, "garmentConfig"));
            payload.Alignment = ParseAlignment(ReadMap(root, "alignmentConfig"));

            if (string.IsNullOrWhiteSpace(payload.GarmentConfig.TemplateId))
            {
                payload.GarmentConfig.TemplateId = payload.TemplateId;
            }
            if (string.IsNullOrWhiteSpace(payload.TemplateId))
            {
                payload.TemplateId = payload.GarmentConfig.TemplateId;
            }
            if (string.IsNullOrWhiteSpace(payload.Model3dUrl))
            {
                payload.Model3dUrl = payload.GarmentConfig.LodModels.Lod0;
            }
            if (string.IsNullOrWhiteSpace(payload.GarmentConfig.LodModels.Lod0))
            {
                payload.GarmentConfig.LodModels.Lod0 = payload.Template?.Lods?.Lod0 ?? string.Empty;
            }
            if (string.IsNullOrWhiteSpace(payload.GarmentConfig.LodModels.Lod1))
            {
                payload.GarmentConfig.LodModels.Lod1 = payload.Template?.Lods?.Lod1 ?? string.Empty;
            }
            if (string.IsNullOrWhiteSpace(payload.GarmentConfig.LodModels.Lod2))
            {
                payload.GarmentConfig.LodModels.Lod2 = payload.Template?.Lods?.Lod2 ?? string.Empty;
            }

            return payload;
        }

        public static UnityPosePayload ParsePose(string json)
        {
            var root = MiniJson.Deserialize(json) as IDictionary<string, object>;
            var pose = ReadMap(root, "poseFrame");
            if (pose == null)
            {
                return null;
            }

            return new UnityPosePayload
            {
                PoseFrame = new UnityPoseFrame
                {
                    LeftShoulder = ParsePosePoint(ReadMap(pose, "leftShoulder")),
                    RightShoulder = ParsePosePoint(ReadMap(pose, "rightShoulder")),
                    LeftElbow = ParsePosePoint(ReadMap(pose, "leftElbow")),
                    RightElbow = ParsePosePoint(ReadMap(pose, "rightElbow")),
                    LeftWrist = ParsePosePoint(ReadMap(pose, "leftWrist")),
                    RightWrist = ParsePosePoint(ReadMap(pose, "rightWrist")),
                    LeftHip = ParsePosePoint(ReadMap(pose, "leftHip")),
                    RightHip = ParsePosePoint(ReadMap(pose, "rightHip")),
                    ShoulderCenter = ParsePosePoint(ReadMap(pose, "shoulderCenter")),
                    HipCenter = ParsePosePoint(ReadMap(pose, "hipCenter")),
                    SpineCenter = ParsePosePoint(ReadMap(pose, "spineCenter")),
                    LeftFoot = ParsePosePoint(ReadMap(pose, "leftFoot")),
                    RightFoot = ParsePosePoint(ReadMap(pose, "rightFoot")),
                    RotationRadians = ReadFloat(pose, "rotationRadians"),
                    ShoulderWidth = ReadFloat(pose, "shoulderWidth"),
                    HipWidth = ReadFloat(pose, "hipWidth", fallback: ReadFloat(pose, "shoulderWidth") * 0.86f),
                    TorsoHeight = ReadFloat(pose, "torsoHeight"),
                    LightingScore = ReadFloat(pose, "lightingScore", fallback: 0.5f),
                    ColorTemperature = ReadFloat(pose, "colorTemperature", fallback: 6500f),
                    SkinToneR = ReadFloat(pose, "skinToneR", fallback: 0.72f),
                    SkinToneG = ReadFloat(pose, "skinToneG", fallback: 0.57f),
                    SkinToneB = ReadFloat(pose, "skinToneB", fallback: 0.48f),
                }
            };
        }

        private static TemplateConfig ParseTemplate(IDictionary<string, object> map)
        {
            var result = new TemplateConfig();
            if (map == null)
            {
                return result;
            }

            result.Id = ReadString(map, "id");
            result.Slug = ReadString(map, "slug");
            result.Name = ReadString(map, "name");
            result.Category = ReadString(map, "category");
            result.BundleUrl = ReadString(map, "bundleUrl");
            result.RigProfile = ReadString(map, "rigProfile");
            result.SupportedFits = ReadStringList(map, "supportedFits");
            result.BlendShapes = ReadNumberMap(map, "blendShapes");
            result.CustomizableParts = ReadStringListMap(map, "customizableParts");
            var modelUrls = ReadMap(map, "modelUrls");
            if (modelUrls != null)
            {
                result.Lods = new LodModelUrls
                {
                    Lod0 = ReadString(modelUrls, "lod0"),
                    Lod1 = ReadString(modelUrls, "lod1"),
                    Lod2 = ReadString(modelUrls, "lod2"),
                };
            }
            return result;
        }

        private static GarmentConfig ParseGarmentConfig(IDictionary<string, object> map)
        {
            var result = new GarmentConfig();
            if (map == null)
            {
                return result;
            }

            result.TemplateId = ReadString(map, "templateId");
            result.FabricTextureUrl = ReadString(map, "fabricTextureUrl");
            result.NormalMapUrl = ReadString(map, "normalMapUrl", "normalMap");
            result.Fit = ReadString(map, "fit", "fitPreset", fallback: "regular").ToLowerInvariant();
            result.FabricPreset = ReadString(map, "fabric", "fabricPreset", fallback: "cotton").ToLowerInvariant();
            result.ColorHex = ReadString(map, "color", "colorHex", fallback: "#C6A769");
            result.DesignOptions = ReadStringMap(map, "designOptions");
            result.BlendShapeOverrides = ReadNumberMap(map, "blendShapeOverrides");
            result.LodPreference = ReadString(map, "lodPreference", fallback: "auto").ToLowerInvariant();
            var lodMap = ReadMap(map, "lodModels");
            if (lodMap != null)
            {
                result.LodModels = new LodModelUrls
                {
                    Lod0 = ReadString(lodMap, "lod0"),
                    Lod1 = ReadString(lodMap, "lod1"),
                    Lod2 = ReadString(lodMap, "lod2"),
                };
            }

            return result;
        }

        private static AlignmentConfig ParseAlignment(IDictionary<string, object> map)
        {
            var result = new AlignmentConfig();
            if (map == null)
            {
                return result;
            }

            result.AnchorTemplate = ReadString(map, "anchorTemplate", fallback: "torso_template");
            result.ScaleFactor = ReadFloat(map, "scaleFactor", fallback: 1f);
            result.WidthFactor = ReadFloat(map, "widthFactor", fallback: 1f);
            result.HeightFactor = ReadFloat(map, "heightFactor", fallback: 1f);
            return result;
        }

        private static MeasurementMap ParseMeasurements(IDictionary<string, object> map)
        {
            var result = new MeasurementMap();
            if (map == null)
            {
                return result;
            }

            result.HeightCm = ReadFloat(map, "heightCm", fallback: result.HeightCm);
            result.ShoulderCm = ReadFloat(map, "shoulderCm", fallback: result.ShoulderCm);
            result.ChestCm = ReadFloat(map, "chestCm", fallback: result.ChestCm);
            result.WaistCm = ReadFloat(map, "waistCm", fallback: result.WaistCm);
            result.HipCm = ReadFloat(map, "hipCm", fallback: result.HipCm);
            result.InseamCm = ReadFloat(map, "inseamCm", fallback: result.InseamCm);
            return result;
        }

        private static UnityPosePoint ParsePosePoint(IDictionary<string, object> map)
        {
            if (map == null)
            {
                return null;
            }
            return new UnityPosePoint
            {
                X = ReadFloat(map, "x"),
                Y = ReadFloat(map, "y"),
            };
        }

        private static IDictionary<string, object> ReadMap(IDictionary<string, object> source, string key)
        {
            if (source == null || !source.TryGetValue(key, out var value))
            {
                return null;
            }
            return value as IDictionary<string, object>;
        }

        private static string ReadString(
            IDictionary<string, object> source,
            string key1,
            string key2 = null,
            string fallback = "")
        {
            if (source != null && source.TryGetValue(key1, out var first) && first != null)
            {
                return first.ToString().Trim();
            }
            if (!string.IsNullOrWhiteSpace(key2) &&
                source != null &&
                source.TryGetValue(key2, out var second) &&
                second != null)
            {
                return second.ToString().Trim();
            }

            return fallback;
        }

        private static float ReadFloat(IDictionary<string, object> source, string key, float fallback = 0f)
        {
            if (source == null || !source.TryGetValue(key, out var value) || value == null)
            {
                return fallback;
            }

            if (value is float)
            {
                return (float)value;
            }
            if (value is double)
            {
                return (float)(double)value;
            }
            if (value is long)
            {
                return (long)value;
            }
            if (value is int)
            {
                return (int)value;
            }
            if (float.TryParse(value.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed))
            {
                return parsed;
            }
            return fallback;
        }

        private static Dictionary<string, string> ReadStringMap(IDictionary<string, object> source, string key)
        {
            var map = ReadMap(source, key);
            if (map == null)
            {
                return new Dictionary<string, string>();
            }

            return map
                .Where(entry => entry.Key != null && entry.Value != null)
                .ToDictionary(
                    entry => entry.Key.Trim(),
                    entry => entry.Value.ToString().Trim(),
                    StringComparer.OrdinalIgnoreCase);
        }

        private static Dictionary<string, float> ReadNumberMap(IDictionary<string, object> source, string key)
        {
            var map = ReadMap(source, key);
            if (map == null)
            {
                return new Dictionary<string, float>();
            }

            var result = new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in map)
            {
                if (string.IsNullOrWhiteSpace(entry.Key) || entry.Value == null)
                {
                    continue;
                }
                if (float.TryParse(entry.Value.ToString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed))
                {
                    result[entry.Key.Trim()] = parsed;
                }
            }

            return result;
        }

        private static Dictionary<string, List<string>> ReadStringListMap(
            IDictionary<string, object> source,
            string key)
        {
            var map = ReadMap(source, key);
            if (map == null)
            {
                return new Dictionary<string, List<string>>();
            }

            var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in map)
            {
                if (string.IsNullOrWhiteSpace(entry.Key))
                {
                    continue;
                }

                if (!(entry.Value is IList list))
                {
                    continue;
                }

                var values = new List<string>();
                foreach (var item in list)
                {
                    var text = item?.ToString().Trim();
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        values.Add(text);
                    }
                }
                result[entry.Key.Trim()] = values;
            }

            return result;
        }

        private static List<string> ReadStringList(IDictionary<string, object> source, string key)
        {
            if (source == null || !source.TryGetValue(key, out var value) || !(value is IList list))
            {
                return new List<string>();
            }

            return list
                .Cast<object>()
                .Select(item => item?.ToString().Trim())
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .ToList();
        }
    }

    [Serializable]
    public sealed class UnityPosePayload
    {
        public UnityPoseFrame PoseFrame;
    }

    [Serializable]
    public sealed class FitData
    {
        public string RecommendedSize = "M";
        public int FitScore = 80;
        public float Confidence = 0.8f;
        public string FitLabel = "Good fit";
        public string BodyType = "regular";
        public string RiskLevel = "low";
        public List<string> FitWarnings = new List<string>();
    }

    [Serializable]
    public sealed class UnityPoseFrame
    {
        public UnityPosePoint LeftShoulder;
        public UnityPosePoint RightShoulder;
        public UnityPosePoint LeftElbow;
        public UnityPosePoint RightElbow;
        public UnityPosePoint LeftWrist;
        public UnityPosePoint RightWrist;
        public UnityPosePoint LeftHip;
        public UnityPosePoint RightHip;
        public UnityPosePoint ShoulderCenter;
        public UnityPosePoint HipCenter;
        public UnityPosePoint SpineCenter;
        public UnityPosePoint LeftFoot;
        public UnityPosePoint RightFoot;
        public float RotationRadians;
        public float ShoulderWidth;
        public float HipWidth;
        public float TorsoHeight;
        public float LightingScore;
        public float ColorTemperature;
        public float SkinToneR;
        public float SkinToneG;
        public float SkinToneB;
    }

    [Serializable]
    public sealed class UnityPosePoint
    {
        public float X;
        public float Y;
    }
}
