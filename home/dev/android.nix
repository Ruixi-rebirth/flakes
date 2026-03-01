# ref. doc:
# https://nixos.wiki/wiki/Android
# https://nixos.org/manual/nixpkgs/unstable/#android
# https://nixos.org/manual/nixpkgs/unstable/#deploying-an-android-sdk-installation-with-plugins
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/mobile/androidenv/compose-android-packages.nix
# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/editors/android-studio/common.nix
{
  pkgs,
  lib,
  ...
}:
let
  # Create a dedicated pkgs instance for Android SDK with accepted licenses
  androidPkgs' = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };

  # Method1: Using predefined Android package compositions
  predefine = androidPkgs'.androidenv.androidPkgs;

  # Method2: Deploying an Android SDK installation with plugins
  custom = androidPkgs'.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "13.0";
    toolsVersion = "26.1.1";
    platformToolsVersion = "35.0.2";
    buildToolsVersions = [
      "34.0.0"
      "35.0.0"
      "36.0.0"
    ];
    includeEmulator = true;
    platformVersions = [
      "34"
      "35"
      "36"
    ];
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "x86_64" ];
    includeNDK = "if-supported";
  };

  # Method3: Using androidenv with Android Studio
  android-studio' = pkgs.androidStudioPackages.canary.full; # support a very complete Android SDK, including system images, will export ANDROID_SDK_ROOT and ANDROID_NDK_ROOT
  # not full, with composeAndroidPackages
  android-studio-no-full =
    pkgs.androidStudioPackages.canary.withSdk
      (androidPkgs'.androidenv.composeAndroidPackages { includeNDK = true; }).androidsdk;
in
{
  home.packages = with pkgs; [
    predefine.androidsdk
    (androidStudioPackages.canary.override {
      tiling_wm = true; # sway, etc.
    })
    jdk17
  ];

  home.sessionVariables =
    let
      buildToolsBase = "${predefine.androidsdk}/libexec/android-sdk/build-tools";
      highestbuildToolsVersion = lib.last (
        lib.naturalSort (builtins.attrNames (builtins.readDir buildToolsBase))
      );
      aapt2Path = "${buildToolsBase}/${highestbuildToolsVersion}/aapt2";
    in
    rec {
      ANDROID_HOME = "${predefine.androidsdk}/libexec/android-sdk";
      ANDROID_SDK_ROOT = "${predefine.androidsdk}/libexec/android-sdk"; # ANDROID_SDK_ROOT is deprecated, but if you rely on tools that need it
      ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";
      JAVA_HOME = "${pkgs.jdk17}";

      # Fix aapt2 issue: Force Gradle to use the Nix-provided aapt2
      GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${aapt2Path}";
    };

  # Automatically add platform-tools and emulator to PATH
  home.sessionPath = [
    "${predefine.androidsdk}/libexec/android-sdk/platform-tools"
    "${predefine.androidsdk}/libexec/android-sdk/emulator"
  ];
}
