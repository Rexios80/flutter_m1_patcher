import 'dart:io';

import 'package:args/args.dart';

const optionFlutterPath = 'flutter-path';

final parser = ArgParser()
  ..addOption(
    optionFlutterPath,
    abbr: 'p',
    help: 'Flutter root path (determined automatically if not specified)',
    valueHelp: 'path',
  );

void main(List<String> arguments) async {
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (_) {
    print(parser.usage);
    exit(1);
  }

  // Get the path to Flutter
  final String flutterPath;
  if (args[optionFlutterPath] != null) {
    flutterPath = args[optionFlutterPath];
  } else {
    final whichFlutterResult = await Process.run('which', ['flutter']);
    flutterPath = whichFlutterResult.stdout as String;
  }

  // Get the path to Dart
  final whichDartResult = await Process.run('which', ['dart']);
  final dartPath = whichDartResult.stdout as String;

  // Get Flutter's bundled Dart SDK vserion
  final flutterBinPath = File(flutterPath.trim()).parent.path;
  final flutterBinCachePath = flutterBinPath + '/cache';
  final dartSdkVersionFile = File('$flutterBinCachePath/dart-sdk/version');
  final dartSdkVersion = dartSdkVersionFile.readAsStringSync().trim();

  // Exit if Flutter and Dart are in the same location
  // This means the user is running the script with the bundled Dart SDK
  if (dartPath.contains(flutterBinPath)) {
    print(
      'This script is running with Flutter\'s bundled Dart SDK.'
      ' Install Dart with homebrew first.',
    );
    exit(1);
  }

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
    exit(1);
  }

  // Determine the release channel of the bundled Dart SDK
  final String releaseChannel;
  if (dartSdkVersion.contains('beta')) {
    releaseChannel = 'beta';
  } else if (dartSdkVersion.contains('dev')) {
    releaseChannel = 'dev';
  } else {
    releaseChannel = 'stable';
  }

  // Download the Dart SDK
  print('Downloading Dart SDK $dartSdkVersion for macos_arm64...');
  final request = await HttpClient().getUrl(
    Uri.parse(
      'https://storage.googleapis.com/dart-archive/channels/$releaseChannel/release/$dartSdkVersion/sdk/dartsdk-macos-arm64-release.zip',
    ),
  );
  final response = await request.close();
  if (response.statusCode != 200) {
    print(
      'Failed to download Dart SDK.'
      ' This might mean Flutter is using a Dart SDK version that is not available on the Dart website.',
    );
    exit(1);
  }
  await response.pipe(File('$flutterBinCachePath/dart-sdk.zip').openWrite());

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

  exit(0);
}
