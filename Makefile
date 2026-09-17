.PHONY: build-matterix build-labutopia check

MATTERIX_IMAGE ?= isaacsim-vastai-matterix:local
LABUTOPIA_IMAGE ?= isaacsim-vastai-labutopia:local

build-matterix:
	docker build --progress=plain -f docker/matterix/Dockerfile -t $(MATTERIX_IMAGE) .

build-labutopia:
	docker build --progress=plain -f docker/labutopia/Dockerfile -t $(LABUTOPIA_IMAGE) .

check:
	bash -n docker/common/*.sh docker/labutopia/*.sh
	python3 -c "compile(open('docker/common/isaac-usd-smoke.py', encoding='utf-8').read(), 'docker/common/isaac-usd-smoke.py', 'exec')"
	python3 -m json.tool vastai/matterix-template.json >/dev/null
	python3 -m json.tool vastai/labutopia-template.json >/dev/null
	python3 -m json.tool vastai/webrtc-identity-template.json >/dev/null
