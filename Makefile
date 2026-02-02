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

.PHONY: lint
lint:
	helm lint $(CHART_DIR) -f env/$(ENV).yaml
