# MQTT Broker with TLS Support

This project provides a Dockerized Eclipse Mosquitto MQTT broker configured to support both standard MQTT (port 1883) and MQTT over TLS (port 8883).

## Prerequisites

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)
- `openssl` (for generating certificates)

## Project Structure

- `docker-compose.yml`: Defines the Mosquitto service and volume mappings.
- `config/mosquitto.conf`: Main configuration file for listeners and persistence.
- `certs/`: Directory containing SSL/TLS certificates.
- `generate-certs.sh`: Script to generate self-signed certificates.
- `data/`: Persistent storage for MQTT messages.
- `log/`: Broker log files.

## Getting Started

### 1. Generate Certificates

Before starting the broker, you need to generate the TLS certificates. Run the provided script:

```bash
chmod +x generate-certs.sh

# For local testing (defaults to localhost)
./generate-certs.sh

# For a specific domain
./generate-certs.sh mqtt.meshgw.com
```

This creates a CA certificate, a server key, and a signed server certificate in the `certs/` directory.

### 2. Start the Broker

Run the following command to start the broker in the background:

```bash
docker-compose up -d
```

### 3. Verify the Container

Check if the container is running:

```bash
docker ps
```

## Configuration Validation

Before starting or restarting the broker, you can validate the syntax of your configuration files (including `mosquitto.conf`, `passwd`, and `acl`) to ensure there are no errors:

```bash
docker-compose run --rm mqtt-broker mosquitto -c /mosquitto/config/mosquitto.conf --test-config
```

This command will:
1. Parse the configuration file.
2. Check for missing files, syntax errors, or invalid settings.
3. Exit with a success message if everything is valid, or report errors to the console.

**Note:** This is especially useful after adding new users or modifying ACL rules.

## Authentication & ACL

The broker is configured with:
- **Username:** `admin`
- **Password:** `password`
- **ACL:** Access restricted to the topic `msh/TH` only.

## User Management

The broker uses a `passwd` file for authentication and an `acl` file for access control. These are located in the `config/` directory.

### 1. Adding/Updating Users

To add a new user or update an existing user's password, you can use the `mosquitto_passwd` command. Since the configuration files are mounted as **read-only** in the Docker container, you should perform these changes on the host machine.

#### If you have `mosquitto-clients` installed on your host:

```bash
# Add or update a user (you will be prompted for a password)
mosquitto_passwd config/passwd <username>
```

#### Using Docker (if you don't have it installed locally):

Since the `config/` directory is mounted as read-only (`:ro`) in `docker-compose.yml`, you cannot run `mosquitto_passwd` directly inside the container to update the files. Instead, you can run a temporary container to generate the password entry and then manually add it to `config/passwd`, or temporarily remove the `:ro` flag.

**Recommended approach (on host):**
1. Generate the hashed password using Docker:
   ```bash
   docker run --rm eclipse-mosquitto sh -c "mosquitto_passwd -b -c /tmp/passwd <username> <password> && cat /tmp/passwd"
   ```
   *Alternative (using openssl if available locally):*
   ```bash
   echo -n "<username>:" && openssl passwd -6 "<password>"
   ```
2. Copy the resulting line (e.g., `user:$6$...`) and append it to `config/passwd`.

**Note:** After adding or updating a user, you must restart the broker for the changes to take effect:

```bash
docker-compose restart mqtt-broker
```

### 2. Managing Access Control (ACL)

The `config/acl` file defines which topics a user can read from or write to. Since it is mounted as read-only, edit it on your host machine.

**Format:**
```text
user <username>
topic [read|write|readwrite] <topic_name>
```

**Example:**
To allow `newuser` to read and write to `msh/TH/sensors`:
1. Edit `config/acl` on the host:
   ```text
   user newuser
   topic readwrite msh/TH/sensors
   ```
2. Restart the broker:
   ```bash
   docker-compose restart mqtt-broker
   ```

## MQTT Bridging

A bridge allows your local broker to connect to another (remote) broker and exchange messages. This is configured in `config/mosquitto.conf`.

### Example Bridge Configuration

To forward and receive messages, add this to `config/mosquitto.conf`:

```conf
connection my-remote-bridge
address remote-broker-ip-or-host:1883
topic # both 0 local-prefix/ remote-prefix/
remote_username your_username
remote_password your_password
```

- **Topic Pattern:** `#` (all topics)
- **Direction:** `both` (receives and forwards). Use `in` for only receiving and `out` for only forwarding.
- **QoS:** `0` (can be 1 or 2)
- **Prefixes:** (Optional) Add a prefix to avoid topic collisions.

## Testing Connections

If you have `mosquitto-clients` installed locally, you can test the listeners:

### Standard MQTT (Port 1883)

```bash
# Subscribe
mosquitto_sub -h localhost -p 1883 -u admin -P password -t "msh/TH"

# Publish (in another terminal)
mosquitto_pub -h localhost -p 1883 -u admin -P password -t "msh/TH" -m "Hello MQTT"
```

### MQTT over TLS (Port 8883)

```bash
# Subscribe
mosquitto_sub -h localhost -p 8883 -u admin -P password --cafile certs/ca.crt -t "msh/TH"

# Publish (in another terminal)
mosquitto_pub -h localhost -p 8883 -u admin -P password --cafile certs/ca.crt -t "msh/TH" -m "Hello Secure MQTT"
```

### Testing ACL Restriction

Trying to publish to any other topic will be denied:

```bash
mosquitto_pub -h localhost -p 1883 -u admin -P password -t "other/topic" -m "This should fail"
```

## Maintenance

- **Persistence:** MQTT data is persisted in the `./data` directory.
- **Logs:** View logs using `docker-compose logs -f` or by checking `./log/mosquitto.log`.
- **Customizing:** You can modify `config/mosquitto.conf` to add users or change authentication settings.
