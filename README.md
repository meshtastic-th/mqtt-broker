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

You have two options for generating certificates:

#### Option A: Self-Signed Certificates (Local/Testing)

For local testing (defaults to `localhost`):

```bash
chmod +x generate-certs.sh
./generate-certs.sh mqtt.meshgw.com
```

#### Option B: Certbot (Public Domain with Let's Encrypt)

If you have a public domain and want a trusted certificate, use Certbot.

1.  **Generate Certificate:**
    Ensure port 80 is open on your host or use your preferred Certbot method.
    ```bash
    sudo certbot certonly --standalone -d mqtt.yourdomain.com
    ```
2.  **Copy and Configure:**
    Run the provided script to copy the certificates into the project's `certs/` directory:
    ```bash
    chmod +x use-certbot.sh
    ./use-certbot.sh mqtt.yourdomain.com
    ```

3.  **Renewal (Manual or Automated):**
    When the certificate is renewed by Certbot, you must re-copy the files and restart the broker.
    **Manual:**
    ```bash
    ./use-certbot.sh mqtt.yourdomain.com
    docker-compose restart mqtt-broker
    ```
    **Automated Renewal Hook:**
    Add a post-renewal hook to your Certbot configuration:
    ```bash
    # Test renewal with hook
    sudo certbot renew --dry-run --post-hook "cd $(pwd) && ./use-certbot.sh mqtt.yourdomain.com && docker-compose restart mqtt-broker"
    ```

**Note:** The script automatically adds **Subject Alternative Names (SAN)** for both DNS and IP (in self-signed mode), which is required by modern MQTT clients and browsers for strict certificate validation. Ensure the argument you pass matches the address you will use to connect.

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

## TLS/SSL Trust Note

If you receive a **"self signed certificate in certificate chain"** error, it is because your client does not trust the CA certificate you generated.

1.  **Always provide the CA file:** In command-line tools, use `--cafile certs/ca.crt`.
2.  **Hostname Matching:** The hostname you use to connect MUST match the **Common Name (CN)** you provided when running `./generate-certs.sh`. If you connect via IP but generated the cert for `localhost`, the verification will fail.
3.  **Insecure Mode (Development Only):** If you cannot provide a CA file, some clients allow an "insecure" or "allow unauthorized" mode, but this is not recommended for production.

## Maintenance

- **Persistence:** MQTT data is persisted in the `./data` directory.
- **Logs:** View logs using `docker-compose logs -f` or by checking `./log/mosquitto.log`.
- **Customizing:** You can modify `config/mosquitto.conf` to add users or change authentication settings.

## Troubleshooting

### Permission Denied Errors

If you see errors like `Permission denied`, `Unable to open log file`, or `Error: Unable to load server key file` in the Docker logs (`docker-compose logs`), it is because the Mosquitto process (running as UID 1883) does not have permission to access the host directories.

To fix this, run the following command on your host:

```bash
sudo chown -R 1883:1883 certs/ data/ log/
docker-compose restart mqtt-broker
```

This ensures the container's internal user can read the SSL certificates and write to the persistence and log folders.

