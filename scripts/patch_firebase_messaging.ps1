# Patches firebase_messaging Android Java for Flutter 3.32+ (FlutterShellArgs API change).
# Run after `flutter pub get` if Android build fails with fromIntent / toArray errors.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/patch_firebase_messaging.ps1

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$lockFile = Join-Path $projectRoot "pubspec.lock"
if (-not (Test-Path $lockFile)) {
    Write-Error "Run from project root after flutter pub get (pubspec.lock missing)."
}

$version = "16.2.2"
$lockText = Get-Content -Path $lockFile -Raw
if ($lockText -match "firebase_messaging:[\s\S]*?version:\s+""([^""]+)""") {
    $version = $Matches[1]
}

$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"
$pluginDir = Join-Path $pubCache "firebase_messaging-$version\android\src\main\java\io\flutter\plugins\firebase\messaging"

if (-not (Test-Path $pluginDir)) {
    Write-Error "firebase_messaging not found at $pluginDir - run flutter pub get first."
}

function Apply-Patch {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New,
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Missing file: $Label"
        return
    }

    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    if ($content.Contains($New)) {
        Write-Host "OK (already patched): $Label"
        return
    }
    if (-not $content.Contains($Old)) {
        Write-Warning "Skip (pattern changed): $Label"
        return
    }

    $content = $content.Replace($Old, $New)
    Set-Content -Path $Path -Value $content -NoNewline -Encoding UTF8
    Write-Host "Patched: $Label"
}

$serviceFile = Join-Path $pluginDir "FlutterFirebaseMessagingBackgroundService.java"
$pluginFile = Join-Path $pluginDir "FlutterFirebaseMessagingPlugin.java"
$executorFile = Join-Path $pluginDir "FlutterFirebaseMessagingBackgroundExecutor.java"

Apply-Patch -Path $serviceFile -Label "FlutterFirebaseMessagingBackgroundService.java" -Old @'
  public static void startBackgroundIsolate(long callbackHandle, FlutterShellArgs shellArgs) {
    if (flutterBackgroundExecutor != null) {
      Log.w(TAG, "Attempted to start a duplicate background isolate. Returning...");
      return;
    }
    flutterBackgroundExecutor = new FlutterFirebaseMessagingBackgroundExecutor();
    flutterBackgroundExecutor.startBackgroundIsolate(callbackHandle, shellArgs);
  }
'@ -New @'
  public static void startBackgroundIsolate(long callbackHandle) {
    if (flutterBackgroundExecutor != null) {
      Log.w(TAG, "Attempted to start a duplicate background isolate. Returning...");
      return;
    }
    flutterBackgroundExecutor = new FlutterFirebaseMessagingBackgroundExecutor();
    flutterBackgroundExecutor.startBackgroundIsolate(callbackHandle);
  }
'@

Apply-Patch -Path $pluginFile -Label "FlutterFirebaseMessagingPlugin.java" -Old @'
        FlutterShellArgs shellArgs = null;
        if (mainActivity != null) {
          // Supports both Flutter Activity types:
          //    io.flutter.embedding.android.FlutterFragmentActivity
          //    io.flutter.embedding.android.FlutterActivity
          // We could use `getFlutterShellArgs()` but this is only available on `FlutterActivity`.
          shellArgs = FlutterShellArgs.fromIntent(mainActivity.getIntent());
        }

        FlutterFirebaseMessagingBackgroundService.setCallbackDispatcher(pluginCallbackHandle);
        FlutterFirebaseMessagingBackgroundService.setUserCallbackHandle(userCallbackHandle);
        FlutterFirebaseMessagingBackgroundService.startBackgroundIsolate(
            pluginCallbackHandle, shellArgs);
'@ -New @'
        // Flutter 3.32+ removed Intent-based FlutterShellArgs; background isolate uses defaults.
        FlutterFirebaseMessagingBackgroundService.setCallbackDispatcher(pluginCallbackHandle);
        FlutterFirebaseMessagingBackgroundService.setUserCallbackHandle(userCallbackHandle);
        FlutterFirebaseMessagingBackgroundService.startBackgroundIsolate(pluginCallbackHandle);
'@

Apply-Patch -Path $executorFile -Label "FlutterFirebaseMessagingBackgroundExecutor.java" -Old @'
  public void startBackgroundIsolate(long callbackHandle, FlutterShellArgs shellArgs) {
'@ -New @'
  public void startBackgroundIsolate(long callbackHandle) {
'@

Apply-Patch -Path $executorFile -Label "BackgroundExecutor startBackgroundIsolate(null)" -Old @'
        startBackgroundIsolate(callbackHandle, null);
'@ -New @'
        startBackgroundIsolate(callbackHandle);
'@

Apply-Patch -Path $executorFile -Label "BackgroundExecutor FlutterEngine" -Old @'
                if (isNotRunning()) {
                  if (shellArgs != null) {
                    Log.i(
                        TAG,
                        "Creating background FlutterEngine instance, with args: "
                            + Arrays.toString(shellArgs.toArray()));
                    backgroundFlutterEngine =
                        new FlutterEngine(
                            ContextHolder.getApplicationContext(), shellArgs.toArray());
                  } else {
                    Log.i(TAG, "Creating background FlutterEngine instance.");
                    backgroundFlutterEngine =
                        new FlutterEngine(ContextHolder.getApplicationContext());
                  }
'@ -New @'
                if (isNotRunning()) {
                  Log.i(TAG, "Creating background FlutterEngine instance.");
                  backgroundFlutterEngine =
                      new FlutterEngine(ContextHolder.getApplicationContext());
'@

Write-Host ""
Write-Host "Done. Run: flutter clean && flutter run"
