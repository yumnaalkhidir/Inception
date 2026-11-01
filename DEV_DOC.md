# Developer Documentation

This document describes how a developer can set up, build, run, and maintain the Inception project. For end-user operation, see [`USER_DOC.md`](USER_DOC.md).

## 1. Set up the environment from scratch

### Prerequisites

- A Linux **virtual machine** (the project must run inside one).
- `docker` and the `docker compose` program .
- `make` and `git`.
- `sudo` rights (data directory creation, `/etc/hosts`).
- The current user in the `docker` group (or use `sudo` for Docker commands).

Quick check:

```bash
docker --version
docker compose version
make --version
```

### Repository layout

```
.
└── Inception/
    ├── secrets/
    │   ├── db_root_password.txt
    │   ├── db_user_password.txt
    │   ├── wp_admin_password.txt
    │   └── wp_user_password.txt
    ├── srcs/
    │   ├── requirements/
    │   │   ├── mariadb/
    │   │   │   ├── conf/
    │   │   │   │   └── 99-inception.cnf
    │   │   │   ├── tools/
    │   │   │   │   └── init-db.sh
    │   │   │   └── Dockerfile
    │   │   ├── nginx/
    │   │   │   ├── conf/
    │   │   │   │   └── nginx.conf
    │   │   │   └── Dockerfile
    │   │   └── wordpress/
    │   │       ├── conf/
    │   │       │   └── www.conf
    │   │       ├── tools/
    │   │       │   └── entrypoint.sh
    │   │       └── Dockerfile
    │   ├── .env
    │   └── docker-compose.yml
    ├── .gitignore
    ├── DEV_DOC.md
    ├── Makefile
    ├── README.md
    └── USER_DOC.md
```

### Configuration files

**`srcs/.env`** holds non-confidential variables:

### Environment variables (`srcs/.env`)

The `.env` file stores non-sensitive configuration used by Docker Compose and the WordPress setup script.

```
# User configuration
DOMAIN_NAME=yalkhidi.42.fr
WP_TITLE=Inception

# MariaDB configuration
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD_FILE=/run/secrets/db_user_pass
MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_pass
WP_DB_HOST=mariadb:3306

# WordPress administrator
WP_ADMIN_USER=yumnaboss
WP_ADMIN_EMAIL=you@example.com
WP_ADMIN_PASSWORD_FILE=/run/secrets/wp_admin_pass

# WordPress regular user
WP_USER=yumna_editor
WP_USER_EMAIL=editor@example.com
WP_USER_PASSWORD_FILE=/run/secrets/wp_user_pass
```

**Variable descriptions:**

| Variable | Purpose |
|---|---|
| `MYSQL_DATABASE` | Name of the database created for WordPress. |
| `MYSQL_USER` | MariaDB user used by WordPress. |
| `MYSQL_PASSWORD_FILE` | Path to the file containing the database user's password. |
| `MYSQL_ROOT_PASSWORD_FILE` | Path to the file containing the MariaDB root password. |
| `DOMAIN_NAME` | Domain name used to access the website. |
| `WP_DB_HOST` | MariaDB container hostname and port. |
| `WP_TITLE` | Name of the WordPress website. |
| `WP_ADMIN_USER` | WordPress administrator username. Must not contain "admin" in it. |
| `WP_ADMIN_EMAIL` | Administrator email address. |
| `WP_ADMIN_PASSWORD_FILE` | Path to the administrator password secret. |
| `WP_USER` | Regular WordPress username. |
| `WP_USER_EMAIL` | Regular user's email address. |
| `WP_USER_PASSWORD_FILE` | Path to the regular user's password secret. |

**Note:** Passwords are not stored directly in `.env`. Instead, the variables ending in `_FILE` point to Docker secret files mounted inside the containers under `/run/secrets/`.

Update the example domain, usernames, and email addresses according to your configuration. Keep `.env` out of version control if it contains private configuration.


### Docker secrets

The `secrets/` directory stores confidential values, with each password kept in a separate file. Docker mounts these files inside the relevant containers under `/run/secrets/`.

| File | Used by | Purpose |
|---|---|---|
| `db_root_password.txt` | `mariadb` | MariaDB root password. |
| `db_user_password.txt` | `mariadb`, `wordpress` | Password of the MariaDB user (`MYSQL_USER`). |
| `wp_admin_password.txt` | `wordpress` | WordPress administrator password. |
| `wp_user_password.txt` | `wordpress` | WordPress regular user password. |

**Create the secret files:**

```bash
mkdir -p secrets

echo 'change_me_db' > secrets/db_user_password.txt
echo 'change_me_db' > secrets/db_user_password.txt
echo 'change_me_admin' > secrets/wp_admin_password.txt
echo 'change_me_user' > secrets/wp_user_password.txt

chmod 600 secrets/*
```

**Important:**
- Replace the example passwords with your own passwords.
- Never commit secret files to Git.
- The `.env` file contains the paths to these secrets, not the passwords themselves.
- Each container only receives the secrets it needs.
Make sure `.gitignore` contains:

```
secrets/
srcs/.env
```

### Domain name

Map the domain to the local IP:

```bash
echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
```

## 2. Build and launch with the Makefile and Docker Compose

The Makefile provides shortcuts for managing the Docker infrastructure. Docker Compose uses the configuration file in `srcs/`.

| Target | What it does |
|---|---|
| `make` / `make all` | Creates the data directories, builds the images, and starts the containers. |
| `make build` | Creates `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress`, then builds the images. |
| `make up` | Starts the containers in detached mode. |
| `make down` | Stops and removes the containers and project network. Volumes and persistent data are kept. |
| `make clean` | Stops the containers and removes the project's images. |
| `make fclean` | Stops and removes containers, images, named volumes, and persistent data under `/home/<login>/data`. |
| `make re` | Performs a full cleanup and rebuilds the infrastructure. |

**Equivalent Docker Compose commands:**

```bash
# Build images and start containers
cd srcs && docker-compose up -d --build

# Stop and remove containers
cd srcs && docker-compose down

# Stop containers and remove named volumes and images
cd srcs && docker-compose down -v --rmi all
```

### Build details

- **Dockerfiles:** Each service has its own Dockerfile under `srcs/requirements/` (`nginx`, `wordpress`, and `mariadb`).
- **Base image:** All three services use `debian:bookworm`.
- **Image names:** Each image is named after its service using the `image:` key in `docker-compose.yml`.
- **Secrets:** Passwords are not hardcoded in Dockerfiles. They are stored in separate secret files and accessed inside containers through `/run/secrets/`.
- **Entrypoint scripts:** MariaDB and WordPress use entrypoint scripts to initialize their services. The main processes run in the foreground so Docker can manage their lifecycle.
- **Process management:** Each container runs its main service as PID 1. No artificial infinite loops or `tail -f` commands are used to keep containers running.
## 3. Manage containers, networks and volumes

### Containers

Useful commands for checking and managing containers:

```bash
# List running containers
docker ps

# List all containers
docker ps -a

# Show services managed by Docker Compose
cd srcs && docker-compose ps

# Follow container logs
docker logs -f nginx
docker logs -f wordpress
docker logs -f mariadb

# Open a shell inside a container
docker exec -it mariadb sh
docker exec -it wordpress sh
docker exec -it nginx sh

# Restart a container
docker restart mariadb

# Rebuild a specific service without using cache
cd srcs && docker-compose build --no-cache wordpress
```

### Useful checks

**1. Database**

Connect to MariaDB using the root account:

```bash
docker exec -it mariadb mariadb -u root -p
```

Enter the root password from `secrets/db_root_password.txt`.

Useful SQL commands:

```sql
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SHOW COLUMNS FROM wp_users;
SELECT user_login FROM wp_users;
```

**2. HTTPS**

Check the TLS connection:

```bash
openssl s_client -connect yalkhidi.42.fr:443 -tls1_2
```

### Network

Inspect Docker networks:

```bash
# List networks
docker network ls

# Inspect the project network
docker network inspect <network_name>
```

The project uses one user-defined bridge network connecting all three containers.

Services communicate using their service names:

- `mariadb:3306`
- `wordpress:9000`

Only NGINX exposes port 443 to the host.

### Volumes

Inspect Docker volumes:

```bash
# List volumes
docker volume ls

# Inspect a volume
docker volume inspect <volume_name>
```

The project uses two named volumes:

- MariaDB volume: stores database files.
- WordPress volume: stores website files.

Their data is stored on the host under `/home/<login>/data`.

To remove a volume manually:

```bash
docker volume rm <volume_name>
```

The volume must not be in use by a container.

## 4. Where the data is stored and how it persists

The project uses two Docker named volumes to store persistent data. They are defined in `docker-compose.yml` using the `local` driver and `driver_opts` to specify their locations on the host machine.

**Volume configuration:**

```yaml
volumes:
  mariadb:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/<login>/data/mariadb

  wordpress:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/<login>/data/wordpress
```

**Volume locations:**

| Volume | Container mount point | Host location | Content |
|---|---|---|---|
| `mariadb` | `/var/lib/mysql` | `/home/<login>/data/mariadb` | MariaDB database files. |
| `wordpress` | `/var/www/html` | `/home/<login>/data/wordpress` | WordPress website files, including themes, plugins and uploads. |

**Persistence behaviour:**

- Data survives `make down`, container removal, and image rebuilds because it is stored outside the containers.
- Data is deleted by `make fclean` because it removes both named volumes and the host data directories.
- The host directories must exist before starting the containers. The Makefile creates them using `mkdir -p`.
- The MariaDB and WordPress entrypoint scripts check whether their data has already been initialized before performing the initial setup again.
- Both WordPress and NGINX access the `wordpress` volume. NGINX mounts it as read-only (`:ro`) because it only needs to serve website files, while WordPress manages the files.

**Important:** Removing a container does not automatically delete its named volumes. This allows the database and website files to remain available when containers are recreated.