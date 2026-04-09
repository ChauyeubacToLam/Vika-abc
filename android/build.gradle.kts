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
    // Only map the app module to Flutter's expected workspace build path.
    // Leave pub-cache plugin modules on their defaults to avoid cross-root
    // Java compile path issues on Windows.
    if (project.path == ":app") {
        val appBuildDir: Directory = newBuildDir.dir("app")
        project.layout.buildDirectory.value(appBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}