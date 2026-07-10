import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/first_run_store.dart';

/// First-run persistence — override in tests with an in-memory fake.
final firstRunStoreProvider = Provider<FirstRunStore>(
  (ref) => const FirstRunStore(),
);
