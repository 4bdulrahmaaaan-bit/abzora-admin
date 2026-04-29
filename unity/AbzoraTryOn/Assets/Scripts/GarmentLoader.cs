using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Networking;

namespace Abzora.TryOn
{
    public class GarmentLoader : MonoBehaviour
    {
        [SerializeField] private Transform garmentRoot;
        [SerializeField] private Material defaultMaterial;
        [SerializeField] private ArVisualTuning tuning;
        [SerializeField] private Camera referenceCamera;
        [SerializeField] private float nearLodDistance = 1.4f;
        [SerializeField] private float midLodDistance = 2.3f;
        [SerializeField] private float lowFpsThreshold = 28f;
        [SerializeField] private float fpsCheckWindowSeconds = 0.75f;

        private readonly Dictionary<string, AssetBundle> _bundleCache = new Dictionary<string, AssetBundle>();
        private readonly Dictionary<int, GameObject> _lodInstances = new Dictionary<int, GameObject>();

        private GameObject _activeGarmentRoot;
        private int _activeLodLevel = -1;
        private TryOnPayload _payload;
        private MeasurementMap _measurements = new MeasurementMap();
        private readonly Dictionary<string, float> _activeBlendShapes =
            new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase);
        private float _fpsWindowElapsed;
        private int _fpsWindowFrames;

        public bool IsReady => _activeGarmentRoot != null;
        public GameObject ActiveGarmentRoot => _activeGarmentRoot;

        private void Update()
        {
            _fpsWindowElapsed += Time.unscaledDeltaTime;
            _fpsWindowFrames += 1;
            UpdateLodSelection();
        }

        public IEnumerator LoadGarment(TryOnPayload payload, MeasurementMap measurements)
        {
            _payload = payload;
            _measurements = measurements ?? new MeasurementMap();
            ClearGarment();

            if (payload == null)
            {
                yield break;
            }

            var loadedAny = false;
            Debug.Log(
                $"[ABZORA AR] Garment load start. product={payload.ProductId}, template={payload.TemplateId}, " +
                $"lod0={payload.GarmentConfig.LodModels.Lod0}, bundle={payload.UnityAssetBundleUrl}, model={payload.Model3dUrl}");
            foreach (var source in payload.GarmentConfig.LodModels.EnumerateByPreference(payload.GarmentConfig.LodPreference))
            {
                if (string.IsNullOrWhiteSpace(source.Url))
                {
                    continue;
                }

                GameObject instance = null;
                yield return StartCoroutine(LoadLodModel(source.Level, source.Url, loaded => instance = loaded));
                if (instance != null)
                {
                    _lodInstances[source.Level] = instance;
                    loadedAny = true;
                }
            }

            if (!loadedAny)
            {
                if (!string.IsNullOrWhiteSpace(payload.UnityAssetBundleUrl))
                {
                    GameObject fromBundle = null;
                    yield return StartCoroutine(
                        LoadLodModel(0, payload.UnityAssetBundleUrl, loaded => fromBundle = loaded));
                    if (fromBundle != null)
                    {
                        _lodInstances[0] = fromBundle;
                        loadedAny = true;
                    }
                }
                else if (!string.IsNullOrWhiteSpace(payload.Model3dUrl))
                {
                    GameObject fromModel = null;
                    yield return StartCoroutine(
                        LoadLodModel(0, payload.Model3dUrl, loaded => fromModel = loaded));
                    if (fromModel != null)
                    {
                        _lodInstances[0] = fromModel;
                        loadedAny = true;
                    }
                }
            }

            if (!loadedAny)
            {
                Debug.LogWarning("[ABZORA AR] No garment URL loaded. Falling back to placeholder mesh.");
                LoadPlaceholderMesh(payload);
            }
            else
            {
                ActivateBestAvailableLod(preferredLevel: 0);
            }

            yield return StartCoroutine(ApplyFabricMaterial(payload));
            ApplyCustomization(payload);
            ApplyBlendShapes(payload, _measurements);
            ApplyMeasurementScale(payload, _measurements);
        }

        public void UpdateMeasurements(TryOnPayload payload, MeasurementMap measurements)
        {
            _payload = payload ?? _payload;
                _measurements = measurements ?? _measurements ?? new MeasurementMap();
            ApplyBlendShapes(_payload, _measurements);
            ApplyMeasurementScale(_payload, _measurements);
        }

        public Dictionary<string, object> BuildFitResult()
        {
            var score = EstimateFitScore();
            var size = RecommendSize(_measurements, _payload?.Category);
            return new Dictionary<string, object>
            {
                { "type", "fit_result" },
                { "productId", _payload?.ProductId ?? string.Empty },
                { "templateId", _payload?.TemplateId ?? string.Empty },
                { "fitScore", score },
                { "recommendedSize", size },
                { "activeLod", _activeLodLevel },
            };
        }

        public void ClearGarment()
        {
            foreach (var lodInstance in _lodInstances.Values)
            {
                if (lodInstance != null)
                {
                    Destroy(lodInstance);
                }
            }
            _lodInstances.Clear();

            if (_activeGarmentRoot != null)
            {
                Destroy(_activeGarmentRoot);
                _activeGarmentRoot = null;
            }
            _activeBlendShapes.Clear();
            _activeLodLevel = -1;
        }

        private IEnumerator LoadLodModel(int lodLevel, string sourceUrl, Action<GameObject> onLoaded)
        {
            if (string.IsNullOrWhiteSpace(sourceUrl))
            {
                onLoaded?.Invoke(null);
                yield break;
            }

            var bundle = default(AssetBundle);
            if (_bundleCache.TryGetValue(sourceUrl, out var cached))
            {
                bundle = cached;
            }
            else
            {
                using (var request = UnityWebRequestAssetBundle.GetAssetBundle(sourceUrl))
                {
                    yield return request.SendWebRequest();
                    if (request.result != UnityWebRequest.Result.Success)
                    {
                        onLoaded?.Invoke(null);
                        yield break;
                    }

                    bundle = DownloadHandlerAssetBundle.GetContent(request);
                    if (bundle == null)
                    {
                        onLoaded?.Invoke(null);
                        yield break;
                    }
                }
                _bundleCache[sourceUrl] = bundle;
            }

            var assetNames = bundle.GetAllAssetNames();
            if (assetNames.Length == 0)
            {
                onLoaded?.Invoke(null);
                yield break;
            }

            var prefab = bundle.LoadAsset<GameObject>(assetNames[0]);
            if (prefab == null)
            {
                onLoaded?.Invoke(null);
                yield break;
            }

            var instance = Instantiate(prefab, garmentRoot);
            instance.name = $"garment_lod_{lodLevel}";
            instance.SetActive(false);
            DisableBlockingBundleSurfaces(instance);
            EnsureSupportedRuntimeMaterials(instance);
            DisableHeavyRendererFlags(instance);
            onLoaded?.Invoke(instance);
        }

        private void LoadPlaceholderMesh(TryOnPayload payload)
        {
            // Keep an invisible placeholder root so camera feed is never blocked by
            // a debug primitive when garment assets are missing.
            var garment = new GameObject($"{payload?.Category ?? "garment"}_placeholder_root");
            garment.transform.SetParent(garmentRoot, false);
            garment.transform.localPosition = Vector3.zero;
            garment.transform.localRotation = Quaternion.identity;
            garment.transform.localScale = Vector3.one;
            garment.SetActive(true);

            _activeGarmentRoot = garment;
            _activeLodLevel = 0;
        }

        private IEnumerator ApplyFabricMaterial(TryOnPayload payload)
        {
            if (_activeGarmentRoot == null || payload == null)
            {
                yield break;
            }

            var renderers = _activeGarmentRoot.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0)
            {
                yield break;
            }

            Texture2D downloadedTexture = null;
            if (!string.IsNullOrWhiteSpace(payload.GarmentConfig.FabricTextureUrl))
            {
                using (var request = UnityWebRequestTexture.GetTexture(payload.GarmentConfig.FabricTextureUrl))
                {
                    yield return request.SendWebRequest();
                    if (request.result == UnityWebRequest.Result.Success)
                    {
                        downloadedTexture = DownloadHandlerTexture.GetContent(request);
                    }
                }
            }

            var color = ParseColor(payload.GarmentConfig.ColorHex, new Color(0.78f, 0.65f, 0.41f, 1f));
            foreach (var renderer in renderers)
            {
                if (renderer == null)
                {
                    continue;
                }
                var material = renderer.material;
                if (IsUnsupportedMaterial(material))
                {
                    material = BuildSafeRuntimeMaterial(
                        defaultColor: color,
                        preferredMaterial: defaultMaterial
                    );
                    renderer.material = material;
                }
                if (material == null)
                {
                    continue;
                }

                material.color = color;
                if (downloadedTexture != null)
                {
                    if (material.HasProperty("_BaseMap"))
                    {
                        material.SetTexture("_BaseMap", downloadedTexture);
                    }
                    else if (material.HasProperty("_MainTex"))
                    {
                        material.SetTexture("_MainTex", downloadedTexture);
                    }
                }
            }
        }

        private static bool IsUnsupportedMaterial(Material material)
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

        private static Material BuildSafeRuntimeMaterial(Color defaultColor, Material preferredMaterial)
        {
            if (preferredMaterial != null && !IsUnsupportedMaterial(preferredMaterial))
            {
                var clone = new Material(preferredMaterial);
                if (clone.HasProperty("_BaseColor"))
                {
                    clone.SetColor("_BaseColor", defaultColor);
                }
                else if (clone.HasProperty("_Color"))
                {
                    clone.SetColor("_Color", defaultColor);
                }
                return clone;
            }

            var shader =
                Shader.Find("Universal Render Pipeline/Lit") ??
                Shader.Find("Standard") ??
                Shader.Find("Unlit/Color");
            var fallback = new Material(shader);
            if (fallback.HasProperty("_BaseColor"))
            {
                fallback.SetColor("_BaseColor", defaultColor);
            }
            else if (fallback.HasProperty("_Color"))
            {
                fallback.SetColor("_Color", defaultColor);
            }
            return fallback;
        }

        private void ApplyBlendShapes(TryOnPayload payload, MeasurementMap measurements)
        {
            if (_activeGarmentRoot == null || payload == null)
            {
                return;
            }

            _activeBlendShapes.Clear();
            foreach (var kv in payload.Template.BlendShapes)
            {
                _activeBlendShapes[kv.Key] = kv.Value;
            }

            foreach (var kv in payload.GarmentConfig.BlendShapeOverrides)
            {
                _activeBlendShapes[kv.Key] = kv.Value;
            }

            var chestOffset = Mathf.Clamp((measurements.ChestCm - 96f) * 0.7f, -20f, 35f);
            var waistOffset = Mathf.Clamp((measurements.WaistCm - 84f) * 0.7f, -20f, 35f);
            var hipOffset = Mathf.Clamp((measurements.HipCm - 98f) * 0.65f, -20f, 35f);

            AccumulateBlendShape("chest_expand", chestOffset);
            AccumulateBlendShape("waist_expand", waistOffset);
            AccumulateBlendShape("hip_expand", hipOffset);

            var skinnedMeshes = _activeGarmentRoot.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            foreach (var meshRenderer in skinnedMeshes)
            {
                if (meshRenderer.sharedMesh == null)
                {
                    continue;
                }

                for (var i = 0; i < meshRenderer.sharedMesh.blendShapeCount; i++)
                {
                    var blendName = meshRenderer.sharedMesh.GetBlendShapeName(i);
                    if (!_activeBlendShapes.TryGetValue(blendName, out var value))
                    {
                        continue;
                    }
                    meshRenderer.SetBlendShapeWeight(i, Mathf.Clamp(value, -100f, 100f));
                }
            }
        }

        private void ApplyCustomization(TryOnPayload payload)
        {
            if (_activeGarmentRoot == null || payload == null)
            {
                return;
            }

            foreach (var slot in payload.Template.CustomizableParts)
            {
                var slotName = slot.Key;
                var selected = payload.GarmentConfig.DesignOptions.TryGetValue(slotName, out var value)
                    ? value
                    : string.Empty;

                if (string.IsNullOrWhiteSpace(selected))
                {
                    continue;
                }

                // Generic slot rule:
                // Children under a slot parent are named like "collar_mandarin", "collar_classic".
                var allTransforms = _activeGarmentRoot.GetComponentsInChildren<Transform>(true);
                foreach (var transformRef in allTransforms)
                {
                    if (transformRef == null || transformRef == _activeGarmentRoot.transform)
                    {
                        continue;
                    }

                    var lower = transformRef.name.ToLowerInvariant();
                    var slotToken = slotName.ToLowerInvariant() + "_";
                    if (!lower.StartsWith(slotToken))
                    {
                        continue;
                    }

                    var shouldEnable = lower == $"{slotToken}{selected.ToLowerInvariant()}";
                    transformRef.gameObject.SetActive(shouldEnable);
                }
            }
        }

        private void ApplyMeasurementScale(TryOnPayload payload, MeasurementMap measurements)
        {
            if (_activeGarmentRoot == null || measurements == null)
            {
                return;
            }

            var alignment = payload?.Alignment ?? new AlignmentConfig();
            var x = Mathf.Clamp((measurements.ChestCm / 96f) * alignment.WidthFactor, 0.78f, 1.42f);
            var y = Mathf.Clamp((measurements.HeightCm / 170f) * alignment.HeightFactor, 0.78f, 1.35f);
            var z = Mathf.Clamp((measurements.WaistCm / 84f), 0.78f, 1.42f);
            var factor = Mathf.Clamp(alignment.ScaleFactor, 0.7f, 1.5f);
            _activeGarmentRoot.transform.localScale = new Vector3(x * factor, y * factor, z * factor);
        }

        private void UpdateLodSelection()
        {
            if (_lodInstances.Count <= 1 || _activeGarmentRoot == null)
            {
                return;
            }

            if (referenceCamera == null)
            {
                referenceCamera = Camera.main;
            }
            if (referenceCamera == null)
            {
                return;
            }

            var distance = Vector3.Distance(referenceCamera.transform.position, _activeGarmentRoot.transform.position);
            var effectiveNear = tuning != null ? tuning.NearLodDistance : nearLodDistance;
            var effectiveMid = tuning != null ? tuning.MidLodDistance : midLodDistance;
            var effectiveLowFps = tuning != null ? tuning.LowFpsThreshold : lowFpsThreshold;
            var effectiveWindow = tuning != null ? tuning.FpsCheckWindowSeconds : fpsCheckWindowSeconds;
            var desiredLod = distance <= nearLodDistance
                ? 0
                : distance <= midLodDistance
                    ? 1
                    : 2;

            desiredLod = distance <= effectiveNear
                ? 0
                : distance <= effectiveMid
                    ? 1
                    : 2;

            if (_fpsWindowElapsed >= effectiveWindow)
            {
                var fps = _fpsWindowFrames / Mathf.Max(0.0001f, _fpsWindowElapsed);
                _fpsWindowElapsed = 0f;
                _fpsWindowFrames = 0;
                if (fps < effectiveLowFps)
                {
                    desiredLod = Mathf.Max(desiredLod, 2);
                }
            }

            ActivateBestAvailableLod(desiredLod);
        }

        private void ActivateBestAvailableLod(int preferredLevel)
        {
            var active = preferredLevel;
            if (!_lodInstances.ContainsKey(active))
            {
                var fallback = _lodInstances.Keys.OrderBy(level => Mathf.Abs(level - preferredLevel)).FirstOrDefault();
                active = fallback;
            }

            foreach (var pair in _lodInstances)
            {
                if (pair.Value != null)
                {
                    pair.Value.SetActive(pair.Key == active);
                }
            }

            if (_lodInstances.TryGetValue(active, out var activeObject) && activeObject != null)
            {
                _activeGarmentRoot = activeObject;
                _activeLodLevel = active;
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

        private void DisableHeavyRendererFlags(GameObject root)
        {
            if (root == null)
            {
                return;
            }
            var first = true;
            foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                renderer.shadowCastingMode = first
                    ? UnityEngine.Rendering.ShadowCastingMode.On
                    : UnityEngine.Rendering.ShadowCastingMode.Off;
                renderer.receiveShadows = true;
                renderer.lightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off;
                first = false;
            }
        }

        private void DisableBlockingBundleSurfaces(GameObject root)
        {
            if (root == null)
            {
                return;
            }

            var renderers = root.GetComponentsInChildren<Renderer>(true);
            if (renderers == null || renderers.Length == 0)
            {
                return;
            }

            // Estimate typical garment renderer size so we can aggressively
            // disable abnormal full-screen/background meshes from bad bundles.
            var sizeSamples = new List<float>(renderers.Length);
            foreach (var renderer in renderers)
            {
                if (renderer == null)
                {
                    continue;
                }
                var bounds = renderer.bounds.size;
                var maxDim = Mathf.Max(bounds.x, Mathf.Max(bounds.y, bounds.z));
                if (maxDim > 0f)
                {
                    sizeSamples.Add(maxDim);
                }
            }
            sizeSamples.Sort();
            var medianDim = sizeSamples.Count == 0
                ? 0.9f
                : sizeSamples[sizeSamples.Count / 2];
            medianDim = Mathf.Clamp(medianDim, 0.35f, 1.35f);

            foreach (var renderer in renderers)
            {
                if (renderer == null)
                {
                    continue;
                }

                var nameLower = renderer.gameObject.name.ToLowerInvariant();
                var looksLikeBackground =
                    nameLower.Contains("background") ||
                    nameLower.Contains("backdrop") ||
                    nameLower.Contains("bg") ||
                    nameLower.Contains("quad") ||
                    nameLower.Contains("plane") ||
                    nameLower.Contains("screen") ||
                    nameLower.Contains("billboard") ||
                    nameLower.Contains("canvas");

                var bounds = renderer.bounds;
                var veryWideSurface =
                    bounds.size.x > 1.8f &&
                    bounds.size.y > 1.8f &&
                    bounds.size.z < 0.2f;

                var maxDim = Mathf.Max(bounds.size.x, Mathf.Max(bounds.size.y, bounds.size.z));
                var minDim = Mathf.Min(bounds.size.x, Mathf.Min(bounds.size.y, bounds.size.z));
                var oversized = maxDim > medianDim * 2.6f || maxDim > 2.4f;
                var ultraThinCard = minDim > 0f && (maxDim / minDim) > 14f && maxDim > 1.2f;
                var looksLikeUiShader = RendererUsesUiLikeShader(renderer);

                if (looksLikeBackground || veryWideSurface || oversized || ultraThinCard || looksLikeUiShader)
                {
                    renderer.enabled = false;
                    Debug.LogWarning($"[ABZORA AR] Disabled blocking renderer: {renderer.gameObject.name}");
                }
            }
        }

        private static bool RendererUsesUiLikeShader(Renderer renderer)
        {
            if (renderer == null)
            {
                return false;
            }

            var mats = renderer.sharedMaterials;
            if (mats == null || mats.Length == 0)
            {
                return false;
            }

            foreach (var mat in mats)
            {
                if (mat == null || mat.shader == null)
                {
                    continue;
                }
                var shaderName = mat.shader.name.ToLowerInvariant();
                if (shaderName.Contains("ui/") ||
                    shaderName.Contains("sprite") ||
                    shaderName.Contains("particles/unlit") ||
                    shaderName.Contains("unlit/transparent"))
                {
                    return true;
                }
            }

            return false;
        }

        private void EnsureSupportedRuntimeMaterials(GameObject root)
        {
            if (root == null)
            {
                return;
            }

            foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                if (renderer == null)
                {
                    continue;
                }

                var material = renderer.sharedMaterial;
                if (!IsUnsupportedMaterial(material))
                {
                    continue;
                }

                var safe = BuildSafeRuntimeMaterial(
                    defaultColor: new Color(0.78f, 0.65f, 0.41f, 1f),
                    preferredMaterial: defaultMaterial
                );
                renderer.sharedMaterial = safe;
                Debug.LogWarning($"[ABZORA AR] Replaced unsupported shader on renderer '{renderer.name}'.");
            }
        }

        private void AccumulateBlendShape(string key, float value)
        {
            if (_activeBlendShapes.TryGetValue(key, out var existing))
            {
                _activeBlendShapes[key] = existing + value;
            }
            else
            {
                _activeBlendShapes[key] = value;
            }
        }

        private int EstimateFitScore()
        {
            if (_measurements == null)
            {
                return 80;
            }

            var chestDelta = Mathf.Abs(_measurements.ChestCm - 96f);
            var waistDelta = Mathf.Abs(_measurements.WaistCm - 84f);
            var hipDelta = Mathf.Abs(_measurements.HipCm - 98f);
            var penalty = (chestDelta * 0.6f) + (waistDelta * 0.7f) + (hipDelta * 0.5f);
            return Mathf.Clamp(Mathf.RoundToInt(96f - penalty), 55, 99);
        }

        private static string RecommendSize(MeasurementMap measurements, string category)
        {
            if (measurements == null)
            {
                return "M";
            }

            var chest = measurements.ChestCm;
            if (category != null && category.Equals("pants", StringComparison.OrdinalIgnoreCase))
            {
                var waist = measurements.WaistCm;
                if (waist < 74) return "XS";
                if (waist < 82) return "S";
                if (waist < 90) return "M";
                if (waist < 98) return "L";
                if (waist < 106) return "XL";
                return "XXL";
            }

            if (chest < 88) return "XS";
            if (chest < 96) return "S";
            if (chest < 104) return "M";
            if (chest < 112) return "L";
            if (chest < 120) return "XL";
            return "XXL";
        }
    }
}
