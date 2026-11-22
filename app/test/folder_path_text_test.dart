import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setding/ui/backup/folder_path_text.dart';

/// The path of the backup folder, shortened in the middle (#889).
void main() {
  group('shortenPath', () {
    bool shorterThan(int n, String text) => text.length < n;

    test('a path that fits stays', () {
      expect(shortenPath('~/Backups/Band', (_) => true), '~/Backups/Band');
    });

    test('the middle gives way, start and folder stay', () {
      const path = '~/Nextcloud/Music/Backups/setDING';
      expect(
        shortenPath(path, (t) => shorterThan(24, t)),
        '~/…/Backups/setDING',
      );
      expect(shortenPath(path, (t) => shorterThan(16, t)), '~/…/setDING');
      // Never less than the folder itself.
      expect(shortenPath(path, (_) => false), '~/…/setDING');
    });

    test('absolute and Windows paths', () {
      expect(
        shortenPath('/mnt/usb/Backups/setDING', (t) => shorterThan(15, t)),
        '/…/setDING',
      );
      expect(
        shortenPath(r'C:\Users\me\Backups\setDING', (t) => shorterThan(22, t)),
        r'C:\…\Backups\setDING',
      );
    });

    test('too few parts to shorten', () {
      expect(shortenPath('~/setDING', (_) => false), '~/setDING');
      expect(shortenPath('setDING', (_) => false), 'setDING');
    });
  });

  testWidgets('a long path keeps its folder in a narrow place', (tester) async {
    const path = '~/Nextcloud/Music/Rehearsals/Backups/setDING-Test-Backup';
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, child: FolderPathText(path)),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text)).data!;
    expect(text, isNot(path));
    expect(text, startsWith('~/…/'));
    expect(text, endsWith('/setDING-Test-Backup'));
  });
}
