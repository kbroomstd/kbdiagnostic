const diagnostic = @import("kbdiagnostics");

const sources = [_]diagnostic.NamedSource{
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

const l0 = [_]diagnostic.LabeledSpan{
    diagnostic.LabeledSpan.newPrimary("config path", 28, 13),
    diagnostic.LabeledSpan.new("missing file", 28, 13),
};
const l1 = [_]diagnostic.LabeledSpan{
    diagnostic.LabeledSpan.newPrimary("schema", 64, 12),
    diagnostic.LabeledSpan.new("mode", 109, 4),
};
const l2 = [_]diagnostic.LabeledSpan{
    diagnostic.LabeledSpan.newPrimary("row access", 95, 15),
    diagnostic.LabeledSpan.new("query result", 48, 12),
    diagnostic.LabeledSpan.new("format string", 115, 15),
};
const l3 = [_]diagnostic.LabeledSpan{
    diagnostic.LabeledSpan.newPrimary("panic site", 24, 14),
};
const l4 = [_]diagnostic.LabeledSpan{
    diagnostic.LabeledSpan.newPrimary("name", 7, 4),
    diagnostic.LabeledSpan.new("section", 15, 17),
    diagnostic.LabeledSpan.new("loop", 34, 13),
};

pub const all = [_]diagnostic.DiagnosticData{
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
