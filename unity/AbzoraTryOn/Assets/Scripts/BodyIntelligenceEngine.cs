using UnityEngine;

namespace Abzora.TryOn
{
    public class BodyIntelligenceEngine : MonoBehaviour
    {
        [SerializeField] private float shoulderToCmFactor = 58f;
        [SerializeField] private float hipToCmFactor = 62f;
        [SerializeField] private float torsoToHeightFactor = 2.95f;
        [SerializeField] private float measurementLerp = 0.28f;

        public void UpdateMeasurements(MeasurementMap measurements, UnityPoseFrame poseFrame)
        {
            if (measurements == null || poseFrame == null)
            {
                return;
            }

            var targetShoulder = Mathf.Clamp(poseFrame.ShoulderWidth * shoulderToCmFactor, 34f, 62f);
            var targetHip = Mathf.Clamp(poseFrame.HipWidth * hipToCmFactor, 34f, 66f);
            var targetHeight = Mathf.Clamp(poseFrame.TorsoHeight * torsoToHeightFactor * 100f, 145f, 205f);
            var estimatedChest = Mathf.Clamp(targetShoulder * 2.2f + 4f, 76f, 140f);
            var estimatedWaist = Mathf.Clamp(targetHip * 1.85f, 62f, 132f);

            measurements.ShoulderCm = Mathf.Lerp(measurements.ShoulderCm, targetShoulder, measurementLerp);
            measurements.HipCm = Mathf.Lerp(measurements.HipCm, targetHip, measurementLerp);
            measurements.HeightCm = Mathf.Lerp(measurements.HeightCm, targetHeight, measurementLerp * 0.22f);
            measurements.ChestCm = Mathf.Lerp(measurements.ChestCm, estimatedChest, measurementLerp);
            measurements.WaistCm = Mathf.Lerp(measurements.WaistCm, estimatedWaist, measurementLerp);
        }

        public string ClassifyBodyType(MeasurementMap measurements)
        {
            if (measurements == null)
            {
                return "regular";
            }

            var shoulderHipRatio = Mathf.Max(0.01f, measurements.ShoulderCm / Mathf.Max(1f, measurements.HipCm));
            var chestWaistRatio = Mathf.Max(0.01f, measurements.ChestCm / Mathf.Max(1f, measurements.WaistCm));

            if (measurements.WaistCm >= 102f || chestWaistRatio < 1.05f)
            {
                return "plus";
            }
            if (shoulderHipRatio > 1.08f && chestWaistRatio > 1.18f)
            {
                return "athletic";
            }
            if (measurements.ChestCm < 92f && measurements.WaistCm < 80f)
            {
                return "slim";
            }
            return "regular";
        }
    }
}
