using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

namespace Abzora.TryOn
{
    public class MaterialApplier : MonoBehaviour
    {
        [SerializeField] private Material fallbackMaterial;
        [SerializeField] private float wrinkleMotionMultiplier = 0.9f;
        [SerializeField] private float skinToneInfluence = 0.12f;

        public IEnumerator Apply(GameObject garmentRoot, GarmentConfig config)
        {
            if (garmentRoot == null || config == null)
            {
                yield break;
            }

            Texture2D albedo = null;
            Texture2D normal = null;

            if (!string.IsNullOrWhiteSpace(config.FabricTextureUrl))
            {
                using (var request = UnityWebRequestTexture.GetTexture(config.FabricTextureUrl))
                {
                    yield return request.SendWebRequest();
                    if (request.result == UnityWebRequest.Result.Success)
                    {
                        albedo = DownloadHandlerTexture.GetContent(request);
                    }
                }
            }

            if (!string.IsNullOrWhiteSpace(config.NormalMapUrl))
            {
                using (var request = UnityWebRequestTexture.GetTexture(config.NormalMapUrl))
                {
                    yield return request.SendWebRequest();
                    if (request.result == UnityWebRequest.Result.Success)
                    {
                        normal = DownloadHandlerTexture.GetContent(request);
                    }
                }
            }

            ApplyRuntimeUpdate(garmentRoot, albedo, normal, config.ColorHex);
            ApplyFabricPresetProperties(garmentRoot, config);
        }

        public void ApplyRuntimeUpdate(GameObject garmentRoot, Texture2D albedo, Texture2D normalMap, string colorHex)
        {
            if (garmentRoot == null)
            {
                return;
            }

            var color = ParseColor(colorHex, new Color(0.78f, 0.65f, 0.41f, 1f));
            var renderers = garmentRoot.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                var material = EnsureCompatibleMaterial(renderer, color);
                if (material == null)
                {
                    continue;
                }

                if (material.HasProperty("_BaseColor"))
                {
                    material.SetColor("_BaseColor", color);
                }
                else if (material.HasProperty("_Color"))
                {
                    material.SetColor("_Color", color);
                }
                if (albedo != null)
                {
                    if (material.HasProperty("_BaseMap"))
                    {
                        material.SetTexture("_BaseMap", albedo);
                    }
                    else if (material.HasProperty("_MainTex"))
                    {
                        material.SetTexture("_MainTex", albedo);
                    }
                }
                if (normalMap != null && material.HasProperty("_BumpMap"))
                {
                    material.SetTexture("_BumpMap", normalMap);
                    material.EnableKeyword("_NORMALMAP");
                }
            }
        }

        public void ApplyPoseAdaptiveUpdate(GameObject garmentRoot, GarmentConfig config, UnityPoseFrame poseFrame)
        {
            if (garmentRoot == null || poseFrame == null)
            {
                return;
            }

            var renderers = garmentRoot.GetComponentsInChildren<Renderer>(true);
            if (renderers == null || renderers.Length == 0)
            {
                return;
            }

            var movement = Mathf.Clamp01((Mathf.Abs(poseFrame.RotationRadians) * 0.9f) + (poseFrame.ShoulderWidth * 0.35f));
            var wrinkleStrength = Mathf.Lerp(0.18f, 1.2f, movement) * wrinkleMotionMultiplier;
            var skinTint = new Color(
                Mathf.Clamp01(poseFrame.SkinToneR),
                Mathf.Clamp01(poseFrame.SkinToneG),
                Mathf.Clamp01(poseFrame.SkinToneB),
                1f
            );

            foreach (var renderer in renderers)
            {
                var material = renderer?.material;
                if (material == null)
                {
                    continue;
                }

                if (material.HasProperty("_BumpScale"))
                {
                    material.SetFloat("_BumpScale", wrinkleStrength);
                }
                if (material.HasProperty("_DetailNormalMapScale"))
                {
                    material.SetFloat("_DetailNormalMapScale", wrinkleStrength * 0.75f);
                }

                if (material.HasProperty("_BaseColor"))
                {
                    var baseColor = material.GetColor("_BaseColor");
                    material.SetColor("_BaseColor", Color.Lerp(baseColor, skinTint, skinToneInfluence));
                }
                else if (material.HasProperty("_Color"))
                {
                    var baseColor = material.color;
                    material.color = Color.Lerp(baseColor, skinTint, skinToneInfluence * 0.7f);
                }
            }

            ApplyFabricPresetProperties(garmentRoot, config);
        }

        public void ApplyLightingScalar(GameObject garmentRoot, float scalar)
        {
            if (garmentRoot == null)
            {
                return;
            }
            var brightness = Mathf.Clamp01(scalar);
            var renderers = garmentRoot.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                var material = renderer?.material;
                if (material == null)
                {
                    continue;
                }

                if (material.HasProperty("_EmissionColor"))
                {
                    var emission = Color.Lerp(Color.black, new Color(0.08f, 0.08f, 0.08f, 1f), brightness);
                    material.SetColor("_EmissionColor", emission);
                }
            }
        }

        private static void ApplyFabricPresetProperties(GameObject garmentRoot, GarmentConfig config)
        {
            if (garmentRoot == null || config == null)
            {
                return;
            }
            var preset = (config.FabricPreset ?? "cotton").Trim().ToLowerInvariant();
            var smoothness = 0.48f;
            var metallic = 0.02f;
            if (preset == "silk")
            {
                smoothness = 0.82f;
                metallic = 0.08f;
            }
            else if (preset == "denim")
            {
                smoothness = 0.24f;
                metallic = 0.01f;
            }

            var renderers = garmentRoot.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                var material = renderer?.material;
                if (material == null)
                {
                    continue;
                }
                if (material.HasProperty("_Smoothness"))
                {
                    material.SetFloat("_Smoothness", smoothness);
                }
                if (material.HasProperty("_Metallic"))
                {
                    material.SetFloat("_Metallic", metallic);
                }
            }
        }

        private static Color ParseColor(string colorHex, Color fallback)
        {
            if (string.IsNullOrWhiteSpace(colorHex))
            {
                return fallback;
            }
            if (ColorUtility.TryParseHtmlString(colorHex.Trim(), out var parsed))
            {
                return parsed;
            }
            return fallback;
        }

        private Material EnsureCompatibleMaterial(Renderer renderer, Color fallbackColor)
        {
            if (renderer == null)
            {
                return null;
            }

            var current = renderer.material;
            if (!IsMagentaRisk(current))
            {
                return current;
            }

            var safe = BuildSafeMaterial(fallbackColor);
            renderer.material = safe;
            return renderer.material;
        }

        private Material BuildSafeMaterial(Color color)
        {
            if (fallbackMaterial != null && !IsMagentaRisk(fallbackMaterial))
            {
                var clone = new Material(fallbackMaterial);
                ApplyColor(clone, color);
                return clone;
            }

            var shader =
                Shader.Find("Universal Render Pipeline/Lit") ??
                Shader.Find("Standard") ??
                Shader.Find("Unlit/Color");

            var material = new Material(shader);
            ApplyColor(material, color);
            return material;
        }

        private static void ApplyColor(Material material, Color color)
        {
            if (material == null)
            {
                return;
            }

            if (material.HasProperty("_BaseColor"))
            {
                material.SetColor("_BaseColor", color);
            }
            else if (material.HasProperty("_Color"))
            {
                material.SetColor("_Color", color);
            }
        }

        private static bool IsMagentaRisk(Material material)
        {
            if (material == null)
            {
                return true;
            }
            var shader = material.shader;
            if (shader == null)
            {
                return true;
            }
            if (!shader.isSupported)
            {
                return true;
            }
            return shader.name == "Hidden/InternalErrorShader";
        }
    }
}
