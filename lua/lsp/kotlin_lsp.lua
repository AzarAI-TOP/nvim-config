-- Official Kotlin Language Server configuration.
-- Gradle and Maven markers keep each client scoped to its project.
return {
    root_markers = {
        "settings.gradle.kts",
        "settings.gradle",
        "build.gradle.kts",
        "build.gradle",
        "pom.xml",
        ".git",
    },
    settings = { kotlin = { compiler = { jvm = { target = "21" } } } },
}
