.PHONY: build-matterix build-labutopia check check-distribution

MATTERIX_IMAGE ?= isaacsim-vastai-matterix:local
LABUTOPIA_IMAGE ?= isaacsim-vastai-labutopia:local
LABUTOPIA_ACCEPT_CC_BY_NC_4_0 ?= N

build-matterix:
	docker build --progress=plain -f docker/matterix/Dockerfile -t $(MATTERIX_IMAGE) .

build-labutopia:
	docker build --progress=plain -f docker/labutopia/Dockerfile \
		--build-arg LABUTOPIA_ACCEPT_CC_BY_NC_4_0=$(LABUTOPIA_ACCEPT_CC_BY_NC_4_0) \
		-t $(LABUTOPIA_IMAGE) .

check: check-distribution
	bash -n docker/common/*.sh docker/labutopia/*.sh vastai/*.sh vm/*.sh vm/isaac-vm
	grep -q -- '--user root' vm/setup.sh
	python3 -c "compile(open('docker/common/isaac-usd-smoke.py', encoding='utf-8').read(), 'docker/common/isaac-usd-smoke.py', 'exec')"
	python3 -m json.tool vastai/matterix-template.json >/dev/null
	python3 -m json.tool vastai/labutopia-template.json >/dev/null
	python3 -m json.tool vastai/webrtc-identity-template.json >/dev/null

check-distribution:
	! grep -R --line-number --fixed-strings 'ghcr.io' README.md vastai .github/workflows
	! grep -R --line-number -E 'packages:[[:space:]]*write|docker/login-action|docker/build-push-action' .github/workflows
	grep -q 'nvcr.io/nvidia/isaac-sim' vastai/matterix-template.json
	grep -q 'nvcr.io/nvidia/isaac-sim' vastai/labutopia-template.json
	test -f LICENSE
	test -f THIRD_PARTY_NOTICES.md
