allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // On Windows it's common for PUB_CACHE to live on a different drive (e.g. C:) than the
    // Flutter project (e.g. D:). For Android library plugins, AGP generates unit test config
    // files by calling Kotlin's File.toRelativeString(), which throws when paths are on
    // different roots/drives. Only redirect build outputs when the project lives on the same
    // drive as the root build directory.
    val rootDrive = newBuildDir.asFile.toPath().root?.toString()
    val projectDrive = project.projectDir.toPath().root?.toString()
    if (rootDrive != null && projectDrive != null && !rootDrive.equals(projectDrive, ignoreCase = true)) {
        return@subprojects
    }

    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "blue_thermal_printer") {
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            try {
                val currentNamespace = androidExt.javaClass
                    .getMethod("getNamespace")
                    .invoke(androidExt) as? String
                if (currentNamespace.isNullOrBlank()) {
                    androidExt.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, "id.kakzaki.blue_thermal_printer")
                }
            } catch (_: Exception) {
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
