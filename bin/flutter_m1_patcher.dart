import 'dart:io';

void main(List<String> arguments) async {
  // Get the path to Flutter
  final whichFlutterResult = await Process.run('which', ['flutter']);
  final flutterPath = whichFlutterResult.stdout as String;

  // Get Flutter's Dart SDK vserion
  final flutterBinPath = File(flutterPath.trim()).parent.path;
  final flutterBinCachePath = flutterBinPath + '/cache';
  final dartSdkVersionFile = File('$flutterBinCachePath/dart-sdk/version');
  final dartSdkVersion = dartSdkVersionFile.readAsStringSync().trim();

  stdout.write('Flutter found at $flutterPath');

  // Print the original bundled Dart SDK version
  print('Original bundled Dart SDK version:');
  final dartVersionOldResult =
      await Process.run('$flutterBinPath/dart', ['--version']);
  stdout.write(dartVersionOldResult.stdout);

  // Ask the user for confirmation
  stdout.write('Continue? (y/n) ');
  final confirmation = stdin.readLineSync();
  if (confirmation != 'y') {
    print('Aborting');
    return;
  }

  // Download the Dart SDK
  print('Downloading Dart SDK $dartSdkVersion for macos_arm64...');
  await Process.run(
    'curl',
    [
      '-o',
      '$flutterBinCachePath/dart-sdk.zip',
      'https://storage.googleapis.com/dart-archive/channels/stable/release/$dartSdkVersion/sdk/dartsdk-macos-arm64-release.zip'
    ],
  );

  // Delete the existing dart-sdk folder
  print('Deleting bundled Dart SDK...');
  Directory('$flutterBinCachePath/dart-sdk').deleteSync(recursive: true);

  // Unzip the Dart SDK
  print('Unzipping Dart SDK...');
  await Process.run(
    'unzip',
    ['-o', '$flutterBinCachePath/dart-sdk.zip', '-d', flutterBinCachePath],
  );

  // Delete the zip file
  print('Deleting zip file...');
  File('$flutterBinCachePath/dart-sdk.zip').deleteSync();

  // Delete the existing engine frontend_server.dart.snapshot file
  print('Deleting engine frontend_server.dart.snapshot file...');
  File('$flutterBinCachePath/artifacts/engine/darwin-x64/frontend_server.dart.snapshot')
      .deleteSync();

  // Copy the dart-sdk frontend_server.dart.snapshot file to the engine folder
  print('Copying Dart SDK frontend_server.dart.snapshot file to engine...');
  File('$flutterBinCachePath/dart-sdk/bin/snapshots/frontend_server.dart.snapshot')
      .copySync(
    '$flutterBinCachePath/artifacts/engine/darwin-x64/frontend_server.dart.snapshot',
  );

  // Print the new bundled Dart SDK version
  print('New bundled Dart SDK version:');
  final dartVersionNewResult =
      await Process.run('$flutterBinPath/dart', ['--version']);
  stdout.write(dartVersionNewResult.stdout);

  print('Done!');
}
