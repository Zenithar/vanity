GOX_OSARCH          ?= "darwin/amd64 linux/amd64 linux/arm freebsd/386 freebsd/amd64 linux/386 windows/386"
GOX_OUTPUT_DIR      ?= bin
GH_ACCESS_TOKEN     ?=
MESSAGE             ?= Latest release.

all: build

build: clean
	@mkdir -p $(GOX_OUTPUT_DIR) && \
	gox -osarch=$(GOX_OSARCH) -output "$(GOX_OUTPUT_DIR)/{{.Dir}}_{{.OS}}_{{.Arch}}" && \
	gzip bin/vanity_darwin_* && \
	gzip bin/vanity_freebsd_* && \
	gzip bin/vanity_linux_* && \
	zip -r bin/vanity_windows_386.zip bin/vanity_windows_386.exe

require-version:
	@if [[ -z "$$VERSION" ]]; then echo "Missing \$$VERSION"; exit 1; fi

require-access-token:
	@if [[ -z "$(GH_ACCESS_TOKEN)" ]]; then echo "Missing \$$GH_ACCESS_TOKEN"; exit 1; fi

release: require-version require-access-token build
	@RESP=$$(curl --silent --data '{ \
		"tag_name": "v$(VERSION)", \
		"name": "v$(VERSION)", \
		"body": "$(MESSAGE)", \
		"target_commitish": "$(git rev-parse --abbrev-ref HEAD)", \
		"draft": false, \
		"prerelease": false \
	}' "https://api.github.com/repos/xiam/vanity/releases?access_token=$(GH_ACCESS_TOKEN)") && \
	\
	UPLOAD_URL_TEMPLATE=$$(echo $$RESP | python -mjson.tool | grep upload_url | awk '{print $$2}' | sed s/,$$//g | sed s/'"'//g) && \
	if [[ -z "$$UPLOAD_URL_TEMPLATE" ]]; then echo $$RESP; exit 1; fi && \
	\
	for ASSET in $$(ls -1 bin/); do \
		UPLOAD_URL=$$(echo $$UPLOAD_URL_TEMPLATE | sed s/"{?name,label}"/"?access_token=$(GH_ACCESS_TOKEN)\&name=$$ASSET"/g) && \
		MIME_TYPE=$$(file --mime-type bin/$$ASSET | awk '{print $$2}') && \
		curl --silent -H "Content-Type: $$MIME_TYPE" --data-binary @bin/$$ASSET $$UPLOAD_URL > /dev/null && \
		echo "-> $$ASSET OK." \
	; done

clean:
	@rm -rf $(GOX_OUTPUT_DIR)

docker:
	docker build -t xiam/vanity .
