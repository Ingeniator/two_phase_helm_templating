CHART_DIR := mychart
RELEASE_NAME := myrelease
ENV ?= dev

.PHONY: template
template:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml

.PHONY: template-debug
template-debug:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml --debug

.PHONY: package
package:
	rm -rf out
	mkdir -p out
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml > out/manifests.yaml

.PHONY: release
release:
	rm -rf release
	mkdir -p release
	cp -r $(CHART_DIR) release/
	./scripts/hardcode-security.sh release/$(CHART_DIR) $(CHART_DIR)/values_security.yaml
	rm release/$(CHART_DIR)/values_security.yaml
	@if [ -f .releaseignore ]; then \
		cd release/$(CHART_DIR) && \
		while IFS= read -r pattern; do \
			[ -z "$$pattern" ] && continue; \
			case "$$pattern" in \#*) continue;; esac; \
			for f in $$(find . -name "$$pattern" 2>/dev/null); do \
				rm -f "$$f" && echo "Removed (releaseignore): $$f"; \
			done; \
		done < ../../.releaseignore; \
	fi

.PHONY: test
test: package release
	@helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml > /tmp/helm_package.yaml
	@helm template $(RELEASE_NAME) release/$(CHART_DIR) > /tmp/helm_release.yaml
	@echo "=== Diff: package ($(ENV)) vs release (hardcoded) ==="
	@diff /tmp/helm_package.yaml /tmp/helm_release.yaml || true

.PHONY: lint
lint:
	helm lint $(CHART_DIR) -f env/$(ENV).yaml
