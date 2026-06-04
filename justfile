default:
    just --list

build:
    mise exec -- zig build -Doptimize=ReleaseSmall

clean:
    rm -rf zig-out .zig-cache

test:
    mise exec -- zig build test

run *args:
    mise exec -- zig build run -- {{ args }}

format:
    mise exec -- zig fmt src/ ./build.zig ./build.zig.zon examples/

clone-references:
    #!/usr/bin/env sh
    GHQ_ROOT={{ source_directory() }}/.references
    # mise exec -- ghq get codeberg.org/ziglang/zig -b 0.16.x
    mise exec -- ghq get github.com/zkat/miette -b v7.6.0

generate-toml-test-suite:
    mise exec -- zig run tools/generate_TOMLTestSuite.zig

example-showcase mode="graphical":
    #!/usr/bin/env sh
    set -eu
    printf '%s\n' '=== zig-cli ==='
    if [ "{{ mode }}" = "json" ]; then
      (cd examples/diagnostic-showcase/zig-cli && zig build run -- --json)
    else
      (cd examples/diagnostic-showcase/zig-cli && zig build run)
    fi
    printf '\n%s\n' '=== rust-cli ==='
    if [ "{{ mode }}" = "json" ]; then
      (cd examples/diagnostic-showcase/rust-cli && CARGO_NET_OFFLINE=true RUSTFLAGS=-Awarnings cargo run -q -- --json)
    else
      (cd examples/diagnostic-showcase/rust-cli && CARGO_NET_OFFLINE=true RUSTFLAGS=-Awarnings cargo run -q)
    fi

example-showcase-diff mode="graphical":
    #!/usr/bin/env sh
    set -eu
    export TMPDIR=/tmp
    export XDG_RUNTIME_DIR=/tmp

    zig_out="$(mktemp)"
    rust_out="$(mktemp)"
    trap 'rm -f "$zig_out" "$rust_out"' EXIT

    if [ "{{ mode }}" = "json" ]; then
      (cd examples/diagnostic-showcase/zig-cli && zig build run -- --json) > "$zig_out"
      (cd examples/diagnostic-showcase/rust-cli && CARGO_NET_OFFLINE=true RUSTFLAGS=-Awarnings cargo run -q -- --json) > "$rust_out"
    else
      (cd examples/diagnostic-showcase/zig-cli && zig build run) > "$zig_out"
      (cd examples/diagnostic-showcase/rust-cli && CARGO_NET_OFFLINE=true RUSTFLAGS=-Awarnings cargo run -q) > "$rust_out"
    fi

    diff -u \
      --label "zig-cli" "$zig_out" \
      --label "rust-cli" "$rust_out" \
      | delta || true
