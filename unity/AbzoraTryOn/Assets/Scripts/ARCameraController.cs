using System;
using System.Collections;
using System.Reflection;
using Unity.XR.CoreUtils;
using UnityEngine;
using UnityEngine.InputSystem.XR;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;
using UnityEngine.Rendering.Universal;

namespace Abzora.TryOn
{
    public class ARCameraController : MonoBehaviour
    {
        [SerializeField] private Transform garmentAnchor;
        [SerializeField] private Transform topAnchor;
        [SerializeField] private Transform bottomAnchor;
        [SerializeField] private Transform leftFootAnchor;
        [SerializeField] private Transform rightFootAnchor;
        [SerializeField] private Camera arCamera;
        [SerializeField] private float minZoom = 0.8f;
        [SerializeField] private float maxZoom = 1.35f;
        [SerializeField] private bool attachToRootTransform = true;
        [SerializeField] private ARHumanBodyManager humanBodyManager;
        [SerializeField] private ARSession arSession;
        [SerializeField] private XROrigin xrOrigin;
        [SerializeField] private ARCameraManager arCameraManager;
        [SerializeField] private ARCameraBackground arCameraBackground;
        [SerializeField] private float maxTrackingWaitSeconds = 6f;
        [SerializeField] private float previewDistanceMeters = 1.15f;
        [SerializeField] private float previewVerticalOffsetMeters = 0.18f;
        [SerializeField] private bool resetSessionOnResume = true;

        public bool IsSessionReady { get; private set; }

        public IEnumerator PrepareArSession(Action<string, string> onError)
        {
            IsSessionReady = false;
            EnsureArRig();
            DisableNonArCameras();
            DisableBlockingDebugMeshes();

            if (arCamera == null || arCameraManager == null || arCameraBackground == null)
            {
                onError?.Invoke(
                    "ar_camera_setup_missing",
                    "AR camera background setup is incomplete."
                );
                yield break;
            }

            Debug.Log("[ABZORA AR] Checking AR platform availability.");
            yield return ARSession.CheckAvailability();

            if (ARSession.state == ARSessionState.NeedsInstall)
            {
                Debug.Log("[ABZORA AR] AR runtime needs install. Requesting installation.");
                yield return ARSession.Install();
            }

            if (ARSession.state == ARSessionState.Unsupported)
            {
                Debug.LogError("[ABZORA AR] Device does not support ARFoundation background rendering.");
                onError?.Invoke(
                    "ar_unsupported",
                    "This device does not support live AR camera rendering."
                );
                yield break;
            }

            if (arSession != null)
            {
                arSession.enabled = true;
                arSession.Reset();
            }
            yield return StartCoroutine(RestartCameraManagerRoutine());
            if (arCameraBackground != null)
            {
                arCameraBackground.enabled = true;
            }

            // Wait for actual tracking before reporting ready. This keeps the camera state stable
            // and avoids flashing into fallback too early on slower devices.
            var trackingDeadline = Time.realtimeSinceStartup + Mathf.Max(5f, maxTrackingWaitSeconds);
            while (Time.realtimeSinceStartup < trackingDeadline)
            {
                if (ARSession.state == ARSessionState.SessionTracking)
                {
                    IsSessionReady = true;
                    Debug.Log("[ABZORA AR] AR session is tracking and camera feed is ready.");
                    yield break;
                }

                if (ARSession.state == ARSessionState.Unsupported)
                {
                    Debug.LogError("[ABZORA AR] AR session became unsupported during startup.");
                    onError?.Invoke(
                        "ar_unsupported",
                        "This device does not support live AR camera rendering."
                    );
                    yield break;
                }

                yield return null;
            }

            Debug.LogWarning("[ABZORA AR] AR tracking did not stabilize within startup window.");
            onError?.Invoke(
                "ar_tracking_timeout",
                "AR tracking is taking longer than expected."
            );
            yield break;
        }

        private void OnApplicationPause(bool pauseStatus)
        {
            if (pauseStatus || !resetSessionOnResume)
            {
                return;
            }
            StartCoroutine(ResumeResetRoutine());
        }

        private void OnApplicationFocus(bool hasFocus)
        {
            if (!hasFocus || !resetSessionOnResume)
            {
                return;
            }
            StartCoroutine(ResumeResetRoutine());
        }

        public void AttachGarment(GameObject garmentRoot, string category = "top")
        {
            if (garmentRoot == null)
            {
                return;
            }

            var normalizedCategory = (category ?? "top").Trim().ToLowerInvariant();
            var preferredAnchor = ResolveCategoryAnchor(normalizedCategory);
            var attachedToBody = false;

            if (humanBodyManager != null && humanBodyManager.trackables.count > 0)
            {
                foreach (var humanBody in humanBodyManager.trackables)
                {
                    if (humanBody == null)
                    {
                        continue;
                    }

                    if (attachToRootTransform)
                    {
                        garmentRoot.transform.SetParent(humanBody.transform, worldPositionStays: false);
                    }
                    else if (preferredAnchor != null)
                    {
                        garmentRoot.transform.SetParent(preferredAnchor, worldPositionStays: false);
                    }
                    attachedToBody = true;
                    break;
                }
            }

            if (attachedToBody)
            {
                return;
            }

            if (preferredAnchor != null)
            {
                garmentRoot.transform.SetParent(preferredAnchor, worldPositionStays: false);
                garmentRoot.transform.localPosition = Vector3.zero;
                garmentRoot.transform.localRotation = Quaternion.identity;
                return;
            }

            // Only use camera preview placement when no anchor exists at all.
            // On Android, AR human body tracking is often unavailable, and forcing
            // the garment in front of the camera creates the large yellow overlay.
            PlaceGarmentInFrontOfCamera(garmentRoot);
        }

        public void SetViewTransform(float rotateY, float zoom)
        {
            if (garmentAnchor != null)
            {
                garmentAnchor.localRotation = Quaternion.Euler(0f, rotateY, 0f);
            }

            if (arCamera != null)
            {
                var clampedZoom = Mathf.Clamp(zoom, minZoom, maxZoom);
                arCamera.fieldOfView = Mathf.Lerp(58f, 42f, clampedZoom - 0.8f);
            }
        }

        private void EnsureArRig()
        {
            arSession = arSession != null ? arSession : FindFirstObjectByType<ARSession>();
            if (arSession == null)
            {
                var sessionObject = new GameObject("AR Session");
                arSession = sessionObject.AddComponent<ARSession>();
            }

            xrOrigin = xrOrigin != null ? xrOrigin : FindFirstObjectByType<XROrigin>();
            if (xrOrigin == null)
            {
                var originObject = new GameObject("XR Origin");
                xrOrigin = originObject.AddComponent<XROrigin>();
            }

            arCamera = arCamera != null ? arCamera : xrOrigin.Camera;
            arCamera = arCamera != null ? arCamera : Camera.main;

            if (arCamera == null)
            {
                var cameraObject = new GameObject("AR Camera");
                cameraObject.transform.SetParent(
                    xrOrigin.CameraFloorOffsetObject != null
                        ? xrOrigin.CameraFloorOffsetObject.transform
                        : xrOrigin.transform,
                    false
                );
                arCamera = cameraObject.AddComponent<Camera>();
                cameraObject.AddComponent<AudioListener>();
            }

            arCamera.tag = "MainCamera";
            // For URP AR background, always clear color first. Depth-only can leave stale
            // color buffers that appear as yellow/black full-screen overlays on some GPUs.
            arCamera.clearFlags = CameraClearFlags.SolidColor;
            arCamera.backgroundColor = new Color(0f, 0f, 0f, 0f);
            arCamera.nearClipPlane = 0.01f;
            arCamera.depth = 0f;

            xrOrigin.Camera = arCamera;

            arCameraManager = arCamera.GetComponent<ARCameraManager>();
            if (arCameraManager == null)
            {
                arCameraManager = arCamera.gameObject.AddComponent<ARCameraManager>();
            }

            arCameraBackground = arCamera.GetComponent<ARCameraBackground>();
            if (arCameraBackground == null)
            {
                arCameraBackground = arCamera.gameObject.AddComponent<ARCameraBackground>();
            }
            arCameraBackground.useCustomMaterial = false;
            arCameraBackground.enabled = true;

            // Disable camera post-processing for AR feed stability and color correctness.
            var additionalCameraData = arCamera.GetComponent<UniversalAdditionalCameraData>();
            if (additionalCameraData != null)
            {
                additionalCameraData.renderPostProcessing = false;
            }

            humanBodyManager = humanBodyManager != null
                ? humanBodyManager
                : xrOrigin.GetComponent<ARHumanBodyManager>();
            if (humanBodyManager == null)
            {
                humanBodyManager = xrOrigin.gameObject.AddComponent<ARHumanBodyManager>();
            }

            EnsurePoseDriver();
            DisableCameraAttachedRenderers();
            ApplyBackgroundRenderingMode();
        }

        private IEnumerator RestartCameraManagerRoutine()
        {
            if (arCameraManager == null)
            {
                yield break;
            }
            arCameraManager.enabled = false;
            yield return null;
            arCameraManager.enabled = true;
        }

        private IEnumerator ResumeResetRoutine()
        {
            if (arSession != null)
            {
                arSession.enabled = true;
                arSession.Reset();
            }
            yield return StartCoroutine(RestartCameraManagerRoutine());
            if (arCameraBackground != null)
            {
                arCameraBackground.enabled = false;
                yield return null;
                arCameraBackground.enabled = true;
            }
        }

        private void EnsurePoseDriver()
        {
            if (arCamera.GetComponent<TrackedPoseDriver>() == null)
            {
                arCamera.gameObject.AddComponent<TrackedPoseDriver>();
            }
        }

        private void ApplyBackgroundRenderingMode()
        {
            if (arCameraBackground == null)
            {
                return;
            }

            var property = arCameraBackground.GetType().GetProperty(
                "requestedRenderingMode",
                BindingFlags.Instance | BindingFlags.Public
            );
            if (property == null || !property.CanWrite)
            {
                return;
            }

            foreach (var name in Enum.GetNames(property.PropertyType))
            {
                if (!name.Contains("Before", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (!name.Contains("Opaque", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var value = Enum.Parse(property.PropertyType, name);
                property.SetValue(arCameraBackground, value);
                Debug.Log($"[ABZORA AR] AR camera background rendering mode set to {name}.");
                return;
            }
        }

        private void DisableNonArCameras()
        {
            foreach (var cameraRef in FindObjectsByType<Camera>(FindObjectsSortMode.None))
            {
                if (cameraRef == null || cameraRef == arCamera)
                {
                    continue;
                }

                // Keep auxiliary cameras disabled so AR camera remains the sole scene renderer.
                cameraRef.enabled = false;
                if (cameraRef.TryGetComponent<AudioListener>(out var audio))
                {
                    audio.enabled = false;
                }
            }
        }

        private void DisableBlockingDebugMeshes()
        {
            var renderers = FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None);
            foreach (var renderer in renderers)
            {
                if (renderer == null || renderer.GetComponent<SkinnedMeshRenderer>() != null)
                {
                    continue;
                }

                var nameLower = renderer.gameObject.name.ToLowerInvariant();
                var isDebugLike =
                    nameLower.Contains("debug") ||
                    nameLower.Contains("test") ||
                    nameLower.Contains("quad") ||
                    nameLower.Contains("plane") ||
                    nameLower.Contains("cube");

                if (!isDebugLike)
                {
                    continue;
                }

                renderer.enabled = false;
            }
        }

        private void DisableCameraAttachedRenderers()
        {
            if (arCamera == null)
            {
                return;
            }

            var attachedRenderers = arCamera.GetComponentsInChildren<Renderer>(true);
            foreach (var renderer in attachedRenderers)
            {
                if (renderer == null)
                {
                    continue;
                }

                // Never disable the AR camera background component itself.
                if (renderer.gameObject == arCamera.gameObject)
                {
                    continue;
                }

                renderer.enabled = false;
                Debug.Log($"[ABZORA AR] Disabled camera-attached renderer: {renderer.gameObject.name}");
            }
        }

        private Transform ResolveCategoryAnchor(string category)
        {
            if (category.Contains("shoe"))
            {
                return leftFootAnchor != null ? leftFootAnchor : (rightFootAnchor != null ? rightFootAnchor : garmentAnchor);
            }
            if (category.Contains("pant") || category.Contains("bottom") || category.Contains("skirt"))
            {
                return bottomAnchor != null ? bottomAnchor : garmentAnchor;
            }
            return topAnchor != null ? topAnchor : garmentAnchor;
        }

        private void PlaceGarmentInFrontOfCamera(GameObject garmentRoot)
        {
            if (garmentRoot == null)
            {
                return;
            }

            var cam = arCamera != null ? arCamera : Camera.main;
            if (cam == null)
            {
                return;
            }

            var flatForward = Vector3.ProjectOnPlane(cam.transform.forward, Vector3.up).normalized;
            if (flatForward.sqrMagnitude < 0.001f)
            {
                flatForward = Vector3.forward;
            }

            var targetPos = cam.transform.position
                            + flatForward * Mathf.Max(0.7f, previewDistanceMeters)
                            + Vector3.down * Mathf.Clamp(previewVerticalOffsetMeters, 0f, 0.5f);
            garmentRoot.transform.position = targetPos;
            garmentRoot.transform.rotation = Quaternion.LookRotation(flatForward, Vector3.up);
        }
    }
}
