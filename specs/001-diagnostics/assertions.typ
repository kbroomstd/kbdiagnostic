= Assertions

== Purpose
Developer-facing helpers that mirror `std.testing.expectXX` style.

== API
- `expectEqualSpan(expected: SourceSpan, actual: SourceSpan) !void`
- `expectEqualLabel(expected: LabeledSpan, actual: LabeledSpan) !void`
- `expectEqualDiagnostic(expected: anytype, actual: anytype) !void`
- `expectOutputContains(actual: []const u8, needle: []const u8) !void`
- `expectJsonField(actual: []const u8, field_name: []const u8) !void`

== Rules
- keep helpers in `assert.zig`
- keep names camelCase
- keep helpers small and dependency-free
- use stable public fields only

