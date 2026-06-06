import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion

allprojects {
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs(
                rootProject.file("app/libs"),
            )
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(KotlinVersion.KOTLIN_2_0)
            apiVersion.set(KotlinVersion.KOTLIN_2_0)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
