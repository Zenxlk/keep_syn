import 'package:flutter_test/flutter_test.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';

void main() {
  group('SyncControllerState', () {
    test('estado inicial idle', () {
      const state = SyncControllerState.idle();

      expect(state.isIdle, isTrue);
      expect(state.progress, 0);
      expect(state.hasError, isFalse);
    });

    test('copyWith con failure marca hasError', () {
      const state = SyncControllerState.idle();
      final next = state.copyWith(
        status: SyncStatus.failed,
        failure: const SyncFailure(message: 'boom'),
      );

      expect(next.status, SyncStatus.failed);
      expect(next.hasError, isTrue);
      expect(next.failure, isA<SyncFailure>());
    });
  });
}

