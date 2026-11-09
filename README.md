# MeshCore Open

Open-source Flutter client for MeshCore LoRa mesh networking devices.

This build tracks the [OverkillFPV fork](https://github.com/OverkillFPV/meshcore-open) of upstream [zjs81/meshcore-open](https://github.com/zjs81/meshcore-open). All changes listed below are on top of upstream `dev`.

## Changes over upstream

### Neighbors map & location

- Repeater neighbors screen with List/Map tabs: map draws the logged-in repeater and positioned neighbors with SNR-colored link lines labeled with distance, SNR, and last-heard time ([57d74fb1](https://github.com/OverkillFPV/meshcore-open/commit/57d74fb1))
- Toolbar actions to send `discover.neighbors` (zero-hop discovery from the repeater) and erase the whole neighbor list via `neighbor.remove`
- Map-based location picker for repeater settings (pick lat/lon directly on the map)
- Neighbors fetched-count notice in map view ([c19373f0](https://github.com/OverkillFPV/meshcore-open/commit/c19373f0))
- Neighbor discovery and page fetches now handle timeouts with limited retries and clear error reporting ([4d89d9ca](https://github.com/OverkillFPV/meshcore-open/commit/4d89d9ca), [be9cf488](https://github.com/OverkillFPV/meshcore-open/commit/be9cf488))
- Advanced path hop resolution: ambiguous hops resolved by shortest distance, hops over 200 km rejected when alternatives exist, user-forced selection supported, unknown hop prefixes resolved via the network map API ([3b6821c4](https://github.com/OverkillFPV/meshcore-open/commit/3b6821c4))

### Companion CLI & mentions

- Companion CLI screen to run local CLI commands on the connected radio (firmware v14+) ([e983841c](https://github.com/OverkillFPV/meshcore-open/commit/e983841c))
- `@mention` support in chat with suggestion picker ([e983841c](https://github.com/OverkillFPV/meshcore-open/commit/e983841c))
- Pulsing animation for self-mentions with an initial attention flash, respecting reduced-motion settings ([df3ebe38](https://github.com/OverkillFPV/meshcore-open/commit/df3ebe38))

### RX log

- Dedicated RX packet viewer decoding every LoRa packet the radio has seen, accessible from channels, contacts, and channel chats ([9c47630e](https://github.com/OverkillFPV/meshcore-open/commit/9c47630e))
- Decoded sender and destination prefixes for direct and advert packets ([08735253](https://github.com/OverkillFPV/meshcore-open/commit/08735253))
- SNR/RSSI indicators colour-coded across the app against LoRa operating limits (green/amber/red bands)
- "Set path…" routing mode in the repeater login dialog opening the path editor directly

### Signal & telemetry

- RSSI/SNR reporting for received messages with color-coded quality indicators ([e983841c](https://github.com/OverkillFPV/meshcore-open/commit/e983841c))
- Strongest-signal merging: SNR/RSSI shown for messages and echoed (sent) messages always come from the single strongest heard copy, never split across copies ([31b32942](https://github.com/OverkillFPV/meshcore-open/commit/31b32942), [13a321df](https://github.com/OverkillFPV/meshcore-open/commit/13a321df))
- Advert metadata tracking: advert hops, scope, and local receipt time shown in contact details ([3761fff5](https://github.com/OverkillFPV/meshcore-open/commit/3761fff5))
- Wider RSSI color gradient down to −140 dBm ([3761fff5](https://github.com/OverkillFPV/meshcore-open/commit/3761fff5))
- Telemetry shows computed power alongside voltage and current; battery voltage to three decimals; durations include days ([72b980b4](https://github.com/OverkillFPV/meshcore-open/commit/72b980b4))
- Pack voltage cell estimates and expanded repeater stats; heard repeaters highlighted in the path view ([35265314](https://github.com/OverkillFPV/meshcore-open/commit/35265314))

### Messaging

- Region and latency metadata improvements: `unscoped` and `unsynced` labels for messages lacking region or time-sync data ([55cb47b8](https://github.com/OverkillFPV/meshcore-open/commit/55cb47b8))
- Unsynced-clock latency threshold raised so high-latency messages are not falsely flagged ([e1e0ce7e](https://github.com/OverkillFPV/meshcore-open/commit/e1e0ce7e))
- Hashtag support: tapping a hashtag offers to add it as a new channel; existing channels open directly ([5b882905](https://github.com/OverkillFPV/meshcore-open/commit/5b882905), [c85b0f1e](https://github.com/OverkillFPV/meshcore-open/commit/c85b0f1e))
- Message resend for 1:1 and channel messages preserving original timestamps ([5b882905](https://github.com/OverkillFPV/meshcore-open/commit/5b882905))
- Mention parsing fixed for multi-mention posts ([5b882905](https://github.com/OverkillFPV/meshcore-open/commit/5b882905))

### Repeater management

- Access Control List (ACL) screen managing companions allowed to log in to a repeater, with Guest/Read-only/Read-write/Admin roles ([c85b0f1e](https://github.com/OverkillFPV/meshcore-open/commit/c85b0f1e))
- Repeater CLI with command copying and resend actions; CLI retry count increased to 3 ([c85b0f1e](https://github.com/OverkillFPV/meshcore-open/commit/c85b0f1e))

### Contacts

- Network summary chips on the contacts screen: total nodes, companions, repeaters, active, and inactive counts ([81c54bb5](https://github.com/OverkillFPV/meshcore-open/commit/81c54bb5))

### Backup & data

- Data backup and import: export/restore app settings and data to/from a file ([5b882905](https://github.com/OverkillFPV/meshcore-open/commit/5b882905))
- Connected device settings can be included in backups, handled separately from app preferences ([3761fff5](https://github.com/OverkillFPV/meshcore-open/commit/3761fff5))

### Map

- Satellite map tiles (Esri World Imagery) ([e983841c](https://github.com/OverkillFPV/meshcore-open/commit/e983841c))
- Packet path polylines snap to cluster centers when nodes are grouped ([55cb47b8](https://github.com/OverkillFPV/meshcore-open/commit/55cb47b8))
- Removed the live packet animation layer and its setting ([f7643c61](https://github.com/OverkillFPV/meshcore-open/commit/f7643c61))

### Localization

- Extensive localization updates across all supported languages for the new features listed above

### Internal

- Removed the APK auto-build GitHub Actions workflow ([c420cd95](https://github.com/OverkillFPV/meshcore-open/commit/c420cd95))

## License

MeshCore Open is available under the [MIT License](LICENSE).
