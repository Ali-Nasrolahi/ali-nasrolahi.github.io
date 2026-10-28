# Personal Website

This my personal website source code powered by [GoHugo](https://gohugo.io/).

## Build

The Makefile uses `podman compose`. The Hugo image includes Go and Git, so
you do not need to install Hugo or Go on the host.

- `make up` (or `make`): Start the Hugo development server at <http://localhost:1313>
  and nginx at <http://localhost:8080>.
- `make build`: Build the static website into `public/`.
- `make logs`: Follow the container logs.
- `make down`: Stop the containers.
- `make version`: Show the container's Hugo version.
- `make shell`: Open a shell in the running Hugo container.

The nginx service serves `public/`; run `make build` to refresh its content.

To invoke Compose directly:

```bash
# Setup the containers
podman compose up -d

# Clean up the containers
podman compose down
```

## Theme

Blowfish is imported as a [Hugo module](https://blowfish.page/docs/installation/)
in `config/_default/module.toml`. Its version is pinned in `go.mod`, with
checksums in `go.sum`; commit both files to keep local and CI builds consistent.
Cloning this repository does not require Git submodules.

The first build downloads the module and requires network access. Compose keeps
Hugo's module cache in `.hugo_cache/` (ignored by Git) so subsequent builds and
container restarts reuse it.

If Podman inherits a proxy bound to `localhost`, the container cannot reach that
proxy over its default network. Use a proxy address reachable from containers,
or populate the cache using host networking:

```bash
podman run --rm --network host --userns keep-id:uid=1000,gid=1000 \
  -e HUGO_CACHEDIR=/project/.hugo_cache -v "$PWD:/project:z" \
  ghcr.io/gohugoio/hugo:v0.167.0 \
  mod get github.com/nunocoracao/blowfish/v3@v3.9.0
```

The normal Makefile targets can then use the cached module. For updates through
that proxy, use the same command with `mod get -u github.com/nunocoracao/blowfish/v3`.

To update Blowfish within v3:

```bash
make theme-update
make build
```

To select a specific release instead:

```bash
podman compose run --rm main mod get github.com/nunocoracao/blowfish/v3@v3.9.0
```

Review and commit the resulting `go.mod` and `go.sum` changes after checking the site.
