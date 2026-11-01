# User Documentation

This guide explains how to use and manage the Inception infrastructure. For installation, configuration, and build details, see [DEV_DOC.md](DEV_DOC.md).

## 1. Services provided

The project runs three services, each in its own Docker container:

| Service | What it does |
|---|---|
| `nginx` | Web server and the only public entrypoint. Serves the website over HTTPS using TLS 1.2 and TLS 1.3. |
| `wordpress` | Runs WordPress using PHP-FPM and generates website pages. |
| `mariadb` | Stores WordPress content, users, and settings in a database. |

The services communicate through a private Docker network called `inception`.

Only NGINX exposes a port to the outside: **443 (HTTPS)**.

Website and database files are stored persistently on the host under `/home/yalkhidi/data`.

## 2. Start and stop the project

Run all Makefile commands from the repository root.

| Action | Command | Description |
|---|---|---|
| Start | `make` | Builds images and starts all containers. |
| Build images | `make build` | Creates the data directories and builds the images. |
| Start containers | `make up` | Starts containers in detached mode. |
| Stop | `make down` | Stops and removes containers and the project network. Data is preserved. |
| Clean | `make clean` | Stops containers and removes project images. |
| Full cleanup | `make fclean` | Removes containers, images, named volumes, and persistent data. |
| Rebuild | `make re` | Performs a full cleanup and starts the project again. |

**Warning:** `make fclean` and `make re` permanently delete the WordPress website and MariaDB database stored under `/home/yalkhidi/data`.

Containers use `restart: always`, so Docker automatically attempts to restart them if they stop.

## 3. Access the website and administration panel

### Domain configuration

The domain must point to the IP address of the machine running the project.

For example, add the following entry to `/etc/hosts`:

```text
127.0.0.1 yalkhidi.42.fr
```

Replace the IP address if the browser is accessing the website from another machine.

The domain must match the NGINX configuration and SSL certificate. See `DEV_DOC.md` for domain configuration details.

### Access the website

Open a browser and visit:

- **Website:** `https://yalkhidi.42.fr`
- **Administration panel:** `https://yalkhidi.42.fr/wp-admin`

The project uses a self-signed SSL certificate, so your browser will display a security warning. Select **Advanced** and proceed to the website.

Only HTTPS on port 443 is exposed.

## 4. Locate and manage credentials

Passwords are stored in separate files inside the `secrets/` directory. They are not committed to Git.

### Secret files

| File | Purpose |
|---|---|
| `db_root_password.txt` | MariaDB root password. |
| `db_user_password.txt` | Password of the MariaDB user used by WordPress. |
| `wp_admin_password.txt` | WordPress administrator password. |
| `wp_user_password.txt` | WordPress regular user password. |

### Other configuration

The `srcs/.env` file contains non-sensitive configuration, including:

- Domain name.
- Database name and username.
- WordPress website title.
- WordPress administrator and regular usernames.
- Email addresses.
- Paths to the password secret files.

### Changing passwords

- **MariaDB passwords:** Changing a secret file does not automatically update an existing database. The password must also be changed inside MariaDB, or the database must be reinitialized.
- **WordPress passwords:** Change user passwords through the administration panel under **Users → Profile**, or using WP-CLI.

**Important:**
- Never commit the `secrets/` directory or `srcs/.env`.
- Keep the secret files private.
- A full reset using `make fclean` deletes the database and website data.

## 5. Check that the services are running correctly

### Check container status

```bash
docker ps
```

The three containers (`nginx`, `wordpress`, and `mariadb`) should show a status of `Up`.

To see all containers, including stopped ones:

```bash
docker ps -a
```

### Check service logs

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

To follow logs continuously, add `-f`:

```bash
docker logs -f nginx
```

### Check HTTPS and TLS

```bash
# TLS 1.2 should succeed
openssl s_client -connect yalkhidi.42.fr:443 -tls1_2

# TLS 1.1 should fail
openssl s_client -connect yalkhidi.42.fr:443 -tls1_1
```

The project only enables TLS 1.2 and TLS 1.3.

### Check persistent data

```bash
ls /home/yalkhidi/data
```

You should see:

- `mariadb/` – MariaDB database files.
- `wordpress/` – WordPress website files.

These directories contain data that persists when containers are removed and recreated.
