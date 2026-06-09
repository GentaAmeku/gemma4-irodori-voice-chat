# Use a thin client with a conversation server

The app will treat desktop and mobile builds as client apps that connect to a conversation server running on an inference PC. This replaces the initial idea that the Tauri process starts and owns a local Python server, because the same client boundary must work for PC and smartphone clients while Gemma4 and voice generation run on a separate machine.
