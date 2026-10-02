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