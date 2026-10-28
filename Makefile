.PHONY: all shell up down logs build version theme-update

all: up

shell:
	@podman compose exec main sh

up: down
	@podman compose up -d

down:
	@podman compose down

logs:
	@podman compose logs -f

build:
	@podman compose run --rm main --minify

version:
	@podman compose run --rm main version

theme-update:
	@podman compose run --rm main mod get -u github.com/nunocoracao/blowfish/v3
