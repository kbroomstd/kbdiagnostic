use std::fmt::{self, Display, Formatter};

use miette::{Diagnostic, GraphicalReportHandler, GraphicalTheme, LabeledSpan, MietteSpanContents, Severity, SourceCode, SourceSpan, JSONReportHandler};

#[derive(Clone)]
struct Source {
    name: &'static str,
    data: &'static str,
}

impl SourceCode for Source {
    fn read_span<'a>(
        &'a self,
        span: &SourceSpan,
        _before: usize,
        _after: usize,
    ) -> Result<Box<dyn miette::SpanContents<'a> + 'a>, miette::MietteError> {
        let mut line = 1;
        let mut column = 1;
        for b in self.data.as_bytes()[..self.data.len().min(span.offset())].iter() {
            if *b == b'\n' {
                line += 1;
                column = 1;
            } else {
                column += 1;
            }
        }

        let mut line_count = 1;
        for b in self.data.as_bytes()[span.offset()..self.data.len().min(span.offset() + span.len())].iter() {
            if *b == b'\n' {
                line_count += 1;
            }
        }

        Ok(Box::new(MietteSpanContents::new_named(
            self.name.to_string(),
            self.data.as_bytes(),
            *span,
            line,
            column,
            line_count,
        )))
    }
}

#[derive(Clone, Copy)]
struct Label {
    text: Option<&'static str>,
    offset: usize,
    len: usize,
    primary: bool,
}

#[derive(Clone)]
struct Node {
    message: &'static str,
    code: Option<&'static str>,
    severity: Option<Severity>,
    help: Option<&'static str>,
    url: Option<&'static str>,
    source_idx: Option<usize>,
    labels: &'static [Label],
}

struct ShowcaseDiagnostic {
    nodes: &'static [Node],
    sources: &'static [Source],
    index: usize,
}

impl ShowcaseDiagnostic {
    fn node(&self) -> &Node {
        &self.nodes[self.index]
    }
}

impl Display for ShowcaseDiagnostic {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.write_str(self.node().message)
    }
}

impl fmt::Debug for ShowcaseDiagnostic {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.debug_struct("ShowcaseDiagnostic")
            .field("message", &self.node().message)
            .finish()
    }
}

impl std::error::Error for ShowcaseDiagnostic {}

impl Diagnostic for ShowcaseDiagnostic {
    fn code<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.node().code.map(|c| Box::new(c) as Box<dyn Display>)
    }

    fn severity(&self) -> Option<Severity> {
        self.node().severity
    }

    fn help<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.node().help.map(|h| Box::new(h) as Box<dyn Display>)
    }

    fn url<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.node().url.map(|u| Box::new(u) as Box<dyn Display>)
    }

    fn source_code(&self) -> Option<&dyn SourceCode> {
        self.node().source_idx.map(|i| &self.sources[i] as &dyn SourceCode)
    }

    fn labels(&self) -> Option<Box<dyn Iterator<Item = LabeledSpan> + '_>> {
        if self.node().labels.is_empty() {
            return None;
        }
        Some(Box::new(self.node().labels.iter().map(|label| {
            let span: SourceSpan = (label.offset, label.len).into();
            if label.primary {
                LabeledSpan::new_primary_with_span(label.text.map(str::to_owned), span)
            } else {
                LabeledSpan::new_with_span(label.text.map(str::to_owned), span)
            }
        })))
    }
}

fn main() {
    static SOURCES: &[Source] = &[
        Source {
            name: "pipeline.rs",
            data: r#"fn pipeline() {
    let config = load_config("config.toml").unwrap();
    let parsed = parse_schema(config.schema).unwrap();
    let plan = build_plan(&parsed, config.mode);
    execute(plan);
}
"#,
        },
        Source {
            name: "query.rs",
            data: r#"pub fn resolve() {
    let cursor = db.query("SELECT * FROM t WHERE id = ?");
    let row = cursor.next().unwrap();
    println!("{}", row["name"]);
}
"#,
        },
        Source {
            name: "template.txt",
            data: "hello {{name}}\n{{#each items}}\n- {{this}}\n{{/each}}\n",
        },
    ];

    static L0: &[Label] = &[
        Label { text: Some("config path"), offset: 28, len: 13, primary: true },
        Label { text: Some("missing file"), offset: 28, len: 13, primary: false },
    ];
    static L1: &[Label] = &[
        Label { text: Some("schema"), offset: 64, len: 12, primary: true },
        Label { text: Some("mode"), offset: 109, len: 4, primary: false },
    ];
    static L2: &[Label] = &[
        Label { text: Some("row access"), offset: 95, len: 15, primary: true },
        Label { text: Some("query result"), offset: 48, len: 12, primary: false },
        Label { text: Some("format string"), offset: 115, len: 15, primary: false },
    ];
    static L3: &[Label] = &[
        Label { text: Some("panic site"), offset: 24, len: 14, primary: true },
    ];
    static L4: &[Label] = &[
        Label { text: Some("name"), offset: 7, len: 4, primary: true },
        Label { text: Some("section"), offset: 15, len: 17, primary: false },
        Label { text: Some("loop"), offset: 34, len: 13, primary: false },
    ];

    static NODES: &[Node] = &[
        Node { message: "cannot open config", code: Some("E001"), severity: Some(Severity::Error), help: Some("pass --config or create config.toml"), url: Some("https://example.invalid/config"), source_idx: Some(0), labels: L0 },
        Node { message: "schema parse failed", code: Some("E002"), severity: Some(Severity::Error), help: Some("validate schema before execution"), url: None, source_idx: Some(0), labels: L1 },
        Node { message: "SQL row shape mismatch", code: Some("E003"), severity: Some(Severity::Warning), help: Some("project columns explicitly"), url: Some("https://example.invalid/sql"), source_idx: Some(1), labels: L2 },
        Node { message: "planner aborted after recursive expansion", code: Some("E004"), severity: Some(Severity::Error), help: Some("cap recursion depth"), url: None, source_idx: Some(0), labels: L1 },
        Node { message: "retry budget exhausted", code: Some("W005"), severity: Some(Severity::Warning), help: Some("increase retry budget"), url: None, source_idx: None, labels: &[] },
        Node { message: "unresolved symbol in generated stage", code: Some("E006"), severity: Some(Severity::Error), help: Some("emit the symbol before use"), url: None, source_idx: Some(1), labels: L2 },
        Node { message: "panic in fallback renderer", code: Some("E007"), severity: Some(Severity::Error), help: Some("never call unwrap in renderer"), url: None, source_idx: Some(0), labels: L3 },
        Node { message: "feature gate mismatch", code: Some("E008"), severity: Some(Severity::Warning), help: Some("align cfg with manifest"), url: Some("https://example.invalid/cfg"), source_idx: None, labels: &[] },
        Node { message: "row decoder overflow", code: Some("E009"), severity: Some(Severity::Error), help: Some("bound row length"), url: None, source_idx: Some(1), labels: L2 },
        Node { message: "invalid placeholder", code: Some("E010"), severity: Some(Severity::Error), help: Some("use named params"), url: None, source_idx: Some(2), labels: L4 },
        Node { message: "late-bound lifetime escaped", code: Some("E011"), severity: Some(Severity::Error), help: Some("tie lifetime to input"), url: None, source_idx: Some(0), labels: L1 },
        Node { message: "unused branch still mutates state", code: Some("W012"), severity: Some(Severity::Warning), help: Some("make side effect explicit"), url: None, source_idx: None, labels: &[] },
        Node { message: "renderer saw malformed label set", code: Some("E013"), severity: Some(Severity::Error), help: Some("always emit primary label"), url: None, source_idx: Some(0), labels: L3 },
        Node { message: "subquery recursion limit exceeded", code: Some("E014"), severity: Some(Severity::Error), help: Some("split recursive query"), url: None, source_idx: Some(1), labels: L2 },
        Node { message: "graphical handler context missing", code: Some("E015"), severity: Some(Severity::Error), help: Some("attach source before render"), url: None, source_idx: None, labels: &[] },
        Node { message: "secondary index stale", code: Some("W016"), severity: Some(Severity::Warning), help: Some("rebuild index"), url: None, source_idx: Some(1), labels: L2 },
        Node { message: "source span crosses statement boundary", code: Some("E017"), severity: Some(Severity::Error), help: Some("narrow span to expression"), url: None, source_idx: Some(0), labels: L1 },
        Node { message: "I/O path normalization lost segment", code: Some("E018"), severity: Some(Severity::Error), help: Some("preserve canonical path"), url: Some("https://example.invalid/path"), source_idx: Some(0), labels: L0 },
        Node { message: "diagnostic chain collapsed", code: Some("E019"), severity: Some(Severity::Error), help: Some("keep root and cause"), url: None, source_idx: None, labels: &[] },
        Node { message: "all clear but noisy", code: Some("A020"), severity: Some(Severity::Advice), help: Some("reduce log spam"), url: None, source_idx: None, labels: &[] },
    ];

    let use_json = std::env::args().any(|arg| arg == "--json");
    let json_handler = JSONReportHandler::new();
    let graphical_handler = GraphicalReportHandler::new_themed(GraphicalTheme::unicode_nocolor())
        .without_syntax_highlighting()
        .with_width(100);

    for index in 0..NODES.len() {
        let diag = ShowcaseDiagnostic { nodes: NODES, sources: SOURCES, index };
        let mut out = String::new();
        if use_json {
            json_handler.render_report(&mut out, &diag).unwrap();
        } else {
            graphical_handler.render_report(&mut out, &diag).unwrap();
        }
        println!("{out}");
    }
}
