# Customer flavor ships Unity; partner flavors may compile without unityLibrary.
# When Unity classes are absent (vendor/rider), suppress Unity symbol warnings so
# R8 can strip unreachable plugin code safely.
-dontwarn com.unity3d.player.**
-dontwarn com.unity3d.plugin.**

# Some transitive annotation-processor shaded references can appear in release
# shrink graphs; suppress as they are not used at runtime on Android devices.
-dontwarn javax.lang.model.**
