using UnityEngine;

namespace Abzora.TryOn
{
    public class GarmentMotionController : MonoBehaviour
    {
        [SerializeField] private ArVisualTuning tuning;
        [SerializeField] private float scaleLerp = 7f;
        [SerializeField] private float swayAmplitude = 0.008f;
        [SerializeField] private float swaySpeed = 0.9f;
        [SerializeField] private float breathingAmplitude = 0.012f;
        [SerializeField] private float breathingSpeed = 0.55f;
        [SerializeField] private string fabricPreset = "cotton";

        private Vector3 _targetScale = Vector3.one;
        private Vector3 _baseLocalPosition;
        private bool _initialized;
        private Cloth _cloth;

        public void AssignTuning(ArVisualTuning value)
        {
            tuning = value;
        }

        public void SetTargetScale(Vector3 targetScale)
        {
            _targetScale = targetScale;
            if (!_initialized)
            {
                _baseLocalPosition = transform.localPosition;
                _initialized = true;
                _cloth = GetComponentInChildren<Cloth>();
                ApplyFabricPreset();
            }
        }

        public void ConfigureFabric(string preset)
        {
            if (!string.IsNullOrWhiteSpace(preset))
            {
                fabricPreset = preset.Trim().ToLowerInvariant();
            }
            ApplyFabricPreset();
        }

        private void Update()
        {
            var effectiveScaleLerp = tuning != null ? tuning.MotionScaleLerp : scaleLerp;
            var effectiveSwayAmplitude = tuning != null ? tuning.SwayAmplitude : swayAmplitude;
            var effectiveSwaySpeed = tuning != null ? tuning.SwaySpeed : swaySpeed;
            var effectiveBreathingAmplitude = tuning != null ? tuning.BreathingAmplitude : breathingAmplitude;
            var effectiveBreathingSpeed = tuning != null ? tuning.BreathingSpeed : breathingSpeed;

            transform.localScale = Vector3.Lerp(
                transform.localScale,
                _targetScale,
                Mathf.Clamp01(Time.deltaTime * effectiveScaleLerp)
            );

            if (!_initialized)
            {
                _baseLocalPosition = transform.localPosition;
                _initialized = true;
                _cloth = GetComponentInChildren<Cloth>();
                ApplyFabricPreset();
            }

            var sway = Mathf.Sin(Time.time * effectiveSwaySpeed) * effectiveSwayAmplitude;
            var breathing = Mathf.Sin(Time.time * effectiveBreathingSpeed) * effectiveBreathingAmplitude;
            transform.localPosition = _baseLocalPosition + new Vector3(sway, breathing, 0f);
        }

        private void ApplyFabricPreset()
        {
            var preset = (fabricPreset ?? "cotton").Trim().ToLowerInvariant();
            if (preset == "denim")
            {
                swayAmplitude = 0.004f;
                breathingAmplitude = 0.007f;
                swaySpeed = 0.72f;
                breathingSpeed = 0.48f;
            }
            else if (preset == "silk")
            {
                swayAmplitude = 0.013f;
                breathingAmplitude = 0.018f;
                swaySpeed = 1.08f;
                breathingSpeed = 0.64f;
            }
            else
            {
                swayAmplitude = 0.008f;
                breathingAmplitude = 0.012f;
                swaySpeed = 0.9f;
                breathingSpeed = 0.55f;
            }

            if (_cloth == null)
            {
                return;
            }

            if (preset == "denim")
            {
                _cloth.stretchingStiffness = 0.78f;
                _cloth.bendingStiffness = 0.72f;
                _cloth.damping = 0.62f;
            }
            else if (preset == "silk")
            {
                _cloth.stretchingStiffness = 0.28f;
                _cloth.bendingStiffness = 0.24f;
                _cloth.damping = 0.22f;
            }
            else
            {
                _cloth.stretchingStiffness = 0.52f;
                _cloth.bendingStiffness = 0.46f;
                _cloth.damping = 0.4f;
            }
        }
    }
}
