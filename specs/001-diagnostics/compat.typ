= Compat

== Std Hooks
Public data types should opt into std hooks where the win is high.

== Serialization
- `Severity` should implement `jsonStringify`
- `SourceSpan` should implement `jsonStringify`
- `LabeledSpan` should implement `jsonStringify`
- handler objects and runtime wrappers should not

== Formatting
- `Severity` should implement `format`
- `SourceSpan` should implement `format`
- `LabeledSpan` should implement `format`
- handler objects and runtime wrappers should not

== Equality
- `Severity` should be `eql`-friendly
- `SourceSpan` should be `eql`-friendly and hashable if cache use appears
- `LabeledSpan` should be `eql`-friendly

== Non-Goals
- no blanket mirror of all std protocols
- no `clone` on cheap value types
- no `hash` on runtime wrappers by default

