import java.io.File
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load local properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

val flutterRoot = localProperties.getProperty("flutter.sdk")
    ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.magadi.tangazoletu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.magadi.tangazoletu"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        
        // Default fallback configuration
        buildConfigField("String", "CLIENT_ID", "\"120\"")
        resValue("string", "client_id", "120")
        
        manifestPlaceholders["applicationName"] = "io.flutter.app.FlutterApplication"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    flavorDimensions += "client"
    productFlavors {
        create("tower") {
            dimension = "client"
            applicationId = "com.tower.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"81\"")
            resValue("string", "client_id", "81")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Tower Mobile"
            manifestPlaceholders["mainActivityClass"] = "com.tower.tangazoletu.MainActivity"
        }
        
        create("mentor") {
            dimension = "client"
            applicationId = "com.mentorcash.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"38\"")
            resValue("string", "client_id", "38")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Mentor Cash App"
            manifestPlaceholders["mainActivityClass"] = "com.mentor.tangazoletu.MainActivity"
        }
        create("imarika") {
            dimension = "client"
            applicationId = "com.imarika.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"39\"")
            resValue("string", "client_id", "39")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Imarika Sacco App"
            manifestPlaceholders["mainActivityClass"] = "com.imarika.tangazoletu.MainActivity"
        }
        create("tabasuri") {
            dimension = "client"
            applicationId = "com.tabasuri.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"98\"")
            resValue("string", "client_id", "98")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Tabasuri DT Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.tabasuri.tangazoletu.MainActivity"
        }


        create("fariji") {
            dimension = "client"
            applicationId = "com.tangazoletu.fariji"
            buildConfigField("String", "CLIENT_ID", "\"113\"")
            resValue("string", "client_id", "113")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Fariji Sacco App"
            manifestPlaceholders["mainActivityClass"] = "com.tangazoletu.fariji.MainActivity"
        }

        create("goldenpillar") {
            dimension = "client"
            applicationId = "com.GoldenPillar.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"95\"")
            resValue("string", "client_id", "95")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Golden Pillar Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.GoldenPillar.tangazoletu.MainActivity"
        }

        create("amica") {
            dimension = "client"
            applicationId = "com.amica.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"116\"")
            resValue("string", "client_id", "116")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Amica Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.amica.tangazoletu.MainActivity"
        }
        
        create("magadi") {
            dimension = "client"
            applicationId = "com.magadi.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"120\"")
            resValue("string", "client_id", "120")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Magadi Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.magadi.tangazoletu.MainActivity"
        }
        
        create("mboresha") {
            dimension = "client"
            applicationId = "com.Boresha.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"93\"")
            resValue("string", "client_id", "93")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "M-BORESHA"
            manifestPlaceholders["mainActivityClass"] = "com.Boresha.tangazoletu.MainActivity"
        }
        
        create("tangazoletu") {
            dimension = "client"
            applicationId = "com.tangazoletu.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"999\"")
            resValue("string", "client_id", "999")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Tangazoletu"
            manifestPlaceholders["mainActivityClass"] = "com.tangazoletu.tangazoletu.MainActivity"
        }
        create("mchipuka") {
            dimension = "client"
            applicationId = "com.Mchipuka.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"85\"")
            resValue("string", "client_id", "85")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "M-chipuka Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.Mchipuka.tangazoletu.MainActivity"
        }

        create("gdc") {
            dimension = "client"
            applicationId = "com.githunguri.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"77\"")
            resValue("string", "client_id", "77")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "GDC Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.githunguri.tangazoletu.MainActivity"
        }

        create("shelloyees") {
            dimension = "client"
            applicationId = "com.shelloyees.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"114\"")
            resValue("string", "client_id", "114")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Shelloyees M-Cash"
            manifestPlaceholders["mainActivityClass"] = "com.shelloyees.tangazoletu.MainActivity"
        }

        create("mchai") {
            dimension = "client"
            applicationId = "com.ChaiSacco.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"90\"")
            resValue("string", "client_id", "90")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "M-Chai"
            manifestPlaceholders["mainActivityClass"] = "com.ChaiSacco.tangazoletu.MainActivity"
        }
        create("maishabora") {
            dimension = "client"
            applicationId = "com.maishaBora.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"99\"")
            resValue("string", "client_id", "99")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Maisha Bora sacco"
            manifestPlaceholders["mainActivityClass"] = "com.maishaBora.tangazoletu.MainActivity"
        }


        create("ollin") {
            dimension = "client"
            applicationId = "com.ollinkash.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"54\"")
            resValue("string", "client_id", "54")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Ollin Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.ollinkash.tangazoletu.MainActivity"
        }
                
        create("shirika") {
            dimension = "client"
            applicationId = "com.shirika.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"107\"")
            resValue("string", "client_id", "107")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Shirika Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.shirika.tangazoletu.MainActivity"
        }

        create("kenyattamatibabu") {
            dimension = "client"
            applicationId = "com.kenyattamatibabu.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"115\"")
            resValue("string", "client_id", "115")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Kenyatta Matibabu Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.kenyattamatibabu.tangazoletu.MainActivity"
        }
        create("nafasi") {
            dimension = "client"
            applicationId = "com.nafasi.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"106\"")
            resValue("string", "client_id", "106")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Nafasi Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.nafasi.tangazoletu.MainActivity"
        }
        create("qwetu") {
            dimension = "client"
            applicationId = "com.qwetu.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"78\"")
            resValue("string", "client_id", "78")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Qwetu Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.qwetu.tangazoletu.MainActivity"
        }
        create("nawiri") {
            dimension = "client"
            applicationId = "com.tangazoletu.nawirisacco"
            buildConfigField("String", "CLIENT_ID", "\"68\"")
            resValue("string", "client_id", "68")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Nawiri Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.tangazoletu.nawirisacco.MainActivity"
        }
        create("egerton") {
            dimension = "client"
            applicationId = "com.egertonsacco.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"60\"")
            resValue("string", "client_id", "60")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Egerton Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.egertonsacco.tangazoletu.MainActivity"
        }
        create("kencream") {
            dimension = "client"
            applicationId = "com.kencream.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"108\"")
            resValue("string", "client_id", "108")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Kencream Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.kencream.tangazoletu.MainActivity"
        }
        create("thamani") {
            dimension = "client"
            applicationId = "com.thamani.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"97\"")
            resValue("string", "client_id", "97")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Thamani Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.thamani.tangazoletu.MainActivity"
        }
        create("jogoo") {
            dimension = "client"
            applicationId = "com.Jogoo.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"105\"")
            resValue("string", "client_id", "105")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Jogoo DT Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.Jogoo.tangazoletu.MainActivity"
        }
        create("lengo") {
            dimension = "client"
            applicationId = "com.lengo.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"109\"")
            resValue("string", "client_id", "109")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Lengo Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.lengo.tangazoletu.MainActivity"
        }
        create("kenchic") {
            dimension = "client"
            applicationId = "com.kenchickash.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"112\"")
            resValue("string", "client_id", "112")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Kenchic Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.kenchickash.tangazoletu.MainActivity"
        }
        create("baraka") {
            dimension = "client"
            applicationId = "com.baraka.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"92\"")
            resValue("string", "client_id", "92")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Baraka Yetu Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.baraka.tangazoletu.MainActivity"
        }
        create("smartlife") {
            dimension = "client"
            applicationId = "com.smartlife.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"96\"")
            resValue("string", "client_id", "96")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Smartlife Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.smartlife.tangazoletu.MainActivity"
        }
        create("mwietheri") {
            dimension = "client"
            applicationId = "com.mwietheri.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"88\"")
            resValue("string", "client_id", "88")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Mwietheri Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.mwietheri.tangazoletu.MainActivity"
        }
        create("ngarisha") {
            dimension = "client"
            applicationId = "com.ngarisha.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"51\"")
            resValue("string", "client_id", "51")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Ngarisha Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.ngarisha.tangazoletu.MainActivity"
        }
        create("ports") {
            dimension = "client"
            applicationId = "com.mombasaport.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"104\"")
            resValue("string", "client_id", "104")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Ports Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.mombasaport.tangazoletu.MainActivity"
        }
        create("tai") {
            dimension = "client"
            applicationId = "com.TaiSacco.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"52\"")
            resValue("string", "client_id", "52")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Tai Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.tai.tangazoletu.MainActivity"
        }
        create("bandari") {
            dimension = "client"
            applicationId = "com.bandari.tangazoletu"
            buildConfigField("String", "CLIENT_ID", "\"89\"")
            resValue("string", "client_id", "89")
            versionNameSuffix = ""
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
            manifestPlaceholders["appName"] = "Bandari Sacco"
            manifestPlaceholders["mainActivityClass"] = "com.bandari.tangazoletu.MainActivity"
        }
    }

    // Configure source sets for flavor-specific resources and Kotlin files
    sourceSets {
        getByName("tower") {
            java.srcDirs("src/tower/kotlin")
            res.srcDirs("src/tower/res")
        }
        getByName("mentor") {
            java.srcDirs("src/mentor/kotlin")
            res.srcDirs("src/mentor/res")
        }
        getByName("amica") {
            java.srcDirs("src/amica/kotlin")
            res.srcDirs("src/amica/res")
        }
        getByName("thamani") {
            java.srcDirs("src/thamani/kotlin")
            res.srcDirs("src/thamani/res")
        }
        getByName("tabasuri") {
            java.srcDirs("src/tabasuri/kotlin")
            res.srcDirs("src/tabasuri/res")
        }
        getByName("smartlife"){
            java.srcDirs("src/smartlife/kotlin")
            res.srcDirs("src/smartlife/res")
        }
        getByName("magadi") {
            java.srcDirs("src/magadi/kotlin")
            res.srcDirs("src/magadi/res")
        }
        getByName("nafasi") {
            java.srcDirs("src/nafasi/kotlin")
            res.srcDirs("src/nafasi/res")
        }
        getByName("egerton"){
            java.srcDirs("src/egerton/kotlin")
            java.srcDirs("src/egerton/kotlin")
        }
        getByName("ngarisha"){
            java.srcDirs("src/ngarisha/kotlin")
            res.srcDirs("src/ngarisha/res")
        }
        getByName("mboresha") {
            java.srcDirs("src/mboresha/kotlin")
            res.srcDirs("src/mboresha/res")
        }
        getByName("jogoo"){
            java.srcDirs("src/jogoo/kotlin")
            res.srcDirs("src/jogoo/res")
        }
        getByName("goldenpillar"){
            java.srcDirs("src/goldenpillar/kotlin")
            res.srcDirs("src/goldenpillar/res")
        }
        getByName("shirika") {
            java.srcDirs("src/shirika/kotlin")
            res.srcDirs("src/shirika/res")
        }
        getByName("kenchic") {
            java.srcDirs("src/kenchic/kotlin")
            res.srcDirs("src/kenchic/res")
        }
        getByName("mchai"){
            java.srcDirs("src/mchai/kotlin")
            res.srcDirs("src/mchai/res")
        }
        getByName("mchipuka") {
            java.srcDirs("src/mchipuka/kotlin")
            res.srcDirs("src/mchipuka/res")
        }
        getByName("tangazoletu") {
            java.srcDirs("src/tangazoletu/kotlin")
            res.srcDirs("src/tangazoletu/res")
        }
        getByName("gdc") {
            java.srcDirs("src/gdc/kotlin")
            res.srcDirs("src/gdc/res")
        }
        getByName("shelloyees") {
            java.srcDirs("src/shelloyees/kotlin")
            res.srcDirs("src/shelloyees/res")
        }
        getByName("ollin") {
            java.srcDirs("src/ollin/kotlin")
            res.srcDirs("src/ollin/res")
        }
        getByName("imarika") {
            java.srcDirs("src/imarika/kotlin")
            res.srcDirs("src/imarika/res")
        }
        getByName("nawiri") {
            java.srcDirs("src/nawiri/kotlin")
            res.srcDirs("src/nawiri/res")
        }
        getByName("kenyattamatibabu") {
            java.srcDirs("src/kenyattamatibabu/kotlin")
            res.srcDirs("src/kenyattamatibabu/kotlin")
        }
        getByName("qwetu") {
            java.srcDirs("src/qwetu/kotlin")
            res.srcDirs("src/qwetu/res")
        }
        getByName("maishabora"){
            java.srcDirs("src/maishabora/kotlin")
            res.srcDirs("src/maishabora/res")
        }
        getByName("lengo"){
            java.srcDirs("src/lengo/kotlin")
            res.srcDirs("src/lengo/res")
        }
        getByName("baraka"){
            java.srcDirs("src/baraka/kotlin")
            res.srcDirs("src/baraka/res")
        }
        getByName("kencream"){
            java.srcDirs("src/kencream/kotlin")
            res.srcDirs("src/kencream/res")
        }
        getByName("mwietheri"){
            java.srcDirs("src/mwietheri/kotlin")
            java.srcDirs("src/mwietheri/res")
        }
        getByName("fariji"){
            java.srcDirs("src/fariji/kotlin")
            res.srcDirs("src/fariji/res")
        }
        getByName("ports") {
            java.srcDirs("src/ports/kotlin")
            res.srcDirs("src/ports/res")
        }
        getByName("tai") {
            java.srcDirs("src/tai/kotlin")
            res.srcDirs("src/tai/res")
        }
        getByName("bandari") {
            java.srcDirs("src/bandari/kotlin")
            res.srcDirs("src/bandari/res")
        }
    }

    packagingOptions {
        pickFirst("**/libc++_shared.so")
        pickFirst("**/libjsc.so")
    }

    bundle {
        storeArchive {
            enable = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    val kotlinVersion = rootProject.extra["kotlin_version"] as String
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion")
}

// Extension function to capitalize string
fun String.capitalizeFirstChar(): String =
    this.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }

// Function to get project root directory
fun getProjectRoot(): File {
    return project.projectDir.parentFile.parentFile
}

// Function to generate pubspec.yaml for a specific flavor
fun generatePubspecForFlavor(flavor: String) {
    val clientId = when(flavor) {
        "tower" -> "81"
        "mentor" -> "38"
        "amica" -> "116"
        "magadi" -> "120"
        "mboresha" -> "93"
        "tangazoletu" -> "999"
        "shelloyees" -> "114"
        "ollin" -> "54"
        "ports" -> "104"
        "mchipuka" -> "85"
        "gdc" -> "77"
        "fariji" -> "113"
        "imarika" -> "39"
        "mchai" -> "90"
        "maishabora" -> "99"
        "kenyattamatibabu" ->"115"
        "shirika" ->"107"
        "tabasuri" ->"98"
        "nawiri" -> "68"
        "egerton" ->"60"
        "qwetu" ->"78"
        "nafasi"->"106"
        "kencream"->"108"
        "smartlife"->"96"
        "thamani"->"97"
        "jogoo" ->"105"
        "lengo" ->"109"
        "kenchic"->"112"
        "ngarisha"->"51"
        "baraka"->"92"
        "mwietheri"->"88"
        "tai"->"52"
        "bandari"->"89"
        "goldenpillar"->"95"
        else -> "120"
    }

    println("Generating pubspec.yaml for client $clientId (flavor: $flavor)")

    val projectRoot = getProjectRoot()
    val pubspecFile = File(projectRoot, "pubspec.yaml")
    val backupFile = File(projectRoot, "pubspec.backup.yaml")

    // Backup original pubspec only if backup doesn't exist
    if (!backupFile.exists()) {
        pubspecFile.copyTo(backupFile)
        println("Created backup of original pubspec.yaml")
    }

    // Read the backup pubspec content (the original)
    val pubspecContent = backupFile.readText()

    // Find the placeholder line and its indentation
    val lines = pubspecContent.lines()
    val placeholderIndex = lines.indexOfFirst { it.contains("# CLIENT_SPECIFIC_ASSETS") }

    if (placeholderIndex == -1) {
        println("Warning: # CLIENT_SPECIFIC_ASSETS placeholder not found")
        return
    }

    // Find the indentation from the previous asset line for consistency
    var assetIndentation = ""
    for (i in placeholderIndex - 1 downTo 0) {
        val line = lines[i].trimEnd()
        if (line.contains("- assets/")) {
            assetIndentation = line.takeWhile { it.isWhitespace() }
            println("Found asset indentation from existing assets: '${assetIndentation}' (${assetIndentation.length} chars)")
            break
        }
    }

    // If we couldn't find asset indentation from existing assets, use placeholder indentation
    if (assetIndentation.isEmpty()) {
        assetIndentation = lines[placeholderIndex].takeWhile { it.isWhitespace() }
    }

    // Read client-specific assets
    val clientAssetsFile = File(projectRoot, "assets_config/${clientId}.yaml")
    val clientAssetLines = if (clientAssetsFile.exists()) {
        clientAssetsFile.readLines()
            .filter { it.trim().isNotEmpty() }
            .map { assetIndentation + it.trim() } // Apply the correct indentation
    } else {
        println("Warning: No assets config found for client $clientId")
        emptyList()
    }

    // Create new lines list with proper replacement
    val newLines = mutableListOf<String>()
    for (i in lines.indices) {
        if (i == placeholderIndex) {
            // Replace placeholder with all client asset lines
            newLines.addAll(clientAssetLines)
        } else {
            newLines.add(lines[i])
        }
    }

    val newPubspecContent = newLines.joinToString("\n")

    // Write the modified pubspec
    pubspecFile.writeText(newPubspecContent)
    println("Generated pubspec.yaml for client $clientId")

    // Debug: Print the assets section
    val assetsIndex = newLines.indexOfFirst { it.trim().startsWith("assets:") }
    if (assetsIndex != -1) {
        println("Assets section preview:")
        for (i in assetsIndex..minOf(assetsIndex + 10, newLines.size - 1)) {
            println("Line $i: '${newLines[i]}'")
        }
    }
}

// Function to restore original pubspec.yaml
fun restorePubspec() {
    val projectRoot = getProjectRoot()
    val pubspecFile = File(projectRoot, "pubspec.yaml")
    val backupFile = File(projectRoot, "pubspec.backup.yaml")

    if (backupFile.exists()) {
        backupFile.copyTo(pubspecFile, overwrite = true)
        backupFile.delete()
        println("Restored original pubspec.yaml")
    }
}

// Hook into the build process
afterEvaluate {
    android.applicationVariants.forEach { variant ->
        val flavorName = variant.flavorName
        val capitalizedVariantName = variant.name.capitalizeFirstChar()
        
        // Debug output
        println("Processing variant: ${variant.name}, flavor: $flavorName")

        // Before build starts, generate client-specific pubspec
        val preBuildTaskName = "pre${capitalizedVariantName}Build"
        tasks.findByName(preBuildTaskName)?.doFirst {
            generatePubspecForFlavor(flavorName)
        }

        // After build completes, restore original pubspec
        val assembleTaskName = "assemble${capitalizedVariantName}"
        tasks.findByName(assembleTaskName)?.doLast {
            restorePubspec()
        }

        // Generate MainActivity for all packages dynamically
        val packageName = variant.applicationId
        val flavor = variant.flavorName
        val srcDir = File(project.projectDir, "src/${flavor}/kotlin/${packageName.replace('.', '/')}")
        srcDir.mkdirs()

        val mainActivityFile = File(srcDir, "MainActivity.kt")
        if (!mainActivityFile.exists()) {
            // Create a simple MainActivity that extends BaseMainActivity
            // CLIENT_ID will be accessed via BuildConfig in BaseMainActivity
            mainActivityFile.writeText("""
            package $packageName
            
            import com.base.BaseMainActivity
            
            class MainActivity : BaseMainActivity()
            """.trimIndent())
            println("Created MainActivity.kt for package $packageName")
        }
    }
}

// Clean up on gradle clean
tasks.register("cleanPubspecBackup") {
    doLast {
        restorePubspec()
    }
}

tasks.named("clean") {
    dependsOn("cleanPubspecBackup")
}
