# Douyu danmaku reconnect

Douyu danmaku connections automatically enter the existing reconnect cycle when both initial WebSocket connection attempts fail. Retries use the existing five-second interval and reconnect limit.

The behavior is enabled only for Douyu. Other platforms keep their previous initial-connection behavior.

Leaving the live room stops the danmaku client and cancels any pending reconnect timer.

