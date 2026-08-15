# Local RTMP test server

This `docker-compose.yml` runs [MediaMTX](https://github.com/bluenviron/mediamtx)
(formerly `rtsp-simple-server`), a lightweight media server that accepts RTMP
ingest and re-exposes it over RTMP, HLS, and WebRTC. It's useful for testing
the `example` app without needing a public RTMP endpoint.

## Starting the server

From this directory, run:

```sh
docker compose up -d
```

This starts a container named `mediamtx`, listening on:

| Port        | Protocol       | Purpose                        |
| ----------- | -------------- | ------------------------------- |
| `1935/tcp`  | RTMP           | Stream ingest (what the app publishes to) |
| `8888/tcp`  | HLS            | Playback in a browser/HLS player |
| `8889/tcp`  | WebRTC (HTTP)  | WebRTC playback signaling       |
| `8189/udp`  | WebRTC (media) | WebRTC media transport          |

To stop it:

```sh
docker compose down
```

## Pointing the example app at the server

1. Find the LAN IP address of the machine running the server (not
   `localhost`/`127.0.0.1`, since the app typically runs on a separate device
   or emulator):
   - Linux/macOS: `ip addr` / `ifconfig`
   - Windows: `ipconfig`
2. Run the `example` app (`flutter run` from the `example/` directory).
3. Tap the settings icon to open the streaming URL dialog, and enter:

   ```
   rtmp://<server-lan-ip>/live/your_stream
   ```

   The path after the host (`/live/your_stream`) can be any name; MediaMTX
   creates streams on demand for any path.
4. Start streaming from the app.

## Viewing the stream

- **HLS** (e.g. in a browser or VLC): `http://<server-lan-ip>:8888/live/your_stream/index.m3u8`
- **WebRTC**: open `http://<server-lan-ip>:8889/live/your_stream` in a browser.

## Notes

- If the app and server run on the same machine (e.g. an Android emulator
  next to Docker Desktop), use `10.0.2.2` (Android emulator's alias for the
  host machine) instead of a LAN IP.
- Make sure your firewall allows inbound connections on the ports above from
  the device running the app.
