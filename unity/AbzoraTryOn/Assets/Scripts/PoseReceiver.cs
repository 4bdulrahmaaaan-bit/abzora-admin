using UnityEngine;

namespace Abzora.TryOn
{
    public class PoseReceiver : MonoBehaviour
    {
        [SerializeField] private Transform garmentAnchor;
        [SerializeField] private float positionLerp = 0.28f;
        [SerializeField] private float rotationLerp = 0.22f;
        [SerializeField] private Vector3 viewportScale = new Vector3(1.4f, 2.0f, 1f);

        public void ApplyPose(UnityPoseFrame poseFrame)
        {
            if (garmentAnchor == null || poseFrame == null || poseFrame.shoulderCenter == null)
            {
                return;
            }

            var targetPosition = new Vector3(
                (poseFrame.shoulderCenter.x - 0.5f) * viewportScale.x,
                (0.5f - poseFrame.shoulderCenter.y) * viewportScale.y - 0.08f,
                0f
            );
            var targetRotation = Quaternion.Euler(0f, 0f, -poseFrame.rotationRadians * Mathf.Rad2Deg);

            garmentAnchor.localPosition = Vector3.Lerp(
                garmentAnchor.localPosition,
                targetPosition,
                positionLerp
            );
            garmentAnchor.localRotation = Quaternion.Slerp(
                garmentAnchor.localRotation,
                targetRotation,
                rotationLerp
            );

            var widthScale = Mathf.Clamp(poseFrame.shoulderWidth * 2.6f, 0.45f, 1.65f);
            var heightScale = Mathf.Clamp(poseFrame.torsoHeight * 3.15f, 0.55f, 2.15f);
            var targetScale = new Vector3(widthScale, heightScale, 1f);
            garmentAnchor.localScale = Vector3.Lerp(
                garmentAnchor.localScale,
                targetScale,
                positionLerp
            );
        }

        public void ResetPose()
        {
            if (garmentAnchor == null)
            {
                return;
            }

            garmentAnchor.localPosition = Vector3.zero;
            garmentAnchor.localRotation = Quaternion.identity;
            garmentAnchor.localScale = Vector3.one;
        }
    }
}
