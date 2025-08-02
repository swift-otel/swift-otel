# If no target is specified, display help
.DEFAULT_GOAL := help

.PHONY: help
help:  # Display this help.
	@-+echo "Run make with one of the following targets:"
	@-+echo
	@-+grep -Eh "^[a-z-]+:.*#" $(abspath $(lastword $(MAKEFILE_LIST))) | sed -E 's/^(.*:)(.*#+)(.*)/  \1 @@@ \3 /' | column -t -s "@@@"

.PHONY: all
all: build examples  # Build swift-otel and example packages.

# Building OTel package
# -----------------------------------------------------------------------------
.PHONY: build
build:  # Build swift-otel package.
	swift build

.PHONY: test
test:  # Run tests for swift-otel package.
	swift test

# Building examples
# -----------------------------------------------------------------------------
EXAMPLES_DIR = Examples
EXAMPLES = $(shell find "$(EXAMPLES_DIR)" -maxdepth 2 -name Package.swift -print0 | xargs -0 dirname)

.PHONY: $(EXAMPLES_DIR)/%.build
$(EXAMPLES_DIR)/%.build:
	swift build --package-path "$(basename $@)"

.PHONY: examples
examples: $(patsubst %,%.build,$(EXAMPLES))  # Build example packages.

# Build protoc plugins
# -----------------------------------------------------------------------------
PROTOC_PLUGINS_BUILD_DIR = $(shell swift build --show-bin-path)
PROTOC_GEN_SWIFT ?= $(PROTOC_PLUGINS_BUILD_DIR)/protoc-gen-swift
PROTOC_GEN_GRPC_SWIFT ?= $(PROTOC_PLUGINS_BUILD_DIR)/protoc-gen-grpc-swift-2

.PHONY: $(PROTOC_GEN_SWIFT)
$(PROTOC_GEN_SWIFT):
	swift build --product $(notdir $@)

.PHONY: $(PROTOC_GEN_GRPC_SWIFT)
$(PROTOC_GEN_GRPC_SWIFT):
	swift build --product $(notdir $@)

# Code generation
# -----------------------------------------------------------------------------
PROTO_ROOT = opentelemetry-proto

OTLP_CORE_SWIFT_ROOT = Sources/OTel/OTLPCore/Generated
OTLP_GRPC_SWIFT_ROOT = Sources/OTel/OTLPCore/Generated

OTLP_CORE_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/common/v1/common.proto
OTLP_CORE_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/resource/v1/resource.proto
OTLP_CORE_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/logs/v1/logs.proto
OTLP_CORE_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/metrics/v1/metrics.proto
OTLP_CORE_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/trace/v1/trace.proto

OTLP_GRPC_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/collector/logs/v1/logs_service.proto
OTLP_GRPC_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/collector/metrics/v1/metrics_service.proto
OTLP_GRPC_PROTOS += $(PROTO_ROOT)/opentelemetry/proto/collector/trace/v1/trace_service.proto

OTLP_CORE_SWIFTS += $(subst $(PROTO_ROOT),$(OTLP_CORE_SWIFT_ROOT),$(OTLP_CORE_PROTOS:.proto=.pb.swift))
OTLP_CORE_SWIFTS += $(subst $(PROTO_ROOT),$(OTLP_CORE_SWIFT_ROOT),$(OTLP_GRPC_PROTOS:.proto=.pb.swift))

OTLP_GRPC_SWIFTS += $(subst $(PROTO_ROOT),$(OTLP_GRPC_SWIFT_ROOT),$(OTLP_GRPC_PROTOS:.proto=.grpc.swift))

$(OTLP_CORE_SWIFTS): $(OTLP_CORE_PROTOS) $(PROTOC_GEN_SWIFT)
	@mkdir -pv $(OTLP_CORE_SWIFT_ROOT)
	protoc $(OTLP_CORE_PROTOS) \
		--proto_path=$(PROTO_ROOT) \
		--plugin=$(PROTOC_GEN_SWIFT) \
		--swift_out=$(OTLP_CORE_SWIFT_ROOT) \
		--swift_opt=Visibility=Package \
		--swift_opt=UseAccessLevelOnImports=true \
		--experimental_allow_proto3_optional
	protoc $(OTLP_GRPC_PROTOS) \
		--proto_path=$(PROTO_ROOT) \
		--plugin=$(PROTOC_GEN_SWIFT) \
		--swift_out=$(OTLP_CORE_SWIFT_ROOT) \
		--swift_opt=Visibility=Package \
		--swift_opt=UseAccessLevelOnImports=true \
		--experimental_allow_proto3_optional

$(OTLP_GRPC_SWIFTS): $(OTLP_GRPC_PROTOS) $(PROTOC_GEN_GRPC_SWIFT)
	@mkdir -pv $(OTLP_GRPC_SWIFT_ROOT)
	protoc $(OTLP_GRPC_PROTOS) \
		--proto_path=$(PROTO_ROOT) \
		--plugin=$(PROTOC_GEN_GRPC_SWIFT) \
		--grpc-swift-2_opt=Visibility=Package \
		--grpc-swift-2_opt=UseAccessLevelOnImports=true \
		--grpc-swift-2_out=Client=true,Server=true:$(OTLP_GRPC_SWIFT_ROOT)

.PHONY: add-trait-guards
add-trait-guards: $(OTLP_CORE_SWIFTS) $(OTLP_GRPC_SWIFTS)
	@for file in $(OTLP_CORE_SWIFTS); do \
		mv "$$file" "$$file.orig"; \
		echo "Adding trait guard to: $$file"; \
		echo "#if !(OTLPHTTP || OTLPGRPC)" >> "$$file"; \
		echo "// Empty when above trait(s) are disabled." >> "$$file"; \
		echo "#else" >> "$$file"; \
		cat "$$file.orig" >> "$$file"; \
		echo "#endif" >> "$$file"; \
		rm "$$file.orig"; \
	done
	@for file in $(OTLP_GRPC_SWIFTS); do \
		mv "$$file" "$$file.orig"; \
		echo "Adding trait guard to: $$file"; \
		echo "#if !OTLPGRPC" >> "$$file"; \
		echo "// Empty when above trait(s) are disabled." >> "$$file"; \
		echo "#else" >> "$$file"; \
		cat "$$file.orig" >> "$$file"; \
		echo "#endif" >> "$$file"; \
		rm "$$file.orig"; \
	done

.PHONY: generate
generate: $(OTLP_CORE_SWIFTS) $(OTLP_GRPC_SWIFTS) add-trait-guards  # Generate Swift files from Protobuf.

.PHONY: delete-generated-code
delete-generated-code:  # Delete all pb.swift and .grpc.swift files.
	@read -p "Delete all *.pb.swift and *.grpc.swift files in Sources/? [y/N]" ans && [ $${ans:-N} = y ]
	find Sources Tests -name *.pb.swift -delete -o -name *.grpc.swift -delete

.PHONY: dump
dump:  # Dump internal variables for debugging the Makefile.
	@$(foreach v, \
		PROTO_ROOT \
		OTLP_CORE_SWIFT_ROOT \
		OTLP_GRPC_SWIFT_ROOT \
		OTLP_CORE_PROTOS \
		OTLP_CORE_SWIFTS \
		OTLP_GRPC_SWIFTS \
	,echo $(v) = $($v);)

# Xcode workspace with examples
# -----------------------------------------------------------------------------
WORKSPACE = swift-otel-workspace.xcworkspace
WORKSPACE_CONTENTS = $(WORKSPACE)/contents.xcworkspacedata

workspace: $(WORKSPACE_CONTENTS)  # Generate and open Xcode workspace including examples.
	open $(WORKSPACE)

define contents_xcworkspacedata
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
	<Group location="container:" name="swift-otel">
		<FileRef location="group:." name="swift-otel"></FileRef>
	</Group>
	<Group location="container:" name="Examples">
	$(foreach example,$(EXAMPLES),<FileRef location="group:$(example)"></FileRef>\n)
	</Group>
	<Group location="container:Benchmarks" name="Benchmarks">
		<FileRef location="group:." name="benchmarks"></FileRef>
	</Group>
	<Group location="container:IntegrationTests" name="IntegrationTests">
		<FileRef location="group:." name="integration-tests"></FileRef>
	</Group>
</Workspace>
endef
export contents_xcworkspacedata

$(WORKSPACE_CONTENTS): Makefile
	rm -rf $(WORKSPACE)
	mkdir -p $(dir $@)
	echo "$$contents_xcworkspacedata" > $@

.DELETE_ON_ERROR:
