using System;
using System.Collections;
using UnityEngine;

namespace Abzora.TryOn
{
    public class TryOnBinder : MonoBehaviour
    {
        [SerializeField] private GarmentLoader garmentLoader;
        [SerializeField] private MaterialApplier materialApplier;
        [SerializeField] private FitApplier fitApplier;
        [SerializeField] private ARCameraController arCameraController;
        [SerializeField] private PoseReceiver poseReceiver;
        [SerializeField] private AvatarRigController avatarRigController;
        [SerializeField] private BodyIntelligenceEngine bodyIntelligenceEngine;
        [SerializeField] private GarmentRigAligner garmentRigAligner;
        [SerializeField] private GarmentClippingGuard garmentClippingGuard;
        [SerializeField] private ArVisualTuning tuning;
        [SerializeField] private float entryDropDistance = 0.24f;
        [SerializeField] private float entryDuration = 0.38f;
        private TryOnPayload _boundPayload;
        private bool _hasReceivedPoseFrame;

        public IEnumerator Bind(TryOnPayload payload, Action<string, string> onError)
        {
            if (payload == null)
            {
                onError?.Invoke("invalid_payload", "Payload is empty.");
                yield break;
            }
            _boundPayload = payload;
            _hasReceivedPoseFrame = false;
            if (garmentLoader == null || materialApplier == null || fitApplier == null)
            {
                onError?.Invoke("binder_missing_dependency", "TryOnBinder is missing required components.");
                yield break;
            }
            if (arCameraController == null)
            {
                onError?.Invoke("ar_controller_missing", "AR camera controller is missing.");
                yield break;
            }
            if (garmentRigAligner == null)
            {
                garmentRigAligner = GetComponent<GarmentRigAligner>();
                if (garmentRigAligner == null)
                {
                    garmentRigAligner = gameObject.AddComponent<GarmentRigAligner>();
                }
            }
            if (garmentClippingGuard == null)
            {
                garmentClippingGuard = GetComponent<GarmentClippingGuard>();
                if (garmentClippingGuard == null)
                {
                    garmentClippingGuard = gameObject.AddComponent<GarmentClippingGuard>();
                }
            }

            yield return StartCoroutine(arCameraController.PrepareArSession(onError));
            if (!arCameraController.IsSessionReady)
            {
                yield break;
            }

            yield return StartCoroutine(garmentLoader.LoadGarment(payload, payload.Measurements));
            var garment = garmentLoader.ActiveGarmentRoot;
            if (garment == null)
            {
                onError?.Invoke("garment_not_loaded", "Garment load failed.");
                yield break;
            }

            if (avatarRigController != null)
            {
                avatarRigController.ApplyMeasurements(payload.Measurements);
            }

            EnsureMotionController(garment, tuning, payload?.GarmentConfig?.FabricPreset);
            ConfigureAmbientLighting(tuning);
            yield return StartCoroutine(materialApplier.Apply(garment, payload.GarmentConfig));
            garmentRigAligner?.Bind(garment);
            garmentClippingGuard?.Setup(garment);
            fitApplier.ApplyBlendShapes(garment, payload.Template, payload.GarmentConfig, payload.Measurements);
            fitApplier.ApplyScale(garment, payload.GarmentConfig, payload.Measurements, payload.Alignment);

            ApplyDesignParts(garment, payload);
            arCameraController?.AttachGarment(garment, payload.Category);
            poseReceiver?.SetLayerMode(payload.Category);
            SetGarmentVisible(garment, false);
            Debug.Log("[ABZORA AR] Garment hidden until first pose frame is received.");
            yield return StartCoroutine(AnimateGarmentEntry(garment));
        }

        public void ApplyMeasurements(TryOnPayload payload)
        {
            if (payload == null)
            {
                return;
            }

            var garment = garmentLoader?.ActiveGarmentRoot;
            if (garment == null)
            {
                return;
            }

            avatarRigController?.ApplyMeasurements(payload.Measurements);
            fitApplier?.ApplyBlendShapes(garment, payload.Template, payload.GarmentConfig, payload.Measurements);
            fitApplier?.ApplyScale(garment, payload.GarmentConfig, payload.Measurements, payload.Alignment);
        }

        public void ApplyPoseFrame(UnityPoseFrame poseFrame)
        {
            if (poseFrame == null)
            {
                return;
            }

            if (_boundPayload != null && _boundPayload.Measurements != null)
            {
                bodyIntelligenceEngine?.UpdateMeasurements(_boundPayload.Measurements, poseFrame);
                var garment = garmentLoader?.ActiveGarmentRoot;
                if (garment != null)
                {
                    fitApplier?.ApplyBlendShapes(
                        garment,
                        _boundPayload.Template,
                        _boundPayload.GarmentConfig,
                        _boundPayload.Measurements
                    );
                    fitApplier?.ApplyScale(
                        garment,
                        _boundPayload.GarmentConfig,
                        _boundPayload.Measurements,
                        _boundPayload.Alignment
                    );
                }
            }
            poseReceiver?.ApplyPose(poseFrame);
            garmentRigAligner?.ApplyPose(poseFrame);
            materialApplier?.ApplyPoseAdaptiveUpdate(
                garmentLoader?.ActiveGarmentRoot,
                _boundPayload?.GarmentConfig,
                poseFrame
            );

            if (!_hasReceivedPoseFrame)
            {
                _hasReceivedPoseFrame = true;
                SetGarmentVisible(garmentLoader?.ActiveGarmentRoot, true);
                Debug.Log("[ABZORA AR] First pose frame received. Garment is now visible.");
            }
        }

        public IEnumerator ApplyRuntimeConfig(TryOnPayload payload)
        {
            if (payload == null)
            {
                yield break;
            }
            var garment = garmentLoader?.ActiveGarmentRoot;
            if (garment == null)
            {
                yield break;
            }

            yield return StartCoroutine(materialApplier.Apply(garment, payload.GarmentConfig));
            fitApplier?.ApplyBlendShapes(garment, payload.Template, payload.GarmentConfig, payload.Measurements);
            fitApplier?.ApplyScale(garment, payload.GarmentConfig, payload.Measurements, payload.Alignment);
            ApplyDesignParts(garment, payload);
        }

        public void UpdateLighting(float cameraBrightness)
        {
            var target = Mathf.Clamp01(cameraBrightness);
            var baseIntensity = tuning != null ? tuning.AmbientIntensity : 1.08f;
            RenderSettings.ambientIntensity = Mathf.Lerp(baseIntensity * 0.82f, baseIntensity * 1.2f, target);
            materialApplier?.ApplyLightingScalar(
                garmentLoader?.ActiveGarmentRoot,
                target
            );
        }

        public void SetViewTransform(float rotateY, float zoom)
        {
            arCameraController?.SetViewTransform(rotateY, zoom);
        }

        public FitData ComputeFitData(TryOnPayload payload)
        {
            return fitApplier != null
                ? fitApplier.CalculateFitData(payload)
                : new FitData();
        }

        public void DisposeSession()
        {
            _boundPayload = null;
            _hasReceivedPoseFrame = false;
            garmentLoader?.ClearGarment();
            poseReceiver?.ResetPose();
        }

        private static void SetGarmentVisible(GameObject garment, bool isVisible)
        {
            if (garment == null)
            {
                return;
            }

            var renderers = garment.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                if (renderer == null)
                {
                    continue;
                }
                renderer.enabled = isVisible;
            }
        }

        private IEnumerator AnimateGarmentEntry(GameObject garment)
        {
            if (garment == null)
            {
                yield break;
            }

            var root = garment.transform;
            var effectiveEntryDrop = tuning != null ? tuning.EntryDropDistance : entryDropDistance;
            var effectiveEntryDuration = tuning != null ? tuning.EntryDuration : entryDuration;
            var endPos = root.localPosition;
            var startPos = endPos + new Vector3(0f, effectiveEntryDrop, 0f);
            root.localPosition = startPos;

            var renderers = garment.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in renderers)
            {
                if (renderer?.material != null && renderer.material.HasProperty("_Color"))
                {
                    var c = renderer.material.color;
                    renderer.material.color = new Color(c.r, c.g, c.b, 0f);
                }
            }

            var elapsed = 0f;
            while (elapsed < effectiveEntryDuration)
            {
                elapsed += Time.deltaTime;
                var t = Mathf.Clamp01(elapsed / Mathf.Max(0.01f, effectiveEntryDuration));
                var eased = 1f - Mathf.Pow(1f - t, 3f);
                root.localPosition = Vector3.Lerp(startPos, endPos, eased);

                foreach (var renderer in renderers)
                {
                    if (renderer?.material != null && renderer.material.HasProperty("_Color"))
                    {
                        var c = renderer.material.color;
                        renderer.material.color = new Color(c.r, c.g, c.b, t);
                    }
                }
                yield return null;
            }

            root.localPosition = endPos;
        }

        private static void ConfigureAmbientLighting(ArVisualTuning tuning)
        {
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = tuning != null
                ? tuning.AmbientLight
                : new Color(0.62f, 0.64f, 0.68f, 1f);
            RenderSettings.ambientIntensity = tuning != null
                ? tuning.AmbientIntensity
                : 1.08f;
        }

        private static void EnsureMotionController(GameObject garment, ArVisualTuning tuning, string fabricPreset)
        {
            if (garment == null)
            {
                return;
            }
            var controller = garment.GetComponent<GarmentMotionController>();
            if (controller == null)
            {
                controller = garment.AddComponent<GarmentMotionController>();
            }
            if (controller != null && tuning != null)
            {
                controller.AssignTuning(tuning);
            }
            controller?.ConfigureFabric(fabricPreset);
        }

        private static void ApplyDesignParts(GameObject garmentRoot, TryOnPayload payload)
        {
            if (garmentRoot == null || payload?.Template?.CustomizableParts == null)
            {
                return;
            }

            foreach (var slot in payload.Template.CustomizableParts)
            {
                if (!payload.GarmentConfig.DesignOptions.TryGetValue(slot.Key, out var selected))
                {
                    continue;
                }
                if (string.IsNullOrWhiteSpace(selected))
                {
                    continue;
                }

                var token = slot.Key.ToLowerInvariant() + "_";
                var target = token + selected.ToLowerInvariant();
                var transforms = garmentRoot.GetComponentsInChildren<Transform>(true);
                foreach (var node in transforms)
                {
                    if (node == null || node == garmentRoot.transform)
                    {
                        continue;
                    }
                    var normalized = node.name.ToLowerInvariant();
                    if (!normalized.StartsWith(token))
                    {
                        continue;
                    }
                    node.gameObject.SetActive(normalized == target);
                }
            }
        }
    }
}
