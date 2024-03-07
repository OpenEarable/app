# Guided Neck Stretch App

## Goal
This App is used to allow users to easily start a stretching exercise for their neck without a lot of trouble. To ensure that the user doesn't have to look at the screen while enjoying their stretching session, it also has a stats tab which displays valuable information to be viewed after they just stretched. Furthermore the app signals to the user whenever the next stretching session starts and when a break is occuring, so that the user can stay calm and close his eyes without focusing on his own set time constraints.
To ensure a more intimate experience the user can also set his own threshold goals and stretching duration for each of the stretch exercises, and modify the break times in between. If a user is new or unsure how to use this app or to execute the stretch exercises in the right manner, a guide tab is provided to help the user understand the app and it's UI and to show them a video regarding the used stretch exercises.  

## Assets
The assets are modified images from the posture tracker app to ensure consistency within the OpenEarable app. These images always display the stretched area with a blue indicator color.
- `Neck_Stretch_Left.png`: Image displaying the neck with indicators of a "left stretch".
- `Neck_Main_Stretch.png`: Image displaying the neck with indicators of a "main stretch".
- `Neck_Right_Stretch.png`: Image displaying the neck with indicators of a "right stretch".
- `Neck_Side_Stretch.png`: Image displaying the neck with indicators of a stretch of both sides of the neck.

## Model
### Stretch Colors
This file stores all colors used within the stretch app to assure easy exchangeability and consistency within this app.

### Stretch State
This file stores all classes used to store stretching information, such as 
- `NeckStretchState`: Stores all data concerning a stretching state and it's asset paths
- `StretchStats`: Stores all data concering the most recent stretching session
- `StretchSettings`: Stores all data needed to configure a stretching session
- `NeckStretch`: Provides a one class solution which compromises all of the Model Data into this Class. It provides all functions needed to get and modify the data and also has all the code concerning the stretch state switches.

## View

### App View
This file consiststs of the module used to display all the submodules of this app and is built up just like the normal app selector in the open-earable app itself. Notable is that this is a stateful widget which initializes the final `StretchViewModel` object which is used to store and manage all data needed for this app.

### Stretch Arc Painter
This is a modified version of the `arc_painter` used in the `posture_tracker` app, which draws the right indicators with the right colors from the `stretch_colors.dart` to indicate whether the user is currently stretching in the right direction and to display what area is desireable or undesireable for the current stretch.

### Stretch Roll View
This is a modified version of the `roll_view` used in the `posture_tracker` app, which is used to draw the whole "head area" of a tracking session. This file is edited to support the different neck stretch types and draw the arcs according to them.

### Stretch Settings View
This is the view used to display the settings module and edit all the settings for a neck stretching session. It uses the `TextEditingController` to parse any input by the user, which is then used to set the right settings in the `StretchViewModel` for a stretching exercise.

### Stretch Stats View
This is the view used to display the stats of the most recent stretching exercise. These stats are stored and editied by the `StretchViewModel`.

### Stretch Tracker View
This module is the view of the stretch tracker module. Here you can start stretching and can track your stretching progess via the UI. The UI is drawn using an modified version of the `posture arc_painter.dart`, the `stretch_arc_painter.dart`. This view also provides certain functions to easily draw the head tracker view in other modules.

### Stretch Tutorial View
This is the view for the stretch tutorial module, which is used to show the user how to use this app, and has an embedded youtube video (using an [youtube player package](https://pub.dev/packages/youtube_player_flutter)), which shows all of the neck stretches used by this app.

## View Model
### Stretch View Model
This file stores the `StretchViewModel`, which stores all data used by this app and is used to change it on the fly by the submodules. It also provides the functionality to track the stats of the user for the Stretch Stats View. Furthermore it is used to stop and start the tracking by the earable.

---
By Soheel Dario Aghadavoodi Jolfaei - [GitHub](https://github.com/BasicallyPolaris/oe-app)