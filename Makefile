CHART_DIR := mychart
RELEASE_NAME := myrelease
ENV ?= dev

.PHONY: template template-debug package release test lint

template:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml

template-debug:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml --debug

package:
	rm -rf out
	mkdir -p out
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml > out/manifests.yaml

release:
	rm -rf release
	mkdir -p release
	cp -r $(CHART_DIR) release/
	./scripts/hardcode-security.sh release/$(CHART_DIR) $(CHART_DIR)/values_security.yaml
	rm release/$(CHART_DIR)/values_security.yaml

test: package release
	@helm template $(RELEASE_NAME) release/$(CHART_DIR) > out/release-manifests.yaml
	@echo "=== Diff: package ($(ENV)) vs release (hardcoded) ==="
	@diff out/manifests.yaml out/release-manifests.yaml || true

lint:
	helm lint $(CHART_DIR) -f env/$(ENV).yaml
