// enum for choosing the setup in the configuration window
enum Setup {
  sitting,
  standing;
}

// enum of the values that can be selected by the user for hours awake
// rough approximation from: Wright KP Jr, Hull JT, Czeisler CA. Relationship between alertness, performance, and body temperature in humans., 2002, Fig 2
// matched the hours awake to rough percentage of full temperature based performance potential

enum HoursAwake {
  two(0.25),
  four(1.0),
  six(0.15),
  eight(0.2),
  ten(0.175),
  twelve(0.25),
  fourteen(0.0),
  sixteen(0.225);

  const HoursAwake(this.percentageOfMax);
  final double percentageOfMax;
}
