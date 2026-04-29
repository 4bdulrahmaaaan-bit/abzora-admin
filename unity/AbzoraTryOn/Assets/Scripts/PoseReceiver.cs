using UnityEngine;

namespace Abzora.TryOn
{
    public class PoseReceiver : MonoBehaviour
    {
        [SerializeField] private Transform garmentAnchor;
        [SerializeField] private Transform topAnchor;
        [SerializeField] private Transform bottomAnchor;
        [SerializeField] private Transform leftShoeAnchor;
        [SerializeField] private Transform rightShoeAnchor;
        [SerializeField] private Transform chestAnchor;
        [SerializeField] private Transform shoulderLeftAnchor;
        [SerializeField] private Transform shoulderRightAnchor;
        [SerializeField] private Transform hipAnchor;
        [SerializeField] private Transform spineAnchor;
        [SerializeField] private Transform neckAnchor;
        [SerializeField] private Transform leftElbowAnchor;
        [SerializeField] private Transform rightElbowAnchor;
        [SerializeField] private Transform leftWristAnchor;
        [SerializeField] private Transform rightWristAnchor;
        [SerializeField] private ArVisualTuning tuning;
        [SerializeField] private float positionLerp = 0.28f;
        [SerializeField] private float rotationLerp = 0.22f;
        [SerializeField] private float smoothTime = 0.085f;
        [SerializeField] private Vector3 viewportScale = new Vector3(1.4f, 2.0f, 1f);
        [SerializeField] private float maxPositionStep = 0.085f;
        [SerializeField] private float maxRotationStepDegrees = 10f;
        [SerializeField] private float maxScaleStep = 0.09f;
        [SerializeField] private string layerMode = "top";
        [SerializeField] private float collarYOffset = 0.07f;
        [SerializeField] private float sleeveAnchorZOffset = 0.01f;

        private Vector3 _garmentVelocity;
        private Vector3 _scaleVelocity;
        private Vector3 _chestVelocity;
        private Vector3 _leftShoulderVelocity;
        private Vector3 _rightShoulderVelocity;
        private Vector3 _hipVelocity;
        private Vector3 _spineVelocity;
        private Vector3 _neckVelocity;
        private Vector3 _leftElbowVelocity;
        private Vector3 _rightElbowVelocity;
        private Vector3 _leftWristVelocity;
        private Vector3 _rightWristVelocity;

        public Transform ChestAnchor => chestAnchor != null ? chestAnchor : garmentAnchor;
        public Transform ShoulderLeftAnchor => shoulderLeftAnchor != null ? shoulderLeftAnchor : garmentAnchor;
        public Transform ShoulderRightAnchor => shoulderRightAnchor != null ? shoulderRightAnchor : garmentAnchor;
        public Transform HipAnchor => hipAnchor != null ? hipAnchor : garmentAnchor;
        public Transform SpineAnchor => spineAnchor != null ? spineAnchor : garmentAnchor;
        public Transform NeckAnchor => neckAnchor != null ? neckAnchor : garmentAnchor;
        public Transform LeftElbowAnchor => leftElbowAnchor != null ? leftElbowAnchor : ShoulderLeftAnchor;
        public Transform RightElbowAnchor => rightElbowAnchor != null ? rightElbowAnchor : ShoulderRightAnchor;
        public Transform LeftWristAnchor => leftWristAnchor != null ? leftWristAnchor : LeftElbowAnchor;
        public Transform RightWristAnchor => rightWristAnchor != null ? rightWristAnchor : RightElbowAnchor;

        public void SetLayerMode(string mode)
        {
            var normalized = (mode ?? "top").Trim().ToLowerInvariant();
            if (normalized.Contains("pant") || normalized.Contains("bottom") || normalized.Contains("skirt"))
            {
                normalized = "bottom";
            }
            else if (normalized.Contains("shoe"))
            {
                normalized = "shoes";
            }
            else
            {
                normalized = "top";
            }
            layerMode = normalized;
            var anchor = ResolveActiveAnchor();
            if (anchor != null)
            {
                garmentAnchor = anchor;
            }
        }

        public void ApplyPose(UnityPoseFrame poseFrame)
        {
            if (garmentAnchor == null || poseFrame == null || poseFrame.ShoulderCenter == null)
            {
                return;
            }

            var effectivePositionLerp = tuning != null ? tuning.PositionLerp : positionLerp;
            var effectiveRotationLerp = tuning != null ? tuning.RotationLerp : rotationLerp;
            var effectiveSmoothTime = Mathf.Max(0.02f, smoothTime);
            var effectiveMaxPositionStep = tuning != null ? tuning.MaxPositionStep : maxPositionStep;
            var effectiveMaxRotationStep = tuning != null
                ? tuning.MaxRotationStepDegrees
                : maxRotationStepDegrees;
            var effectiveMaxScaleStep = tuning != null ? tuning.MaxScaleStep : maxScaleStep;
            var activeAnchor = ResolveActiveAnchor();
            if (activeAnchor != null && activeAnchor != garmentAnchor)
            {
                garmentAnchor = activeAnchor;
            }

            var useHipAnchor = layerMode == "bottom";
            var useFeetAnchor = layerMode == "shoes";
            var center = useHipAnchor ? poseFrame.HipCenter : poseFrame.ShoulderCenter;
            if (center == null)
            {
                center = poseFrame.ShoulderCenter;
            }

            var baseYOffset = useHipAnchor ? -0.24f : -0.08f;
            var targetPosition = new Vector3(
                (center.X - 0.5f) * viewportScale.x,
                (0.5f - center.Y) * viewportScale.y + baseYOffset,
                0f
            );

            var shoulderDirection = ComputeShoulderDirection(poseFrame);
            var spineUp = ComputeSpineDirection(poseFrame);
            var shoulderDegrees = Mathf.Atan2(shoulderDirection.y, shoulderDirection.x) * Mathf.Rad2Deg;
            var spineDegrees = Mathf.Atan2(spineUp.x, spineUp.y) * Mathf.Rad2Deg;
            var rotationDegrees = Mathf.Lerp(shoulderDegrees, -spineDegrees, 0.32f);
            var targetRotation = Quaternion.Euler(
                0f,
                0f,
                -Mathf.Lerp(poseFrame.RotationRadians * Mathf.Rad2Deg, rotationDegrees, 0.68f)
            );
            var currentPosition = garmentAnchor.localPosition;
            var clampedPositionDelta = Vector3.ClampMagnitude(
                targetPosition - currentPosition,
                effectiveMaxPositionStep
            );
            var stableTargetPosition = currentPosition + clampedPositionDelta;

            var currentRotation = garmentAnchor.localRotation;
            var rotationStep = Quaternion.RotateTowards(
                currentRotation,
                targetRotation,
                effectiveMaxRotationStep
            );

            garmentAnchor.localPosition = Vector3.SmoothDamp(
                currentPosition,
                stableTargetPosition,
                ref _garmentVelocity,
                effectiveSmoothTime
            );
            garmentAnchor.localRotation = Quaternion.Slerp(
                currentRotation,
                rotationStep,
                effectiveRotationLerp
            );

            var widthSource = useHipAnchor ? Mathf.Max(0.18f, poseFrame.HipWidth) : poseFrame.ShoulderWidth;
            var widthScale = Mathf.Clamp(widthSource * 2.6f, 0.45f, 1.65f);
            var heightScale = Mathf.Clamp(poseFrame.TorsoHeight * 3.15f, 0.55f, 2.15f);
            if (useFeetAnchor)
            {
                widthScale = Mathf.Clamp(poseFrame.ShoulderWidth * 1.15f, 0.38f, 1.1f);
                heightScale = Mathf.Clamp(poseFrame.TorsoHeight * 1.02f, 0.4f, 1.2f);
            }
            var targetScale = new Vector3(widthScale, heightScale, 1f);
            var currentScale = garmentAnchor.localScale;
            var clampedScaleDelta = Vector3.ClampMagnitude(
                targetScale - currentScale,
                effectiveMaxScaleStep
            );
            var stableScale = currentScale + clampedScaleDelta;
            garmentAnchor.localScale = Vector3.SmoothDamp(
                currentScale,
                stableScale,
                ref _scaleVelocity,
                effectiveSmoothTime
            );

            UpdateBodyAnchors(poseFrame, effectiveSmoothTime);
        }

        private void UpdateBodyAnchors(UnityPoseFrame poseFrame, float smoothSeconds)
        {
            if (poseFrame == null || garmentAnchor == null)
            {
                return;
            }

            SmoothAnchor(chestAnchor, ToAnchorPosition(poseFrame.ShoulderCenter, -0.02f), ref _chestVelocity, smoothSeconds);
            SmoothAnchor(hipAnchor, ToAnchorPosition(poseFrame.HipCenter, -0.18f), ref _hipVelocity, smoothSeconds);
            SmoothAnchor(spineAnchor, ToAnchorPosition(poseFrame.SpineCenter ?? poseFrame.ShoulderCenter, -0.06f), ref _spineVelocity, smoothSeconds);
            SmoothAnchor(neckAnchor, ToAnchorPosition(poseFrame.ShoulderCenter, collarYOffset), ref _neckVelocity, smoothSeconds);

            SmoothAnchor(shoulderLeftAnchor, ToAnchorPosition(poseFrame.LeftShoulder, -0.05f), ref _leftShoulderVelocity, smoothSeconds);
            SmoothAnchor(shoulderRightAnchor, ToAnchorPosition(poseFrame.RightShoulder, -0.05f), ref _rightShoulderVelocity, smoothSeconds);
            SmoothAnchor(leftElbowAnchor, ToAnchorPosition(poseFrame.LeftElbow, -0.06f), ref _leftElbowVelocity, smoothSeconds);
            SmoothAnchor(rightElbowAnchor, ToAnchorPosition(poseFrame.RightElbow, -0.06f), ref _rightElbowVelocity, smoothSeconds);
            SmoothAnchor(leftWristAnchor, ToAnchorPosition(poseFrame.LeftWrist, -0.06f), ref _leftWristVelocity, smoothSeconds);
            SmoothAnchor(rightWristAnchor, ToAnchorPosition(poseFrame.RightWrist, -0.06f), ref _rightWristVelocity, smoothSeconds);
        }

        private Vector3 ToAnchorPosition(UnityPosePoint point, float yOffset)
        {
            if (point == null)
            {
                return garmentAnchor.localPosition;
            }
            return new Vector3(
                (point.X - 0.5f) * viewportScale.x,
                (0.5f - point.Y) * viewportScale.y + yOffset,
                sleeveAnchorZOffset
            );
        }

        private static void SmoothAnchor(Transform target, Vector3 desired, ref Vector3 velocity, float smoothSeconds)
        {
            if (target == null)
            {
                return;
            }
            target.localPosition = Vector3.SmoothDamp(
                target.localPosition,
                desired,
                ref velocity,
                smoothSeconds
            );
        }

        private Transform ResolveActiveAnchor()
        {
            if (layerMode == "bottom")
            {
                return bottomAnchor != null ? bottomAnchor : garmentAnchor;
            }
            if (layerMode == "shoes")
            {
                return leftShoeAnchor != null ? leftShoeAnchor : (rightShoeAnchor != null ? rightShoeAnchor : garmentAnchor);
            }
            return topAnchor != null ? topAnchor : garmentAnchor;
        }

        private static Vector2 ComputeShoulderDirection(UnityPoseFrame poseFrame)
        {
            if (poseFrame?.LeftShoulder == null || poseFrame.RightShoulder == null)
            {
                return new Vector2(1f, 0f);
            }
            var dir = new Vector2(
                poseFrame.RightShoulder.X - poseFrame.LeftShoulder.X,
                poseFrame.RightShoulder.Y - poseFrame.LeftShoulder.Y
            );
            if (dir.sqrMagnitude < 0.0001f)
            {
                return new Vector2(1f, 0f);
            }
            return dir.normalized;
        }

        private static Vector2 ComputeSpineDirection(UnityPoseFrame poseFrame)
        {
            if (poseFrame?.ShoulderCenter == null || poseFrame.HipCenter == null)
            {
                return new Vector2(0f, 1f);
            }
            var dir = new Vector2(
                poseFrame.ShoulderCenter.X - poseFrame.HipCenter.X,
                poseFrame.HipCenter.Y - poseFrame.ShoulderCenter.Y
            );
            if (dir.sqrMagnitude < 0.0001f)
            {
                return new Vector2(0f, 1f);
            }
            return dir.normalized;
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
