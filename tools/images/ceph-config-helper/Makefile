# For docker build
export DOCKER_BUILDKIT=1

.PHONY: build
build:
	docker build -t elementalnet/`basename $$PWD` .;
	@version=$$(docker inspect -f {{.Config.Labels.version}} elementalnet/`basename $$PWD`); \
		if [ -n "$$version" ]; then \
			docker tag elementalnet/`basename $$PWD`:latest elementalnet/`basename $$PWD`:$$version; \
		fi

.PHONY: push
push:
	@version=$$(docker inspect -f {{.Config.Labels.version}} elementalnet/`basename $$PWD`:latest); \
		if docker inspect --format='{{index .RepoDigests 0}}' elementalnet/$$(basename $$PWD):$$version >/dev/null 2>&1; then \
			echo "no changes"; \
		else \
			docker push elementalnet/`basename $$PWD`; \
		fi

.PHONE: update
update:
	mod up --build