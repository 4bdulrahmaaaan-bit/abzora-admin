# Some transitive annotation-processor shaded references can appear in release
# shrink graphs; suppress as they are not used at runtime on Android devices.
-dontwarn javax.lang.model.**
