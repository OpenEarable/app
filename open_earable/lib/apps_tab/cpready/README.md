# CPReady

CPReady is an application for the [OpenEarable](https://open-earable.teco.edu).
It helps the user while performing CPR.

## Features
- Measures the frequency with which the user is currently performing CPR.
- Gives feedback according to the current frequency.
- Gives the user audio or visual support for staying within the recommended frequency range.
- Optionally supports mouth-to-mouth resuscitation by prompting the user to do so at the recommended times.

## Audio Support
It is possible to enable audio support.
For this feature to work, an audio file (.wav format) named "frequency.wav" needs to be on the SD card of the earable.
This file needs to contain the metronome sound in the desired frequency.
An exemplary file is provided in the assets folder.
If the prerequisites are met, the audio support can be enabled with a button while doing CPR.

## Visual support
If the audio support is not enabled, there is a visual support shown.
This visual support consists of an animation that shows an CPR procedure with a frequency of 110 bpm.

## Mouth-to-mouth resuscitation
Optionally, the app can prompt the user to do mouth-to-mouth resuscitation.
This is done by showing a pop-up dialogue after every 30 pushes. 