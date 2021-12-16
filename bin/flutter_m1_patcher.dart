import 'dart:io';

void main(List<String> arguments) async {
  final result = await Process.run('which', ['flutter']);
  final flutterPath = result.stdout as String;
  final flutterBinFolder = File(flutterPath.trim()).parent;
  final flutterBinCachePath = '${flutterBinFolder.path}/cache';
  final dartSdkVersionFile = File('$flutterBinCachePath/dart-sdk/version');
  final dartSdkVersion = dartSdkVersionFile.readAsStringSync().trim();
  await Process.run('rm', ['-rf', '$flutterBinCachePath/dart-sdk']);
  // Download dart sdk
  await Process.run('curl', [
    '-o',
    '$flutterBinCachePath/dart-sdk.zip',
    'https://storage.googleapis.com/dart-archive/channels/stable/release/$dartSdkVersion/sdk/dartsdk-macos-arm64-release.zip'
  ]);
  // Unzip dart sdk
  await Process.run('unzip', [
    '-o',
    '$flutterBinCachePath/dart-sdk.zip',
    '-d',
    flutterBinCachePath
  ]);
  // Remove zip file
  await Process.run('rm', ['-rf', '$flutterBinCachePath/dart-sdk.zip']);
  // Link the
  await Process.run('ln', [
    '-f',
    '$flutterBinCachePath/dart-sdk/bin/snapshots/frontend_server.dart.snapshot',
    '$flutterBinCachePath/artifacts/engine/darwin-x64/frontend_server.dart.snapshot'
  ]);
}
