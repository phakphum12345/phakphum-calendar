import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dependabot tracks every package manager used by the repository', () {
    final config = File('.github/dependabot.yml').readAsStringSync();

    expect(config, contains('version: 2'));
    expect(config, contains('package-ecosystem: composer'));
    expect(config, contains('package-ecosystem: pub'));
    expect(config, contains('package-ecosystem: npm'));
    expect(config, contains('package-ecosystem: github-actions'));
    expect(config, contains('directory: "/backend"'));
    expect(config, contains('directory: "/"'));
    expect(config, contains('interval: daily'));
    expect(config, contains('interval: weekly'));
  });
}
