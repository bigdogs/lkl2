/// Application-wide tunable constants.
///
/// All magic numbers live here so they can be adjusted in one place.
library;

// ---------------------------------------------------------------------------
// File loading – polling intervals
// ---------------------------------------------------------------------------

/// Time threshold before switching from the loading spinner to showing
/// already-loaded data with a progress bar.
const kLoadingAnimationThreshold = Duration(seconds: 1);

/// Polling interval during the first [kLoadingAnimationThreshold] window.
const kFastPollInterval = Duration(milliseconds: 100);

/// Polling interval after the animation threshold has elapsed.
const kSlowPollInterval = Duration(milliseconds: 500);

// ---------------------------------------------------------------------------
// File size limits
// ---------------------------------------------------------------------------

/// Default max file size in bytes (100 MB) — mirrors
/// `libparser::constants::DEFAULT_MAX_FILE_SIZE` on the Rust side.
const kDefaultMaxFileSize = 100 * 1024 * 1024; // 100 MB

/// Medium option exposed in the View menu (800 MB).
const kMaxFileSizeMedium = 800 * 1024 * 1024; // 800 MB

/// Menu-visible options for the max-load-size setting.
/// A `null` value means "unlimited".
const kMaxFileSizeOptions = <({String label, int? value})>[
  (label: '100 MB', value: kDefaultMaxFileSize),
  (label: '800 MB', value: kMaxFileSizeMedium),
  (label: 'Unlimited', value: null),
];

// ---------------------------------------------------------------------------
// Persistence keys (shared_preferences)
// ---------------------------------------------------------------------------

/// Key used to persist the user's chosen max-file-size preference.
const kPrefsKeyMaxFileSize = 'max_file_size';
