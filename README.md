# Personal Website

This my personal website source code powered by [GoHugo](https://gohugo.io/).

## Build

Use `docker compose` for building and serving. Available targets are:

- `build`: For building the static website that outputs will be at `public` directory.
- `server`: Uses `hugo`'s internal web server. and port `1313` will be exposed on host. (Available at `localhost:1313`)
- `nginx`: Uses `nginx` official image and binds the `public` directory for `nginx` to serve. (Available at `localhost:80`)

```bash
# Setup the containers
docker compose up <optional target> -d

# Clean up the containers
docker compose down
```