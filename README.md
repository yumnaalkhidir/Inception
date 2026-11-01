*This project has been created as part of the 42 curriculum by yalkhidi.*

# Inception

## Description

**Inception** is a System Administration project whose goal is to build a small, self-contained web infrastructure using **Docker** and **Docker Compose**, entirely inside a virtual machine.

The stack is made of three services, each running in its own dedicated container, built from our own Dockerfiles:

| Service     | Role                                              | Internal port |
|-------------|---------------------------------------------------|---------------|
| `nginx`     | Reverse proxy / only entrypoint, TLSv1.2/1.3 only | 443 (exposed) |
| `wordpress` | WordPress + php-fpm        | 9000          |
| `mariadb`   | MariaDB database           | 3306          |

Supporting resources:

- **Two Docker named volumes**: one for the WordPress database, one for the WordPress website files. Their data lives on the host in `/home/<login>/data`.
- **One user-defined Docker network** connecting the containers.
- **Docker secrets** for confidential values and a **`.env`** file for non-confidential configuration.
- A **Makefile** at the repository root that builds and runs everything through `docker-compose.yml`.

The website is reachable at `https://<login>.42.fr`, which resolves to the local IP of the VM.

### Project structure

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

### Main design choices

- **Operating system:** The virtual machine runs Debian.
- **Base images:** All three containers use `debian:bookworm` as their base image. I chose Debian over Alpine because I am more familiar with it, it has good package support, and it is easier to configure and troubleshoot. Alpine is smaller, but Debian offers broader compatibility.
- **Separate containers:** NGINX, WordPress and MariaDB each run in their own container to keep their responsibilities separate.
- **Data persistence:** Docker named volumes store WordPress files and MariaDB data so they are not lost when containers are removed.
- **Networking:** All containers communicate through one user-defined bridge network using their service names.
- **Security:** Only NGINX exposes port 443. Passwords are stored in Docker secrets, while other configuration is stored in `.env`.
- **HTTPS:** NGINX handles HTTPS using TLS 1.2 and TLS 1.3 with a self-signed certificate.
- **Initialization:** Entrypoint scripts check whether the database and WordPress are already initialized before setting them up. This prevents existing data from being overwritten.
- **Restart policy:** Containers use `restart: always` to restart automatically if they stop.
- **WordPress users:** Two users are created: an administrator and a regular user. The administrator username does not contain `admin` or `administrator`.

### Comparisons

#### Virtual Machines vs Docker

| Virtual Machine | Docker |
|---|---|
| Runs a complete operating system. | Shares the host kernel. |
| Uses a hypervisor. | Uses namespaces and cgroups for isolation. |
| Requires more resources. | Generally lightweight. |
| Takes longer to start. | Starts quickly. |

In this project, Debian runs inside the virtual machine, and Docker runs the three services inside separate containers.

#### Docker Secrets vs Environment Variables

| Docker Secrets | Environment Variables |
|---|---|
| Store sensitive information such as passwords. | Store general configuration such as database names and usernames. |
| Mounted as files under `/run/secrets/`. | Passed as key-value pairs to containers. |

We use Docker secrets for passwords and `.env` for non-sensitive configuration.

#### Docker Network vs Host Network

| Bridge Network | Host Network |
|---|---|
| Containers have their own network. | Container shares the host network. |
| Containers communicate using service names. | Uses the host's network directly. |
| Ports must be published to access services externally. | Ports are directly available through the host network. |

This project uses a user-defined bridge network so containers can communicate privately.

#### Docker Volumes vs Bind Mounts

| Named Volumes | Bind Mounts |
|---|---|
| Managed by Docker. | Directly map a host directory. |
| Referenced by volume name. | Referenced by a host path. |
| Useful for persistent application data. | Useful for sharing files between host and container. |

The subject requires named volumes. We use the `local` driver with `driver_opts` to store the volume data under `/home/<login>/data` on the host.

## Instructions

### Prerequisites

- A Linux virtual machine with `docker` (with the Compose plugin) and `make` installed.
- `sudo` rights (to create `/home/<login>/data` and edit `/etc/hosts`).

### Setup

1. Clone the repository and enter it.
2. Create the secrets (these files are git-ignored):
   ```bash
   mkdir -p secrets
   echo "a_strong_db_password"      > secrets/db_password.txt
   echo "a_strong_root_password"    > secrets/db_root_password.txt
   # credentials.txt: WordPress admin and regular user credentials (see DEV_DOC.md for the format)
   ```
3. Create `srcs/.env` (see `DEV_DOC.md` for the full list of variables). At minimum:
   ```env
   DOMAIN_NAME=<login>.42.fr
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wpuser
   ```
4. Point the domain name to your local IP:
   ```bash
   echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
   ```

### Build and run
**Makefile**

The Makefile is located at the root of the repository and provides commands to build, start, stop, and clean the Docker infrastructure.

| Command | Description |
|---|---|
| `make` or `make all` | Creates the data directories, builds the images, and starts the containers. |
| `make build` | Creates the data directories and builds the Docker images. |
| `make up` | Starts the containers in detached mode. |
| `make down` | Stops and removes the containers. Data is preserved in named volumes. |
| `make clean` | Stops the containers and removes the project's Docker images. |
| `make fclean` | Stops and removes containers, images, volumes, and persistent data. |
| `make re` | Performs a full cleanup and rebuilds the infrastructure. |
Then open `https://<login>.42.fr` in a browser (accept the self-signed certificate warning). The administration panel is at `https://<login>.42.fr/wp-admin`.

For more detail, see:

- [`USER_DOC.md`](USER_DOC.md): how to use and operate the stack.
- [`DEV_DOC.md`](DEV_DOC.md): how to set up, build, and maintain the project.

## Resources

- [Docker Compose](https://docs.docker.com/compose/)
- [Docker Compose Secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker Compose Volumes](https://docs.docker.com/reference/compose-file/volumes/)
- [Nginx SSL Module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Nginx FastCGI Module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [PHP-FPM Configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI – Core Install](https://developer.wordpress.org/cli/commands/core/install/)
- [MariaDB Documentation - MariaDB Server PDF](https://mariadb.com/docs)


- [MariaDB Initialization & Environment Variables](https://mariadb.com/docs/server/server-management/automated-mariadb-deployment-and-administration/docker-and-mariadb/)


### Use of AI

AI tools (Claude and ChatGPT) were used as an assistant, not as a replacement for understanding. Every generated piece was reviewed, tested, and discussed with peers before being kept.

- **Documentation:** drafting the structure of `README.md`, `USER_DOC.md`, and `DEV_DOC.md`, which were then edited and checked against the real project.
- **Explanations:** clarifying concepts (PID 1, php-fpm/FastCGI, named volumes with `driver_opts`, Docker secrets).
- **Debugging:** suggesting hypotheses for errors, which were verified manually.

AI was *not* used to produce the Dockerfiles, entrypoint scripts, or configuration files without being fully understood and rewritten/validated by the authors.