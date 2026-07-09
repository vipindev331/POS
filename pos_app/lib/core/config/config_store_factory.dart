// Default/stub implementation. Never actually used at runtime — one of the
// platform variants (native/web) always wins via the conditional import in
// config_store.dart. Present only so the import has a fallback to resolve.
import 'config_store.dart';

ConfigStore createConfigStore() =>
    throw UnsupportedError('No ConfigStore implementation for this platform');
