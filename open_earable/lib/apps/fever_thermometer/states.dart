/// The current state of the app. This determines what appears on the bottom half of the screen.
enum CurrentState {
  /// until initState is completed
  uninitialized,

  /// no reference or measurement is being taken
  idle,

  /// while the reference is set
  referencing,

  /// while the real measuring is running. Reference has to be set
  measuring,
}
