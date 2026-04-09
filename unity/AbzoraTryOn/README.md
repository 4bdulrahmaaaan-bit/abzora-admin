# ABZORA Unity Try-On Project

This folder is the Unity-side premium renderer scaffold for ABZORA.

Recommended Unity setup:

- Unity 2022 LTS
- URP
- AR Foundation
- ARCore XR Plugin
- ARKit XR Plugin
- Addressables or AssetBundles for garments

Suggested structure:

- `Assets/Scenes/TryOnScene.unity`
- `Assets/Scripts/PoseReceiver.cs`
- `Assets/Scripts/GarmentLoader.cs`
- `Assets/Scripts/AvatarRigController.cs`
- `Assets/Scripts/FlutterUnityBridge.cs`
- `Assets/Prefabs/`
- `Assets/Materials/`
- `Assets/StreamingAssets/`

The Flutter app already expects:

- `unityAssetBundleUrl`
- `model3dUrl`
- `rigProfile`
- `materialProfile`

Use this project as the premium 3D mode, not the baseline renderer.
