const std = @import("std");
const kb = @import("kbdiagnostics");

const NamedSource = struct {
    name: []const u8,
    data: []const u8,

    fn readSpan(ptr: *const anyopaque, s: *const kb.SourceSpan, _: usize, _: usize) anyerror!kb.SpanContents {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        var line: usize = 1;
        var column: usize = 1;
        var i: usize = 0;
        while (i < @min(s.offset, self.data.len)) : (i += 1) {
            if (self.data[i] == '\n') {
                line += 1;
                column = 1;
            } else {
                column += 1;
            }
        }
        var line_count: usize = 1;
        var j = s.offset;
        const end = @min(self.data.len, s.offset + s.length);
        while (j < end) : (j += 1) {
            if (self.data[j] == '\n') line_count += 1;
        }
        return .{ ._data = self.data, ._span = s.*, ._name = self.name, ._line = line, ._column = column, ._line_count = line_count, ._language = null };
    }

    const vtable = kb.SourceCode.VTable{ .readSpan = readSpan };

    fn source(self: *const @This()) kb.SourceCode {
        return .{ .ptr = self, .vtable = &vtable };
    }
};

const diag = struct {
    message: []const u8,
    code: ?[]const u8 = null,
    severity: ?kb.Severity = null,
    help: ?[]const u8 = null,
    url: ?[]const u8 = null,
    source: ?*const kb.SourceCode = null,
    labels: []const kb.LabeledSpan = &.{},
    related: []const kb.Diagnostic = &.{},

    pub fn diagnostic(self: *const @This()) kb.Diagnostic {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn codeFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.code;
    }
    fn severityFn(ptr: *const anyopaque) ?kb.Severity {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.severity;
    }
    fn helpFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.help;
    }
    fn urlFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.url;
    }
    fn sourceFn(ptr: *const anyopaque) ?*const kb.SourceCode {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.source;
    }
    fn labelsFn(ptr: *const anyopaque) ?[]const kb.LabeledSpan {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return if (self.labels.len == 0) null else self.labels;
    }
    fn relatedFn(ptr: *const anyopaque) ?[]const kb.Diagnostic {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return if (self.related.len == 0) null else self.related;
    }
    fn diagnosticSourceFn(_: *const anyopaque) ?*const kb.Diagnostic {
        return null;
    }
    fn messageFn(ptr: *const anyopaque) []const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.message;
    }

    const vtable = kb.Diagnostic.VTable{
        .code = codeFn,
        .severity = severityFn,
        .help = helpFn,
        .url = urlFn,
        .sourceCode = sourceFn,
        .labels = labelsFn,
        .related = relatedFn,
        .diagnosticSource = diagnosticSourceFn,
        .message = messageFn,
    };
};

const sources = [_]NamedSource{
    .{ .name = "pipeline.rs", .data =
        \\fn pipeline() {
        \\    let config = load_config("config.toml").unwrap();
        \\    let parsed = parse_schema(config.schema).unwrap();
        \\    let plan = build_plan(&parsed, config.mode);
        \\    execute(plan);
        \\}
    },
    .{ .name = "query.rs", .data =
        \\pub fn resolve() {
        \\    let cursor = db.query("SELECT * FROM t WHERE id = ?");
        \\    let row = cursor.next().unwrap();
        \\    println!("{}", row["name"]);
        \\}
    },
    .{ .name = "template.txt", .data = "hello {{name}}\n{{#each items}}\n- {{this}}\n{{/each}}\n" },
};

const source_pipeline = sources[0].source();
const source_query = sources[1].source();
const source_template = sources[2].source();

const l0 = [_]kb.LabeledSpan{
    .{ ._label = "config path", ._span = .{ .offset = 28, .length = 13 }, ._primary = true },
    .{ ._label = "missing file", ._span = .{ .offset = 28, .length = 13 }, ._primary = false },
};
const l1 = [_]kb.LabeledSpan{
    .{ ._label = "schema", ._span = .{ .offset = 64, .length = 12 }, ._primary = true },
    .{ ._label = "mode", ._span = .{ .offset = 109, .length = 4 }, ._primary = false },
};
const l2 = [_]kb.LabeledSpan{
    .{ ._label = "row access", ._span = .{ .offset = 95, .length = 15 }, ._primary = true },
    .{ ._label = "query result", ._span = .{ .offset = 48, .length = 12 }, ._primary = false },
    .{ ._label = "format string", ._span = .{ .offset = 115, .length = 15 }, ._primary = false },
};
const l3 = [_]kb.LabeledSpan{
    .{ ._label = "panic site", ._span = .{ .offset = 24, .length = 14 }, ._primary = true },
};
const l4 = [_]kb.LabeledSpan{
    .{ ._label = "name", ._span = .{ .offset = 7, .length = 4 }, ._primary = true },
    .{ ._label = "section", ._span = .{ .offset = 15, .length = 17 }, ._primary = false },
    .{ ._label = "loop", ._span = .{ .offset = 34, .length = 13 }, ._primary = false },
};

const all = [_]diag{
    .{ .message = "cannot open config", .code = "E001", .severity = .Error, .help = "pass --config or create config.toml", .url = "https://example.invalid/config", .source = &source_pipeline, .labels = &l0 },
    .{ .message = "schema parse failed", .code = "E002", .severity = .Error, .help = "validate schema before execution", .source = &source_pipeline, .labels = &l1 },
    .{ .message = "SQL row shape mismatch", .code = "E003", .severity = .Warning, .help = "project columns explicitly", .url = "https://example.invalid/sql", .source = &source_query, .labels = &l2 },
    .{ .message = "planner aborted after recursive expansion", .code = "E004", .severity = .Error, .help = "cap recursion depth", .source = &source_pipeline, .labels = &l1 },
    .{ .message = "retry budget exhausted", .code = "W005", .severity = .Warning, .help = "increase retry budget" },
    .{ .message = "unresolved symbol in generated stage", .code = "E006", .severity = .Error, .help = "emit the symbol before use", .source = &source_query, .labels = &l2 },
    .{ .message = "panic in fallback renderer", .code = "E007", .severity = .Error, .help = "never call unwrap in renderer", .source = &source_pipeline, .labels = &l3 },
    .{ .message = "feature gate mismatch", .code = "E008", .severity = .Warning, .help = "align cfg with manifest", .url = "https://example.invalid/cfg" },
    .{ .message = "row decoder overflow", .code = "E009", .severity = .Error, .help = "bound row length", .source = &source_query, .labels = &l2 },
    .{ .message = "invalid placeholder", .code = "E010", .severity = .Error, .help = "use named params", .source = &source_template, .labels = &l4 },
    .{ .message = "late-bound lifetime escaped", .code = "E011", .severity = .Error, .help = "tie lifetime to input", .source = &source_pipeline, .labels = &l1 },
    .{ .message = "unused branch still mutates state", .code = "W012", .severity = .Warning, .help = "make side effect explicit" },
    .{ .message = "renderer saw malformed label set", .code = "E013", .severity = .Error, .help = "always emit primary label", .source = &source_pipeline, .labels = &l3 },
    .{ .message = "subquery recursion limit exceeded", .code = "E014", .severity = .Error, .help = "split recursive query", .source = &source_query, .labels = &l2 },
    .{ .message = "graphical handler context missing", .code = "E015", .severity = .Error, .help = "attach source before render" },
    .{ .message = "secondary index stale", .code = "W016", .severity = .Warning, .help = "rebuild index", .source = &source_query, .labels = &l2 },
    .{ .message = "source span crosses statement boundary", .code = "E017", .severity = .Error, .help = "narrow span to expression", .source = &source_pipeline, .labels = &l1 },
    .{ .message = "I/O path normalization lost segment", .code = "E018", .severity = .Error, .help = "preserve canonical path", .url = "https://example.invalid/path", .source = &source_pipeline, .labels = &l0 },
    .{ .message = "diagnostic chain collapsed", .code = "E019", .severity = .Error, .help = "keep root and cause" },
    .{ .message = "all clear but noisy", .code = "A020", .severity = .Advice, .help = "reduce log spam" },
};

pub fn main(init: std.process.Init) !void {
    var use_json = false;
    var args = try init.minimal.args.iterateAllocator(init.arena.allocator());
    defer args.deinit();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            use_json = true;
            break;
        }
    }
    const handler = if (use_json) (kb.JsonReportHandler{}).base else (kb.GraphicalReportHandler{}).base;

    var buf: [4096]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &buf);
    const out = &file_writer.interface;

    for (all) |item| {
        const d = item.diagnostic();
        try handler.display(&d, out);
        if (!use_json) try out.writeByte('\n');
    }
    try out.flush();
}
