import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:pub_update_checker/pub_update_checker.dart';

const optionFlutterPath = 'flutter-path';

final parser = ArgParser()
  ..addOption(
    optionFlutterPath,
    abbr: 'p',
    help: 'Flutter root path (determined automatically if not specified)',
    valueHelp: 'path',
  );

final magentaPen = AnsiPen()..magenta();
final greenPen = AnsiPen()..green();
final yellowPen = AnsiPen()..yellow();
final redPen = AnsiPen()..red();

void main(List<String> arguments) async {
  final newVersion = await PubUpdateChecker.check();
  if (newVersion != null) {
    print(
      yellowPen(
        'There is an update available: $newVersion. Run `dart pub global activate flutter_m1_patcher` to update.',
      ),
    );
  }

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (_) {
    print(magentaPen(parser.usage));
    exit(1);
  }

  // Get the path to Flutter
  final String flutterBinPath;
  if (args[optionFlutterPath] != null) {
    final flutterRootPath = args[optionFlutterPath];
    flutterBinPath = '$flutterRootPath/bin';
  } else {
    final whichFlutterResult = await Process.run('which', ['flutter']);
    final flutterPath = whichFlutterResult.stdout as String;
    flutterBinPath = File(flutterPath.trim()).parent.path;
  }

  // Get the path to Dart
  final whichDartResult = await Process.run('which', ['dart']);
  final dartPath = whichDartResult.stdout as String;

  // Get Flutter's bundled Dart SDK vserion
  final flutterBinCachePath = flutterBinPath + '/cache';
  final dartSdkVersionFile = File('$flutterBinCachePath/dart-sdk/version');
  final dartSdkVersion = dartSdkVersionFile.readAsStringSync().trim();

  // Exit if Flutter and Dart are in the same location
  // This means the user is running the script with the bundled Dart SDK
  if (dartPath.contains(flutterBinPath)) {
    print(
      redPen(
        'This script is running with Flutter\'s bundled Dart SDK.'
        ' Install Dart with homebrew first.',
      ),
    );
    exit(1);
  }

  print('Flutter found at $flutterBinPath/flutter');

  // Print the original bundled Dart SDK version
  print('Original bundled Dart SDK version:');
  final dartVersionOldResult =
      await Process.run('$flutterBinPath/dart', ['--version']);
  stdout.write(dartVersionOldResult.stdout);

  // Ask the user for confirmation
  stdout.write(yellowPen('Continue? (y/n) '));
  final confirmation = stdin.readLineSync();
  if (confirmation != 'y') {
    print(redPen('Aborting'));
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
      redPen(
        'Failed to download Dart SDK.'
        ' This might mean Flutter is using a Dart SDK version that is not available on the Dart website.',
      ),
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

  print(greenPen('Done!'));

  exit(0);
}
