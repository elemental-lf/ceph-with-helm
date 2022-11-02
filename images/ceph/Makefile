.PHONY: build
build:
	docker buildx build --load -t elementalnet/`basename $$PWD`:latest .;
	@version=$$(docker inspect -f {{.Config.Labels.version}} elementalnet/`basename $$PWD`:latest); \
	if [ -n "$$version" ]; then \
	  docker tag elementalnet/`basename $$PWD`:latest elementalnet/`basename $$PWD`:$$version; \
	fi

.PHONY: version
version:
	@docker inspect -f {{.Config.Labels.version}} elementalnet/`basename $$PWD`