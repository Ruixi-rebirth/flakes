# ref doc: https://nixos.wiki/wiki/Android
{
  pkgs,
  ...
}:
let
  # Create a dedicated pkgs instance for Android SDK with accepted licenses
  androidPkgs = import pkgs.path {
    inherit (pkgs) system;
    config = pkgs.config // {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };

  # Compose Android SDK following the Nixpkgs manual
  # https://nixos.org/manual/nixpkgs/unstable/#android
  androidSdk = androidPkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "13.0";
    platformToolsVersion = "35.0.2";
    buildToolsVersions = [
      "34.0.0"
      "35.0.0"
    ];
    includeEmulator = true;
    platformVersions = [
      "34"
      "35"
    ];
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "x86_64" ];
    includeNDK = false;
  };

  # Path to aapt2 in the SDK for overriding Gradle's default behavior
  aapt2Path = "${androidSdk.androidsdk}/libexec/android-sdk/build-tools/35.0.0/aapt2";
in
{
  home.packages = with pkgs; [
    androidSdk.androidsdk
    android-studio
    jdk17
    # Graphics libraries required by the emulator
    libGL
    libxkbcommon
    vulkan-loader
  ];

  home.sessionVariables = {
    ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${pkgs.jdk17}";

    # Fix aapt2 issue: Force Gradle to use the Nix-provided aapt2
    # This solves "No such file or directory" errors when running ./gradlew on NixOS
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${aapt2Path}";

    # Fix emulator graphics rendering and startup issues on NixOS
    QT_X11_NO_MITSHM = "1";
    LD_LIBRARY_PATH = "${pkgs.libGL}/lib:${pkgs.libxkbcommon}/lib:${pkgs.vulkan-loader}/lib";
  };

  # Automatically add platform-tools and emulator to PATH
  home.sessionPath = [
    "${androidSdk.androidsdk}/libexec/android-sdk/platform-tools"
    "${androidSdk.androidsdk}/libexec/android-sdk/emulator"
  ];
}
