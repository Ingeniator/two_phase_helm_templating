CHART_DIR := mychart
RELEASE_NAME := myrelease
ENV ?= dev

.PHONY: template
template:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml

.PHONY: template-debug
template-debug:
	helm template $(RELEASE_NAME) $(CHART_DIR) -f env/$(ENV).yaml --debug

.PHONY: lint
lint:
	helm lint $(CHART_DIR) -f env/$(ENV).yaml
