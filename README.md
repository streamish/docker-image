# Music Server

This software indexes music files in one or more folders and provides an API for accessing them.

The goal of this server is to be a multi-client backend that allows existing music smartphone apps to be used without a proprietary NAS, cloud service, and as a lightweight alternative to hosting music libraries in video-streaming software like JellyFin. Each user can exercise their own preference for which smartphone app they want to use.

This software is not "vibe-coded" but has been built in conjunction with GitHub Copilot's code completion functionality.

## Docker Image

This is the official docker image combining [music-server](https://github.com/selfhostmedia/music-server) and [music-webui](https://github.com/selfhostmedia/music-webui).

Internally it builds the `music-server` backend and the `music-webui` frontend and uses Nginx to serve the frontend and proxy the backend.

The SQLite database will be built automatically in the `/data` volume, and the music files will be read from the `/music` and `/library1...10` volumes which can be mounted as read-only.

When the container starts it will automatically create a default administrator account with the username `admin` and password `admin` and a default normal user account with the username `user` and password `user`.  Their libraries can be set up automatically.

You can disable creating the user account and create them as needed in the administration UI.  Control these settings with the following environment variables:

| Variable                  | Default value | Description |
|---------------------------|---------------|---------------------------------------------------------------------|
| `DEFAULT_ADMIN_USERNAME`  | `admin`       | The username for the default administrator account                  |
| `DEFAULT_ADMIN_PASSWORD`  | `admin`       | The password for the default administrator account                  |
| `DEFAULT_ADMIN_ROOT_PATH` |               | Comma-separated list of paths for the default administrator account |
| `DISABLE_DEFAULT_USER`    | `false`       | Set to `true` to disable creating the default normal user account   |
| `DEFAULT_USER_USERNAME`   | `user`        | The username for the default normal user account                    |
| `DEFAULT_USER_PASSWORD`   | `user`        | The password for the default normal user account                    |
| `DEFAULT_USER_ROOT_PATH`  |               | Comma-separated list of paths for the default normal user account   |

You can enable API compatibility:

| Variable                        | Default value | Description |
|---------------------------------|---------------|------------------------------------------------------------------|
| `SYNOLOGY_AUDIOSTATION_ENABLED` |               | Set to `true` to enable Synology Audio Station API compatibility |

You can enable Swagger API interface for the backend APIs:

| Variable                        | Default value | Description |
|---------------------------------|---------------|------------------------------------------------------------------|
| `SWAGGER_ENABLED`               |               | Set to `true` to enable Swagger documentation |

## How to access

Once the container is running you can sign in at:

[http://localhost:8000](http://localhost:8000)

Or access Swagger documentation at:

[http://localhost:8000/swagger](http://localhost:8000/swagger)

If you are accessing over your network you can replace `localhost` with the IP address of the machine running the container.

### Setting up

To build from the main branch:

```bash
$ git clone https://github.com/selfhostmedia/docker-image.git
$ cd docker-image
$ docker build -t music-server .
```

To build a different branch:

```bash
$ git clone https://github.com/selfhostmedia/docker-image.git
$ cd docker-image
$ docker build \
  --build-arg BACKEND_BRANCH=feat/in-development \
  --build-arg FRONTEND_BRANCH=feat/in-development \
  -t music-server .
```

### Running

If your music is in a single location:

```bash
docker run --rm \
  -p 8000:8000 \
  -v /path/to/your/music:/music \
  -v /path/to/your/data:/data \
  -e DEFAULT_ADMIN_USERNAME=admin \
  -e DEFAULT_ADMIN_PASSWORD=admin \
  -e DEFAULT_ADMIN_ROOT_PATH=/music \
  -e DISABLE_DEFAULT_USER=true \
  -e SYNOLOGY_AUDIOSTATION_ENABLED=true \
  music-server
```

You can mount up to 10 additional read-only volumes:

```bash
docker run --rm \
  -p 8000:8000 \
  -v /path/to/your/music:/music:ro \
  -v /path/to/your/library1:/library1:ro \
  -v /path/to/your/library2:/library2:ro \
  -v /path/to/your/library3:/library3:ro \
  -v /path/to/your/library4:/library4:ro \
  -v /path/to/your/library5:/library5:ro \
  -v /path/to/your/library6:/library6:ro \
  -v /path/to/your/library7:/library7:ro \
  -v /path/to/your/library8:/library8:ro \
  -v /path/to/your/library9:/library9:ro \
  -v /path/to/your/library10:/library10:ro \
  music-server
```

### Docker Compose

```yaml
version: "3.9"
services:
  music-server:
    image: music-server
    container_name: music-server
    ports:
      - "8000:8000"
    volumes:
      - /path/to/your/database:/data
      - /path/to/your/music:/music:ro
      - /path/to/your/library1:/library1:ro
      - /path/to/your/library2:/library2:ro
      - /path/to/your/library3:/library3:ro
      - ...
      - /path/to/your/library10:/library10:ro
    environment:
        - DEFAULT_ADMIN_USERNAME=admin
        - DEFAULT_ADMIN_PASSWORD=admin
        - DISABLE_DEFAULT_USER=true
        - SYNOLOGY_AUDIOSTATION_ENABLED=true
    restart: unless-stopped
```
