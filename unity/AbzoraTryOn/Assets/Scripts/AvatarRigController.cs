using UnityEngine;

namespace Abzora.TryOn
{
    public class AvatarRigController : MonoBehaviour
    {
        [SerializeField] private Transform avatarRoot;
        [SerializeField] private float measurementLerp = 0.2f;

        private Vector3 _targetScale = Vector3.one;

        private void Update()
        {
            if (avatarRoot == null)
            {
                return;
            }

            avatarRoot.localScale = Vector3.Lerp(
                avatarRoot.localScale,
                _targetScale,
                measurementLerp
            );
        }

        public void ApplyMeasurements(MeasurementMap measurements)
        {
            if (measurements == null)
            {
                return;
            }

            var width = Mathf.Clamp(measurements.ShoulderCm / 42f, 0.88f, 1.28f);
            var torso = Mathf.Clamp(measurements.ChestCm / 96f, 0.9f, 1.32f);
            var height = Mathf.Clamp(measurements.HeightCm / 170f, 0.88f, 1.22f);
            _targetScale = new Vector3(width, (torso + height) * 0.5f, 1f);
        }

        public Vector3 ComputeGarmentScale(MeasurementMap measurements, AlignmentConfig alignment)
        {
            if (measurements == null)
            {
                return Vector3.one;
            }

            var widthScale = Mathf.Clamp(measurements.ChestCm / 96f, 0.82f, 1.4f);
            var heightScale = Mathf.Clamp(measurements.HeightCm / 170f, 0.84f, 1.28f);
            var depthScale = Mathf.Clamp(measurements.WaistCm / 84f, 0.84f, 1.34f);
            var scaleFactor = alignment?.ScaleFactor ?? 1f;
            var widthFactor = alignment?.WidthFactor ?? 1f;
            var heightFactor = alignment?.HeightFactor ?? 1f;

            return new Vector3(
                widthScale * widthFactor * scaleFactor,
                heightScale * heightFactor * scaleFactor,
                depthScale * scaleFactor
            );
        }
    }
}
