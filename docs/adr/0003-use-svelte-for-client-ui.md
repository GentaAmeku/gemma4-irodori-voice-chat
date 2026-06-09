# Use Svelte for the client UI

The client UI will use Svelte with TypeScript and Vite instead of htmx. The app needs substantial local state and browser API control for microphone input, audio playback, WebSocket audio streaming, cancellation, and settings panels, so a lightweight reactive UI framework fits the product better than HTML-fragment swapping.
