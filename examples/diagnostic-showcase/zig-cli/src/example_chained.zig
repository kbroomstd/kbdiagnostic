const diagnostic = @import("kbdiagnostic");
const span = @import("kbdiagnostic").span;
const source = @import("kbdiagnostic").source;

const Node = struct {
    message: []const u8,
    code: ?[]const u8,
    severity: ?diagnostic.Severity,
    help: ?[]const u8,
    url: ?[]const u8,
    source_code: ?source.SourceCode,
    labels: []const span.LabeledSpan,
    related: ?[]const diagnostic.Diagnostic,
    diag_source: ?*const diagnostic.Diagnostic,

fn implBy(self: *const Node) diagnostic.Diagnostic {
    return .{ .ptr = self, .vtable = &VTable };
}

    fn codeFn(ptr: *const anyopaque) ?[]const u8 {
        return node(ptr).code;
    }
    fn severityFn(ptr: *const anyopaque) ?diagnostic.Severity {
        return node(ptr).severity;
    }
    fn helpFn(ptr: *const anyopaque) ?[]const u8 {
        return node(ptr).help;
    }
    fn urlFn(ptr: *const anyopaque) ?[]const u8 {
        return node(ptr).url;
    }
    fn sourceCodeFn(ptr: *const anyopaque) ?*const source.SourceCode {
        const n = node(ptr);
        if (n.source_code) |*sc| return sc;
        return null;
    }
    fn labelsFn(ptr: *const anyopaque) ?[]const span.LabeledSpan {
        const n = node(ptr);
        return if (n.labels.len > 0) n.labels else null;
    }
    fn relatedFn(ptr: *const anyopaque) ?[]const diagnostic.Diagnostic {
        return node(ptr).related;
    }
    fn diagnosticSourceFn(ptr: *const anyopaque) ?*const diagnostic.Diagnostic {
        return node(ptr).diag_source;
    }
    fn messageFn(ptr: *const anyopaque) []const u8 {
        return node(ptr).message;
    }

    fn node(ptr: *const anyopaque) *const Node {
        return @ptrCast(@alignCast(ptr));
    }

    const VTable = diagnostic.Diagnostic.VTable{
        .code = codeFn,
        .severity = severityFn,
        .help = helpFn,
        .url = urlFn,
        .sourceCode = sourceCodeFn,
        .labels = labelsFn,
        .related = relatedFn,
        .diagnosticSource = diagnosticSourceFn,
        .message = messageFn,
    };
};

const NodeDesc = struct {
    message: []const u8,
    code: ?[]const u8 = null,
    severity: ?diagnostic.Severity = null,
    help: ?[]const u8 = null,
    url: ?[]const u8 = null,
    source_idx: ?usize = null,
    labels: []const span.LabeledSpan = &.{},
    related_idxs: []const usize = &.{},
    diag_source_idx: ?usize = null,
};

fn prim(text: []const u8, offset: usize, len: usize) span.LabeledSpan {
    return span.LabeledSpan.newPrimary(text, offset, len);
}
fn sec(text: []const u8, offset: usize, len: usize) span.LabeledSpan {
    return span.LabeledSpan.new(text, offset, len);
}

const DESCS = [_]NodeDesc{
    // 00: standalone — no chain
    .{
        .message = "standalone diagnostic with no chain",
        .code = "S000",
        .severity = .Advice,
        .help = "everything is fine",
    },
    // 01: single related sibling
    .{
        .message = "single related sibling",
        .code = "C001",
        .severity = .Error,
        .help = "check the sibling diagnostic for context",
        .related_idxs = &.{0},
    },
    // 02: multiple related siblings (3, with repetition)
    .{
        .message = "multiple related siblings",
        .code = "C002",
        .severity = .Warning,
        .help = "all siblings must be resolved",
        .related_idxs = &.{ 0, 1, 0 },
    },
    // 03: causal chain depth 2 — source is d00
    .{
        .message = "causal chain depth 2 (d03 → d00)",
        .code = "C003",
        .severity = .Error,
        .help = "root cause is the standalone diagnostic",
        .source_idx = 2,
        .labels = &.{prim("ROW_NUMBER", 68, 10)},
        .diag_source_idx = 0,
    },
    // 04: causal chain depth 4 — d04 → d09 → d02 → d00
    // d09 is the "nested inner" which has diag_source=d01 (wait no, d09 doesn't have diag_source)
    // Let me re-think: d04.diag_source->d07, d07.diag_source->d02, d02.diag_source->d00

    // Actually, I realize d02 has no diag_source. Let me use a different chain.
    // d04.diag_source = d06, d06.diag_source = d10, d10.diag_source = d00
    // But d06 doesn't have diag_source either.

    // Let me define separate "chain node" that only serves as causal link:
    // d04.diag_source = d15, d15.diag_source = d16, d16.diag_source = d00
    // where d15 and d16 are "sub-label" nodes with diag_source set.

    // UPDATE: reordering. Let me use d03 (index 3) as second link and d00 as first.
    // d04.diag_source = &d03, d03.diag_source = &d00
    // That's depth 3 (d04→d03→d00). For depth 4 need one more: d04→d07→d03→d00

    // But d07 doesn't exist yet. Let me just do d04 → d03 → d00 (depth 3 shown as causal chain depth 3),
    // and rename the message.

    // No, I'll restructure the indices. Let me just define them carefully:
    // d04.diag_source = d03, d03.diag_source = d00 → depth 3
    // For depth 4: I'll use d05.diag_source = d04, d04.diag_source = d03, d03.diag_source = d00

    // But d05 has already been assigned a different meaning ("related with source labels").
    // I need to reorder. Let me reassign the entire set.

    // FINAL REORDERING (committing to this):
    // 00: standalone
    // 01: single related [00]
    // 02: multi related [00,01,00]
    // 03: causal-2: diag_source=00, src=query.sql
    // 04: causal-4: diag_source=03→00 (depth 3, renamed to "causal chain depth 3")
    // 05: causal-5: diag_source=04→03→00 (depth 4, renamed to "causal chain depth 4")
    // 06: related+w/labels: related=[00,02], src=template.tera
    // 07: causal+w/labels: diag_source=01, src=config.yaml
    // 08: both chains: diag_source=00, related=[02,03], src=handler.go
    // 09: nested related: related=[10]; 10→related=[00]
    // 10: nested inner: related=[00]
    // 11: causal+related+labels: diag_source=09, related=[02,04], src=template.tera
    // 12: diamond: diag_source=02, related=[03,04], src=pipeline.py
    // 13: cross-file: related=[00,07,03,10,12] (no own labels, spans via related whose labels cover 5 files)
    // 14: sub-labels: related=[15,16]
    // 15: sub-a: src=handler.go, labels=[PingContext]
    // 16: sub-b: src=handler.go, labels=[database not connected]
    // 17: fan-out: diag_source=11, related=[07,18,19], src=config.yaml
    // 18: fan-sub-a: diag_source=01, src=handler.go
    // 19: fan-sub-b: diag_source=02, src=pipeline.py+log.error
    // 20: full-chaos: diag_source=00, related=[04,07,12,15], src=query.sql
    .{
        .message = "causal chain depth 3 (d04 → d03 → d00)",
        .code = "C004",
        .severity = .Error,
        .help = "each step in the chain adds context",
        .source_idx = 3,
        .labels = &.{prim("TransformError", 479, 14)},
        .diag_source_idx = 3,
    },
    // 05: causal chain depth 4 (d05 → d04 → d03 → d00)
    .{
        .message = "causal chain depth 4 (d05 → d04 → d03 → d00)",
        .code = "C005",
        .severity = .Error,
        .help = "deep causal chains reveal propagation path",
        .source_idx = 3,
        .labels = &.{prim("Semaphore", 269, 9)},
        .diag_source_idx = 4,
    },
    // 06: related with source labels
    .{
        .message = "related with source labels",
        .code = "C006",
        .severity = .Warning,
        .help = "related errors provide additional context",
        .source_idx = 4,
        .labels = &.{ prim("title", 74, 5), sec("items", 107, 5) },
        .related_idxs = &.{ 0, 2 },
    },
    // 07: causal with source labels
    .{
        .message = "causal with source labels",
        .code = "C007",
        .severity = .Error,
        .help = "check the config values",
        .source_idx = 0,
        .labels = &.{ prim("host", 10, 4), sec("8080", 36, 4) },
        .diag_source_idx = 1,
    },
    // 08: both chain types
    .{
        .message = "both chain types (causal + related)",
        .code = "C008",
        .severity = .Error,
        .help = "causal chain explains why, related shows what else",
        .source_idx = 1,
        .labels = &.{prim("HealthCheck", 79, 11)},
        .diag_source_idx = 0,
        .related_idxs = &.{ 2, 3 },
    },
    // 09: nested related (d09 → related[d10], d10 → related[d00])
    .{
        .message = "nested related chain",
        .code = "C009",
        .severity = .Error,
        .help = "nested chains expand recursively",
        .source_idx = 2,
        .labels = &.{prim("ranked AS", 5, 9)},
        .related_idxs = &.{10},
    },
    // 10: nested inner (child of d09, related d00)
    .{
        .message = "nested related inner",
        .code = "C009",
        .severity = .Warning,
        .source_idx = 3,
        .labels = &.{sec("worker", 306, 6)},
        .related_idxs = &.{0},
    },
    // 11: causal + related + labels
    .{
        .message = "causal plus related with labels",
        .code = "C010",
        .severity = .Error,
        .source_idx = 4,
        .labels = &.{prim("for item", 175, 8)},
        .diag_source_idx = 9,
        .related_idxs = &.{ 2, 4 },
    },
    // 12: diamond (one cause, two effects as related)
    .{
        .message = "diamond: one cause with two related effects",
        .code = "C011",
        .severity = .Error,
        .help = "single root cause branches to multiple downstream errors",
        .source_idx = 3,
        .labels = &.{prim("asyncio.gather", 645, 14)},
        .diag_source_idx = 2,
        .related_idxs = &.{ 3, 4 },
    },
    // 13: cross-file (related all have different source files)
    .{
        .message = "cross-file chain spanning all sources",
        .code = "C012",
        .severity = .Error,
        .help = "related errors originate from five different files",
        .related_idxs = &.{ 0, 7, 3, 10, 12 },
    },
    // 14: sub-labels (related each have their own labels on same source)
    .{
        .message = "related with sub-labels",
        .code = "C013",
        .severity = .Warning,
        .help = "each related has its own label within the same source",
        .related_idxs = &.{ 15, 16 },
    },
    // 15: sub-label a
    .{
        .message = "ping context deadline exceeded",
        .code = "C013",
        .severity = .Error,
        .source_idx = 1,
        .labels = &.{prim("PingContext", 273, 11)},
    },
    // 16: sub-label b
    .{
        .message = "database connection is nil",
        .code = "C013",
        .severity = .Error,
        .source_idx = 1,
        .labels = &.{prim("database not connected", 140, 22)},
    },
    // 17: fan-out (one cause, 3 related effects, one effect has sub-cause)
    .{
        .message = "fan-out: one cause with multiple effects",
        .code = "C014",
        .severity = .Error,
        .help = "single failure triggers cascading errors",
        .source_idx = 0,
        .labels = &.{prim("pool_size", 108, 9)},
        .diag_source_idx = 11,
        .related_idxs = &.{ 7, 18, 19 },
    },
    // 18: fan-out sub (related to d17, has own causal source)
    .{
        .message = "timeout connecting to database",
        .code = "C014",
        .severity = .Error,
        .source_idx = 1,
        .labels = &.{prim("fmt.Errorf", 128, 10)},
        .diag_source_idx = 1,
    },
    // 19: fan-out sub (related to d17, has own causal source)
    .{
        .message = "transform pipeline rejected item",
        .code = "C014",
        .severity = .Error,
        .source_idx = 3,
        .labels = &.{prim("log.error", 516, 9)},
        .diag_source_idx = 2,
    },
    // 20: full chaos — all patterns combined
    .{
        .message = "full chaos: causal + related + labels + cross-file + nested",
        .code = "C019",
        .severity = .Error,
        .help = "maximal diagnostic chain complexity",
        .url = "https://example.invalid/chaos",
        .source_idx = 2,
        .labels = &.{ prim("employees", 146, 9), sec("dept_id", 55, 7) },
        .diag_source_idx = 0,
        .related_idxs = &.{ 4, 7, 12, 15 },
    },
};

pub fn build(alloc: std.mem.Allocator, sources: []const diagnostic.NamedSource) ![]diagnostic.Diagnostic {
    const nodes = try alloc.alloc(Node, DESCS.len);
    const diags = try alloc.alloc(diagnostic.Diagnostic, DESCS.len);

    // First pass: create all nodes and their diagnostic wrappers
    for (DESCS, nodes) |desc, *node| {
        const source_code: ?source.SourceCode = if (desc.source_idx) |si|
            sources[si].source()
        else
            null;

        node.* = Node{
            .message = desc.message,
            .code = desc.code,
            .severity = desc.severity,
            .help = desc.help,
            .url = desc.url,
            .source_code = source_code,
            .labels = desc.labels,
            .related = null,
            .diag_source = null,
        };
    }
    for (nodes, diags) |*node, *diag| {
    diag.* = node.implBy();
    }

    var total_related: usize = 0;
    for (DESCS) |desc| total_related += desc.related_idxs.len;

    const related_buf = try alloc.alloc(diagnostic.Diagnostic, total_related);

    {
        var pos: usize = 0;
        for (DESCS) |desc| {
            for (desc.related_idxs) |idx| {
                related_buf[pos] = diags[idx];
                pos += 1;
            }
        }
    }

    // Second pass: wire up chain references
    {
        var pos: usize = 0;
        for (DESCS, nodes) |desc, *node| {
            if (desc.related_idxs.len > 0) {
                node.related = related_buf[pos..][0..desc.related_idxs.len];
                pos += desc.related_idxs.len;
            }
            if (desc.diag_source_idx) |idx| {
                node.diag_source = &diags[idx];
            }
        }
    }

    return diags;
}

const std = @import("std");
