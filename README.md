# Record and Play Audio with Bluetooth Headset and Media Buttons on iOS

This project implements a reproducible example of how to record and play audio with a Bluetooth headset even if the app is in background.

The difficulty is to receive button presses from the headset, especially the _pause_ command.
With the current implementations the button press is not detected. But these events would be crucial to implement start and stop recording via the buttons presses.

The implementation starts the `AudioEngine`, and therefore the recording, immediately. If audio data is actually processed is managed separately. This allows to initiate the recording even from the background via a headset button press because the recording is already running and only the _virtual_ recording is started. Actually starting the `AudioEngine` when the app is in the background is not possible (see [this StackOverflow answer](https://stackoverflow.com/a/61347295/8170620)).

Because the `AudioEngine` is running all the time, only the _pause_ command could be emitted. But this event is not detected. **The problem here is to find a way to receive this _pause_ command from the headset button.**
