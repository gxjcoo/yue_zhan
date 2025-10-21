// 全局Gradle初始化脚本 - 强制替换所有JCenter仓库
// 解决JCenter关闭导致的依赖下载失败问题

gradle.projectsLoaded {
    allprojects {
    buildscript {
        repositories {
            all {
                if (this is MavenArtifactRepository) {
                    val originalUrl = url.toString()
                    when {
                        originalUrl.startsWith("https://jcenter.bintray.com") -> {
                            println("⚠️  替换 JCenter: $originalUrl -> 阿里云镜像")
                            setUrl("https://maven.aliyun.com/repository/jcenter")
                        }
                        originalUrl.startsWith("https://dl.bintray.com") -> {
                            println("⚠️  替换 Bintray: $originalUrl -> Maven Central")
                            setUrl("https://maven.aliyun.com/repository/central")
                        }
                    }
                }
            }
            maven("https://maven.aliyun.com/repository/google")
            maven("https://maven.aliyun.com/repository/central")
            maven("https://maven.aliyun.com/repository/public")
            maven("https://maven.aliyun.com/repository/jcenter")
            google()
            mavenCentral()
        }
    }

    repositories {
        all {
            if (this is MavenArtifactRepository) {
                val originalUrl = url.toString()
                when {
                    originalUrl.startsWith("https://jcenter.bintray.com") -> {
                        println("⚠️  替换 JCenter: $originalUrl -> 阿里云镜像")
                        setUrl("https://maven.aliyun.com/repository/jcenter")
                    }
                    originalUrl.startsWith("https://dl.bintray.com") -> {
                        println("⚠️  替换 Bintray: $originalUrl -> Maven Central")
                        setUrl("https://maven.aliyun.com/repository/central")
                    }
                }
            }
        }
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/jcenter")
        google()
        mavenCentral()
    }
    }
}

