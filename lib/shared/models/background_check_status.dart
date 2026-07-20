// ---- Onboarding: background check (Step 9, optional) ----
enum BackgroundCheckStatus { notRequested, pending, clear, flagged }

BackgroundCheckStatus backgroundCheckStatusFromServer(String? s) => switch (s) {
      'pending' => BackgroundCheckStatus.pending,
      'clear' => BackgroundCheckStatus.clear,
      'flagged' => BackgroundCheckStatus.flagged,
      _ => BackgroundCheckStatus.notRequested,
    };
