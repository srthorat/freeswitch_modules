# FreeSWITCH 1.10.x Base Image

Complete FreeSWITCH installation built from source with all standard modules, ready for extension with custom modules.

## Features

✅ **FreeSWITCH 1.10.11** - Latest stable release built from source
✅ **All Standard Modules** - Complete module set compiled and available
✅ **SIP Support** - Full SIP protocol support
✅ **WebRTC Support** - WebSocket and WebRTC enabled
✅ **Event Socket** - fs_cli command-line interface ready
✅ **Pre-configured Extensions** - 1000 and 1001 ready to use
✅ **System Utilities** - ps, netstat, ping, lsof, vim, curl
✅ **Process Management** - Supervisor for reliable service management

## Quick Start

### Build the Image

```bash
./docker-build-base.sh
```

Build time: 30-45 minutes (Intel/AMD), 60-90 minutes (Apple Silicon)

### Run FreeSWITCH

**Option 1: With Supervisor (Recommended)**
```bash
docker run --rm -it --name fs --network host freeswitch-base:1.10.11
```

**Option 2: Direct FreeSWITCH**
```bash
docker run --rm -it --name fs --network host freeswitch-base:1.10.11 freeswitch -nc -nf
```

### Connect with fs_cli

**Terminal 1:**
```bash
docker run --rm -it --name fs --network host freeswitch-base:1.10.11
```

**Terminal 2:**
```bash
docker exec -it fs fs_cli
```

**In fs_cli:**
```
fs_cli> show modules
fs_cli> show registrations
fs_cli> status
```

## Testing Extensions

### Pre-configured Extensions

- **Extension 1000**
  - Username: 1000
  - Password: 1234
  - Domain: Your container IP

- **Extension 1001**
  - Username: 1001
  - Password: 1234
  - Domain: Your container IP

### Register SIP Clients

Use any SIP softphone (e.g., Zoiper, Linphone, MicroSIP):

1. **Server/Domain**: Container IP or localhost (if using --network host)
2. **Username**: 1000 or 1001
3. **Password**: 1234
4. **Port**: 5060

### Test Calling

1. Register extension 1000 on one SIP client
2. Register extension 1001 on another SIP client
3. From 1000, dial `1001` - should ring extension 1001
4. From 1001, dial `1000` - should ring extension 1000

## Network Configuration

### Using Host Network (Recommended for Testing)

```bash
docker run --rm -it --network host freeswitch-base:1.10.11
```

FreeSWITCH will bind to all host ports directly.

### Using Port Mapping

```bash
docker run --rm -it \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -p 5080:5080/tcp \
  -p 5080:5080/udp \
  -p 8021:8021/tcp \
  -p 7443:7443/tcp \
  -p 16384-32768:16384-32768/udp \
  freeswitch-base:1.10.11
```

### Exposed Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 5060-5061 | TCP/UDP | SIP |
| 5080-5081 | TCP/UDP | WebSocket SIP |
| 8021 | TCP | Event Socket (fs_cli) |
| 7443 | TCP | WebRTC |
| 5066 | TCP | WebSocket |
| 16384-32768 | UDP | RTP Media |

## Container Management

### Get a Shell

```bash
docker exec -it fs bash
```

### View FreeSWITCH Logs

```bash
# Live log tail
docker exec -it fs tail -f /usr/local/freeswitch/log/freeswitch.log

# Last 100 lines
docker exec -it fs tail -100 /usr/local/freeswitch/log/freeswitch.log
```

### Check Processes

```bash
docker exec -it fs ps aux
```

### Network Diagnostics

```bash
# Check listening ports
docker exec -it fs netstat -tlnp

# Ping test
docker exec -it fs ping -c 3 8.8.8.8
```

### Restart FreeSWITCH

```bash
# Via fs_cli
docker exec -it fs fs_cli -x "fsctl shutdown restart"

# Or restart container
docker restart fs
```

## Configuration

### Configuration Files Location

```
/usr/local/freeswitch/conf/
├── freeswitch.xml           # Main configuration
├── vars.xml                 # Variables
├── autoload_configs/        # Module configs
│   ├── modules.conf.xml     # Modules to load
│   ├── event_socket.conf.xml
│   ├── sofia.conf.xml       # SIP profiles
│   └── ...
├── directory/               # User directory
│   └── default/
│       ├── 1000.xml         # Extension 1000
│       ├── 1001.xml         # Extension 1001
│       └── ...
├── dialplan/                # Call routing
│   └── default.xml
└── sip_profiles/            # SIP profiles
    ├── internal.xml
    ├── external.xml
    └── ...
```

### Mounting Custom Configuration

```bash
docker run --rm -it \
  -v /path/to/your/conf:/usr/local/freeswitch/conf \
  --network host \
  freeswitch-base:1.10.11
```

### Persisting Data

```bash
docker run --rm -it \
  -v fs-conf:/usr/local/freeswitch/conf \
  -v fs-log:/usr/local/freeswitch/log \
  -v fs-db:/usr/local/freeswitch/db \
  --network host \
  freeswitch-base:1.10.11
```

## Verification Commands

### Check FreeSWITCH Status

```bash
docker exec -it fs fs_cli -x "status"
```

### List Loaded Modules

```bash
docker exec -it fs fs_cli -x "show modules"
```

### Check Registrations

```bash
docker exec -it fs fs_cli -x "show registrations"
```

### Check Active Calls

```bash
docker exec -it fs fs_cli -x "show calls"
```

### Check Channels

```bash
docker exec -it fs fs_cli -x "show channels"
```

## Troubleshooting

### FreeSWITCH Won't Start

```bash
# Check logs
docker exec -it fs tail -100 /usr/local/freeswitch/log/freeswitch.log

# Check if process is running
docker exec -it fs ps aux | grep freeswitch

# Try starting manually
docker exec -it fs freeswitch -nc -nf
```

### Can't Connect with fs_cli

```bash
# Check if event socket is listening
docker exec -it fs netstat -tlnp | grep 8021

# Check event_socket config
docker exec -it fs cat /usr/local/freeswitch/conf/autoload_configs/event_socket.conf.xml
```

### SIP Clients Can't Register

```bash
# Check if SIP port is listening
docker exec -it fs netstat -ulnp | grep 5060

# Check SIP profile status
docker exec -it fs fs_cli -x "sofia status"

# Check for registration errors
docker exec -it fs fs_cli -x "sofia global siptrace on"
```

### No Audio in Calls

```bash
# Check RTP ports
docker exec -it fs netstat -ulnp | grep 16384

# Verify RTP is allowed through firewall/NAT
# Make sure UDP ports 16384-32768 are accessible
```

## Next Steps

### Adding Custom Modules

Once the base image works, you can:

1. Create a new Dockerfile that extends this base image:
   ```dockerfile
   FROM freeswitch-base:1.10.11

   # Add custom module source
   COPY modules/mod_custom /usr/local/src/mod_custom

   # Build and install custom module
   RUN cd /usr/local/src/mod_custom && make && make install

   # Update modules.conf.xml to load custom module
   ```

2. Or use multi-stage builds to compile custom modules alongside FreeSWITCH

### Integration Testing

Test this base image thoroughly before adding custom modules:

- ✅ Verify all standard modules load
- ✅ Test SIP registration (extensions 1000, 1001)
- ✅ Test calling between extensions
- ✅ Test WebRTC connectivity
- ✅ Verify fs_cli works
- ✅ Check all system utilities are available

## Support

For issues with this base image, check:
- FreeSWITCH logs: `/usr/local/freeswitch/log/freeswitch.log`
- Supervisor logs: `/var/log/supervisor/freeswitch.log`
- Container logs: `docker logs fs`
