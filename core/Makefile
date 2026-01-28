# TakeHome Core - Build Commands

.PHONY: build test bench clean ios android wasm bindings

# Default target
all: build test

# Build library
build:
	cargo build --release

# Run tests
test:
	cargo test

# Run tests with output
test-verbose:
	cargo test -- --nocapture

# Run benchmarks
bench:
	cargo bench

# Check code without building
check:
	cargo check

# Format code
fmt:
	cargo fmt

# Lint code
lint:
	cargo clippy -- -D warnings

# Clean build artifacts
clean:
	cargo clean

# Build for iOS (both device and simulator)
ios: ios-device ios-sim

ios-device:
	cargo build --release --target aarch64-apple-ios

ios-sim:
	cargo build --release --target aarch64-apple-ios-sim

# Generate Swift bindings
bindings-swift:
	cargo run --bin uniffi-bindgen generate \
		--library target/release/libtakehome_core.dylib \
		--language swift \
		--out-dir ../bindings/swift

# Create XCFramework for iOS
xcframework: ios
	@mkdir -p ../bindings/swift
	xcodebuild -create-xcframework \
		-library target/aarch64-apple-ios/release/libtakehome_core.a \
		-headers ../bindings/swift/TakeHomeCoreFFI.h \
		-library target/aarch64-apple-ios-sim/release/libtakehome_core.a \
		-headers ../bindings/swift/TakeHomeCoreFFI.h \
		-output ../bindings/TakeHomeCore.xcframework

# Build for WebAssembly
wasm:
	cargo build --release --target wasm32-unknown-unknown --features wasm

# Build for Android
android:
	cargo build --release --target aarch64-linux-android
	cargo build --release --target armv7-linux-androideabi
	cargo build --release --target x86_64-linux-android
	cargo build --release --target i686-linux-android

# Generate all bindings
bindings: bindings-swift
	@echo "Bindings generated in ../bindings/"

# Install required targets
setup:
	rustup target add aarch64-apple-ios
	rustup target add aarch64-apple-ios-sim
	rustup target add wasm32-unknown-unknown
	rustup target add aarch64-linux-android
	rustup target add armv7-linux-androideabi
	rustup target add x86_64-linux-android
	rustup target add i686-linux-android
	cargo install uniffi_bindgen

# Show help
help:
	@echo "Available targets:"
	@echo "  build          - Build release library"
	@echo "  test           - Run tests"
	@echo "  bench          - Run benchmarks"
	@echo "  ios            - Build for iOS (device + simulator)"
	@echo "  bindings-swift - Generate Swift bindings"
	@echo "  xcframework    - Create XCFramework for iOS"
	@echo "  wasm           - Build for WebAssembly"
	@echo "  android        - Build for Android"
	@echo "  setup          - Install required Rust targets"
	@echo "  clean          - Clean build artifacts"
