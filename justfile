default:
  just --list

build:
  mise exec -- zig build -Doptimize=ReleaseSmall

clean:
  rm -rf zig-out .zig-cache

test:
  mise exec -- zig build test

run *args:
  mise exec -- zig build run -- {{args}}

format:
  mise exec -- zig fmt src/ ./build.zig ./build.zig.zon

clone-references:
  #!/usr/bin/env sh
  GHQ_ROOT={{source_directory()}}/.references
  mise exec -- ghq get codeberg.org/ziglang/zig -b 0.16.x
  mise exec -- ghq get github.com/zkat/miette v7.6.0 -b v7.6.0

generate-toml-test-suite:
  mise exec -- zig run tools/generate_TOMLTestSuite.zig

