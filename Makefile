CHART_DIR := mychart
RELEASE_NAME := myrelease

.PHONY: template
template:
	helm template $(RELEASE_NAME) $(CHART_DIR)

.PHONY: template-debug
template-debug:
	helm template $(RELEASE_NAME) $(CHART_DIR) --debug

.PHONY: lint
lint:
	helm lint $(CHART_DIR)
