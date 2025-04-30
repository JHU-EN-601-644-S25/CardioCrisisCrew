// ccc/build.gradle.kts
plugins {
    id("com.android.application") version "8.5.0"   // or library
    id("org.jetbrains.kotlin.android") version "2.0.0"
    id("org.cyclonedx.bom") version "2.2.0"
    id("org.sonarqube") version "4.4.1.3373"  // example version
}


sonarqube {
  properties {
    property("sonar.projectKey", "com.cardio:ccc")
    property("sonar.host.url", "http://localhost:9000")
    property("sonar.login", System.getenv("SONAR_TOKEN"))
  }
}


group = "com.cardio.crisis"
version = "0.1.0"

android {
    namespace  = "com.cardio.crisis"
    compileSdk = 34
    defaultConfig {
        minSdk    = 24
        targetSdk = 34
    }
}
