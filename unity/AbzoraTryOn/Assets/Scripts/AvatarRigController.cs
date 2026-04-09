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

        public void ApplyMeasurements(UnityMeasurementMap measurements)
        {
            if (measurements == null)
            {
                return;
            }

            var width = Mathf.Clamp(measurements.shoulderCm / 42f, 0.88f, 1.28f);
            var torso = Mathf.Clamp(measurements.chestCm / 96f, 0.9f, 1.32f);
            var height = Mathf.Clamp(measurements.heightCm / 170f, 0.88f, 1.22f);
            _targetScale = new Vector3(width, (torso + height) * 0.5f, 1f);
        }
    }
}
