# WebSocket IPC API

This document describes how to communicate with the OpenWearable WebSocket connector.

## Endpoint

Default endpoint:

- `ws://<device-ip>:8765/ws`

Notes:

- The app binds the websocket server on all IPv4 interfaces and advertises the current device IP for clients on the same network.
- Port and path are configurable in app settings.
- The API is JSON over WebSocket text frames.

## Message Envelopes

Request:

```json
{"id":1,"method":"ping","params":{}}
```

Success response:

```json
{"id":1,"result":{"ok":true}}
```

Error response:

```json
{
  "id": 1,
  "error": {
    "message": "Unknown method: foo",
    "type": "UnsupportedError",
    "stack": "..."
  }
}
```

## Server Events

On connect, the server sends:

```json
{
  "event": "ready",
  "methods": ["ping", "methods", "..."],
  "endpoint": "ws://192.168.1.23:8765/ws"
}
```

`ready.endpoint` may be `null` when the app cannot determine a client-reachable
LAN IP address. The connector still runs in that case.

Other event messages:

- `scan`: broadcast when a device is discovered.
- `connecting`: broadcast when a connect attempt starts.
- `connected`: broadcast when a wearable is connected.
- `stream`: stream subscription data.
- `stream_error`: error for a stream subscription.
- `stream_done`: stream finished.

`stream` event format:

```json
{
  "event": "stream",
  "subscription_id": 1,
  "stream": "sensor_values",
  "device_id": "string",
  "data": {}
}
```

## Top-Level Methods

| Method | Params | Result |
|---|---|---|
| `ping` | `{}` | `{"ok":true}` |
| `methods` | `{}` | `string[]` |
| `has_permissions` | `{}` | `bool` |
| `check_and_request_permissions` | `{}` | `bool` |
| `start_scan` | `{"check_and_request_permissions"?:bool}` | `{"started":true}` |
| `start_scan_async` | `{"check_and_request_permissions"?:bool}` | `{"started":true,"subscription_id":int,"stream":"scan","device_id":"scanner"}` |
| `get_discovered_devices` | `{}` | `DiscoveredDevice[]` |
| `connect` | `{"device_id":string,"connected_via_system"?:bool}` | `WearableSummary` |
| `connect_system_devices` | `{"ignored_device_ids"?:string[]}` | `WearableSummary[]` |
| `list_connected` | `{}` | `WearableSummary[]` |
| `disconnect` | `{"device_id":string}` | `{"disconnected":true}` |
| `store_sound` | `{"sound_id":string,"audio_base64":string,"codec"?:string,"sample_rate"?:int,"num_channels"?:int,"interleaved"?:bool,"buffer_size"?:int}` | `{"sound_id":string,"stored":true,"bytes":int,"config":object}` |
| `play_sound` | `{"sound_id"?:string,"url"?:string,"volume"?:number,"codec"?:string,"sample_rate"?:int,"num_channels"?:int}` | `{"source":"sound_id"\\|"url","playing":true,"config":object,...}` |
| `start_audio_stream` | `{"volume"?:number,"codec"?:string,"sample_rate"?:int,"num_channels"?:int,"interleaved"?:bool,"buffer_size"?:int}` | `{"started":true,"config":object}` |
| `push_audio_stream_chunk` | `{"audio_base64":string}` | `{"queued_bytes":int}` |
| `stop_audio_stream` | `{}` | `{"stopped":true}` |
| `subscribe` | `{"device_id":string,"stream":string,"args"?:object}` | `{"subscription_id":int,"stream":string,"device_id":string}` |
| `unsubscribe` | `{"subscription_id":int}` | `{"subscription_id":int,"cancelled":bool}` |
| `invoke_action` | `{"device_id":string,"action":string,"args"?:object}` | depends on action |

## Action Commands (`invoke_action`)

Current actions:

- `disconnect` (no `args`)
- `synchronize_time`
- `list_sensors`
- `list_sensor_configurations`
- `set_sensor_configuration` with args:
  - `{"configuration_name":string,"value_key":string}`

Examples:

```json
{"id":10,"method":"invoke_action","params":{"device_id":"abc","action":"synchronize_time"}}
```

```json
{"id":11,"method":"invoke_action","params":{"device_id":"abc","action":"set_sensor_configuration","args":{"configuration_name":"Accelerometer","value_key":"100Hz"}}}
```

## Subscribe Streams

Supported values for `subscribe.params.stream`:

- `sensor_values` (requires one of below in `args`)
  - `{"sensor_id":string}` (recommended)
  - `{"sensor_index":int}`
  - `{"sensor_name":string}`
- `sensor_configuration`
- `button_events`
- `battery_percentage`
- `battery_power_status`
- `battery_health_status`
- `battery_energy_status`

Note:

- `scan` is not a direct `subscribe` stream.
- Use `start_scan_async` to receive scan data via `stream` events.

## Audio Playback Over WebSocket

The connector supports two audio modes:

1. Distinct preloaded sounds (store once, play many times)
2. Chunked audio stream playback (headphone-like continuous feed)

### 1) Distinct Preloaded Sounds

Store sound bytes in memory:

```json
{
  "id": 20,
  "method": "store_sound",
  "params": {
    "sound_id": "beep_ok",
    "audio_base64": "<base64-encoded-audio-bytes>"
  }
}
```

Play a stored sound:

```json
{
  "id": 21,
  "method": "play_sound",
  "params": {
    "sound_id": "beep_ok",
    "volume": 1.0
  }
}
```

Play directly from a URL:

```json
{
  "id": 22,
  "method": "play_sound",
  "params": {
    "url": "https://example.com/notification.wav",
    "volume": 1.0
  }
}
```

`play_sound` rules:

- Provide exactly one source: `sound_id` or `url`.
- If both are set, the server returns an error.

### 2) Chunked Audio Stream

Start stream playback mode:

```json
{
  "id": 30,
  "method": "start_audio_stream",
  "params": {
    "volume": 1.0
  }
}
```

Push chunks continuously:

```json
{
  "id": 31,
  "method": "push_audio_stream_chunk",
  "params": {
    "audio_base64": "<base64-encoded-audio-chunk>"
  }
}
```

Stop stream playback:

```json
{
  "id": 32,
  "method": "stop_audio_stream",
  "params": {}
}
```

Notes:

- `audio_base64` must be raw audio file/chunk bytes encoded as Base64.
- Default config when omitted:
  - `codec=defaultCodec`
  - `sample_rate=16000`
  - `num_channels=1`
  - `interleaved=true`
  - `buffer_size=8192`
- PCM stream mode:
  - `codec=pcm16` or `codec=pcmFloat32` enables low-latency feed mode (`startPlayerFromStream`).
  - Other codecs are handled as queued chunk playback.
- Keep chunk sizes moderate to reduce latency and memory pressure.
- Call `start_audio_stream` before first chunk; otherwise the server returns an error.

## Data Shapes

### DiscoveredDevice

```json
{
  "id": "string",
  "name": "string",
  "service_uuids": ["string"],
  "manufacturer_data": [1, 2, 3],
  "rssi": -56
}
```

### WearableSummary

```json
{
  "device_id": "string",
  "name": "string",
  "type": "OpenEarableV2",
  "capabilities": ["SensorManager", "SensorConfigurationManager"]
}
```

### `list_sensors` item

```json
{
  "sensor_id": "accelerometer_0",
  "sensor_index": 0,
  "name": "Accelerometer",
  "chart_title": "Accelerometer",
  "short_chart_title": "ACC",
  "axis_names": ["x", "y", "z"],
  "axis_units": ["m/s²", "m/s²", "m/s²"],
  "timestamp_exponent": -9
}
```

### `list_sensor_configurations` item

```json
{
  "name": "Accelerometer",
  "unit": "Hz",
  "values": [
    {
      "key": "100Hz",
      "frequency_hz": 100,
      "options": ["streamSensorConfigOption"]
    }
  ],
  "off_value": "off"
}
```

## Suggested Workflows

### Scan and connect

1. Call `start_scan` or `start_scan_async`.
2. Use `get_discovered_devices` (or consume stream events from `start_scan_async`).
3. Call `connect` with selected `device_id`.

### Sensor streaming

1. `invoke_action` with `action="list_sensors"`.
2. Pick `sensor_id`.
3. `subscribe` with `stream="sensor_values"` and `args={"sensor_id":"..."}`.
4. `unsubscribe` when done.

### Distinct sound playback

1. `store_sound` with `sound_id` and `audio_base64`.
2. `play_sound` with the same `sound_id`.

### Live audio streaming

1. `start_audio_stream`.
2. Repeatedly call `push_audio_stream_chunk`.
3. `stop_audio_stream` when done.
