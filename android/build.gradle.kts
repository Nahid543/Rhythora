import java.io.File
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// Repositories for all modules (app + plugins)
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force ALL Kotlin compile tasks in ALL subprojects to use JVM target 17
subprojects {
    // Apply to all Kotlin compilation tasks
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
    
    // Apply to all Java compilation tasks
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

private val namespaceFixes =
    mapOf(":on_audio_query_android" to "com.lucasjosino.on_audio_query")

gradle.beforeProject {
    namespaceFixes[project.path]?.let { namespace ->
        val groovyBuild = File(project.projectDir, "build.gradle")
        val kotlinBuild = File(project.projectDir, "build.gradle.kts")
        val target = when {
            groovyBuild.exists() -> groovyBuild
            kotlinBuild.exists() -> kotlinBuild
            else -> null
        }

        target?.let { file -> ensureNamespace(file, namespace) }
    }
}

fun ensureNamespace(file: File, namespace: String) {
    val content = file.readText()
    val namespacePattern = Regex("""(?m)^\s*namespace\s+["']""")
    if (namespacePattern.containsMatchIn(content)) {
        return
    }

    val marker = "android {"
    if (!content.contains(marker)) {
        return
    }

    val namespaceLine =
        if (file.extension == "kts") {
            """    namespace = "$namespace""""
        } else {
            """    namespace '$namespace'"""
        }

    val updated = content.replaceFirst(marker, "$marker\n$namespaceLine")
    if (updated != content) {
        file.writeText(updated)
        println("Injected namespace '$namespace' into ${file.absolutePath}")
    }
}
