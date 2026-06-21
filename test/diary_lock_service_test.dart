import 'package:flutter_test/flutter_test.dart';
import 'package:journal/services/diary_lock_service.dart';

void main() {
  setUp(() {
    DiaryLockService.resetInstanceForTest();
  });

  group('DiaryLockService', () {
    test('hasPin is false before setup', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      expect(await service.hasPin(), isFalse);
    });

    test('setPin stores hash and verifyPin succeeds', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      await service.setPin('1234');

      expect(await service.hasPin(), isTrue);
      expect(await service.verifyPin('1234'), isTrue);
      expect(await service.verifyPin('0000'), isFalse);
    });

    test('changePin updates stored pin', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      await service.setPin('1234');

      expect(await service.changePin('1234', '5678'), isTrue);
      expect(await service.verifyPin('5678'), isTrue);
      expect(await service.verifyPin('1234'), isFalse);
    });

    test('changePin fails with wrong old pin', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      await service.setPin('1234');

      expect(await service.changePin('9999', '5678'), isFalse);
      expect(await service.verifyPin('1234'), isTrue);
    });

    test('verifyPin caches session pin', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      await service.setPin('1234');
      service.resetSession();

      expect(service.hasSessionPin, isFalse);
      expect(await service.verifyPin('1234'), isTrue);
      expect(service.hasSessionPin, isTrue);
      expect(service.sessionPin, '1234');
    });

    test('changePin clears and refreshes session pin', () async {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      await service.setPin('1234');

      expect(await service.changePin('1234', '5678'), isTrue);
      expect(service.sessionPin, '5678');
      expect(service.isUnlockedForSession, isTrue);
    });

    test('session unlock state resets', () {
      final service = DiaryLockService.withStorage(MemoryPinStorage());
      service.markSessionUnlocked();
      expect(service.isUnlockedForSession, isTrue);

      service.resetSession();
      expect(service.isUnlockedForSession, isFalse);
      expect(service.hasSessionPin, isFalse);
    });

    test('isValidPinFormat validates length and digits', () {
      expect(DiaryLockService.isValidPinFormat('123'), isFalse);
      expect(DiaryLockService.isValidPinFormat('1234'), isTrue);
      expect(DiaryLockService.isValidPinFormat('12345'), isFalse);
      expect(DiaryLockService.isValidPinFormat('123456'), isFalse);
      expect(DiaryLockService.isValidPinFormat('12a4'), isFalse);
    });
  });
}
