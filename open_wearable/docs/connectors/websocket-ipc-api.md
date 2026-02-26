# WebSocket IPC API

This document describes how to communicate with the OpenWearable WebSocket connector.

## Endpoint

Default endpoint:

- `ws://127.0.0.1:8765/ws`

Notes:

- Host, port, and path are configurable in app settings.
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
  "methods": ["ping", "methods", "..."]
}
```

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
