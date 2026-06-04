use std::fmt::{self, Display, Formatter};
use std::ptr::NonNull;
use std::rc::Rc;

use miette::{
    Diagnostic, LabeledSpan, MietteSpanContents, Severity, SourceCode, SourceSpan,
};

#[derive(Clone)]
pub struct Source {
    pub name: String,
    pub data: String,
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
        for b in self.data.as_bytes()
            [span.offset()..self.data.len().min(span.offset() + span.len())]
            .iter()
        {
            if *b == b'\n' {
                line_count += 1;
            }
        }

        Ok(Box::new(MietteSpanContents::new_named(
            self.name.clone(),
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

pub struct ChainedDiagnostic {
    message: &'static str,
    code: Option<&'static str>,
    severity: Option<Severity>,
    help: Option<&'static str>,
    url: Option<&'static str>,
    source_idx: Option<usize>,
    sources: Rc<Vec<Source>>,
    labels: &'static [Label],
    related: Vec<*const ChainedDiagnostic>,
    diag_source: Option<*const ChainedDiagnostic>,
}

// SAFETY: ChainedDiagnostic only contains raw pointers to other
// ChainedDiagnostic values within the same stable Vec allocation.
// No ownership or mutation through these pointers.
unsafe impl Send for ChainedDiagnostic {}
unsafe impl Sync for ChainedDiagnostic {}

impl ChainedDiagnostic {
    fn source(&self) -> Option<&Source> {
        self.source_idx.map(|i| &self.sources[i])
    }
}

impl Display for ChainedDiagnostic {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.write_str(self.message)
    }
}

impl fmt::Debug for ChainedDiagnostic {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.debug_struct("ChainedDiagnostic")
            .field("message", &self.message)
            .finish()
    }
}

impl std::error::Error for ChainedDiagnostic {}

impl Diagnostic for ChainedDiagnostic {
    fn code<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.code.map(|c| Box::new(c) as Box<dyn Display>)
    }

    fn severity(&self) -> Option<Severity> {
        self.severity
    }

    fn help<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.help.map(|h| Box::new(h) as Box<dyn Display>)
    }

    fn url<'a>(&'a self) -> Option<Box<dyn Display + 'a>> {
        self.url.map(|u| Box::new(u) as Box<dyn Display>)
    }

    fn source_code(&self) -> Option<&dyn SourceCode> {
        self.source().map(|s| s as &dyn SourceCode)
    }

    fn labels(&self) -> Option<Box<dyn Iterator<Item = LabeledSpan> + '_>> {
        if self.labels.is_empty() {
            return None;
        }
        Some(Box::new(self.labels.iter().map(|label| {
            let span: SourceSpan = (label.offset, label.len).into();
            if label.primary {
                LabeledSpan::new_primary_with_span(label.text.map(str::to_owned), span)
            } else {
                LabeledSpan::new_with_span(label.text.map(str::to_owned), span)
            }
        })))
    }

    fn related<'a>(&'a self) -> Option<Box<dyn Iterator<Item = &'a dyn Diagnostic> + 'a>> {
        if self.related.is_empty() {
            return None;
        }
        // SAFETY: all raw pointers point to ChainedDiagnostic values
        // within the same stable Vec that outlives &self.
        let refs: Vec<&'a dyn Diagnostic> = self
            .related
            .iter()
            .map(|&p| unsafe { &*p as &dyn Diagnostic })
            .collect();
        Some(Box::new(refs.into_iter()))
    }

    fn diagnostic_source(&self) -> Option<&dyn Diagnostic> {
        // SAFETY: same lifetime invariant as related()
        self.diag_source
            .map(|p| unsafe { &*p as &dyn Diagnostic })
    }
}

struct NodeDesc {
    message: &'static str,
    code: Option<&'static str>,
    severity: Option<Severity>,
    help: Option<&'static str>,
    url: Option<&'static str>,
    source_idx: Option<usize>,
    labels: &'static [Label],
    related_idxs: &'static [usize],
    diag_source_idx: Option<usize>,
}

const fn primary(text: &'static str, offset: usize, len: usize) -> Label {
    Label { text: Some(text), offset, len, primary: true }
}
const fn secondary(text: &'static str, offset: usize, len: usize) -> Label {
    Label { text: Some(text), offset, len, primary: false }
}

const DESCS: &[NodeDesc] = &[
    // 00: standalone
    NodeDesc {
        message: "standalone diagnostic with no chain",
        code: Some("S000"),
        severity: Some(Severity::Advice),
        help: Some("everything is fine"),
        url: None,
        source_idx: None,
        labels: &[],
        related_idxs: &[],
        diag_source_idx: None,
    },
    // 01: single related sibling
    NodeDesc {
        message: "single related sibling",
        code: Some("C001"),
        severity: Some(Severity::Error),
        help: Some("check the sibling diagnostic for context"),
        url: None,
        source_idx: None,
        labels: &[],
        related_idxs: &[0],
        diag_source_idx: None,
    },
    // 02: multiple related siblings (3, with repetition)
    NodeDesc {
        message: "multiple related siblings",
        code: Some("C002"),
        severity: Some(Severity::Warning),
        help: Some("all siblings must be resolved"),
        url: None,
        source_idx: None,
        labels: &[],
        related_idxs: &[0, 1, 0],
        diag_source_idx: None,
    },
    // 03: causal chain depth 2
    NodeDesc {
        message: "causal chain depth 2 (d03 → d00)",
        code: Some("C003"),
        severity: Some(Severity::Error),
        help: Some("root cause is the standalone diagnostic"),
        url: None,
        source_idx: Some(2),
        labels: &[primary("ROW_NUMBER", 68, 10)],
        related_idxs: &[],
        diag_source_idx: Some(0),
    },
    // 04: causal chain depth 3
    NodeDesc {
        message: "causal chain depth 3 (d04 → d03 → d00)",
        code: Some("C004"),
        severity: Some(Severity::Error),
        help: Some("each step in the chain adds context"),
        url: None,
        source_idx: Some(3),
        labels: &[primary("TransformError", 479, 14)],
        related_idxs: &[],
        diag_source_idx: Some(3),
    },
    // 05: causal chain depth 4
    NodeDesc {
        message: "causal chain depth 4 (d05 → d04 → d03 → d00)",
        code: Some("C005"),
        severity: Some(Severity::Error),
        help: Some("deep causal chains reveal propagation path"),
        url: None,
        source_idx: Some(3),
        labels: &[primary("Semaphore", 269, 9)],
        related_idxs: &[],
        diag_source_idx: Some(4),
    },
    // 06: related with source labels
    NodeDesc {
        message: "related with source labels",
        code: Some("C006"),
        severity: Some(Severity::Warning),
        help: Some("related errors provide additional context"),
        url: None,
        source_idx: Some(4),
        labels: &[primary("title", 74, 5), secondary("items", 107, 5)],
        related_idxs: &[0, 2],
        diag_source_idx: None,
    },
    // 07: causal with source labels
    NodeDesc {
        message: "causal with source labels",
        code: Some("C007"),
        severity: Some(Severity::Error),
        help: Some("check the config values"),
        url: None,
        source_idx: Some(0),
        labels: &[primary("host", 10, 4), secondary("8080", 36, 4)],
        related_idxs: &[],
        diag_source_idx: Some(1),
    },
    // 08: both chain types
    NodeDesc {
        message: "both chain types (causal + related)",
        code: Some("C008"),
        severity: Some(Severity::Error),
        help: Some("causal chain explains why, related shows what else"),
        url: None,
        source_idx: Some(1),
        labels: &[primary("HealthCheck", 79, 11)],
        related_idxs: &[2, 3],
        diag_source_idx: Some(0),
    },
    // 09: nested related (d09 → d10 → d00 via related)
    NodeDesc {
        message: "nested related chain",
        code: Some("C009"),
        severity: Some(Severity::Error),
        help: Some("nested chains expand recursively"),
        url: None,
        source_idx: Some(2),
        labels: &[primary("ranked AS", 5, 9)],
        related_idxs: &[10],
        diag_source_idx: None,
    },
    // 10: nested inner
    NodeDesc {
        message: "nested related inner",
        code: Some("C009"),
        severity: Some(Severity::Warning),
        help: None,
        url: None,
        source_idx: Some(3),
        labels: &[secondary("worker", 306, 6)],
        related_idxs: &[0],
        diag_source_idx: None,
    },
    // 11: causal + related + labels
    NodeDesc {
        message: "causal plus related with labels",
        code: Some("C010"),
        severity: Some(Severity::Error),
        help: None,
        url: None,
        source_idx: Some(4),
        labels: &[primary("for item", 175, 8)],
        related_idxs: &[2, 4],
        diag_source_idx: Some(9),
    },
    // 12: diamond
    NodeDesc {
        message: "diamond: one cause with two related effects",
        code: Some("C011"),
        severity: Some(Severity::Error),
        help: Some("single root cause branches to multiple downstream errors"),
        url: None,
        source_idx: Some(3),
        labels: &[primary("asyncio.gather", 645, 14)],
        related_idxs: &[3, 4],
        diag_source_idx: Some(2),
    },
    // 13: cross-file
    NodeDesc {
        message: "cross-file chain spanning all sources",
        code: Some("C012"),
        severity: Some(Severity::Error),
        help: Some("related errors originate from five different files"),
        url: None,
        source_idx: None,
        labels: &[],
        related_idxs: &[0, 7, 3, 10, 12],
        diag_source_idx: None,
    },
    // 14: sub-labels
    NodeDesc {
        message: "related with sub-labels",
        code: Some("C013"),
        severity: Some(Severity::Warning),
        help: Some("each related has its own label within the same source"),
        url: None,
        source_idx: None,
        labels: &[],
        related_idxs: &[15, 16],
        diag_source_idx: None,
    },
    // 15: sub-label a
    NodeDesc {
        message: "ping context deadline exceeded",
        code: Some("C013"),
        severity: Some(Severity::Error),
        help: None,
        url: None,
        source_idx: Some(1),
        labels: &[primary("PingContext", 273, 11)],
        related_idxs: &[],
        diag_source_idx: None,
    },
    // 16: sub-label b
    NodeDesc {
        message: "database connection is nil",
        code: Some("C013"),
        severity: Some(Severity::Error),
        help: None,
        url: None,
        source_idx: Some(1),
        labels: &[primary("database not connected", 140, 22)],
        related_idxs: &[],
        diag_source_idx: None,
    },
    // 17: fan-out
    NodeDesc {
        message: "fan-out: one cause with multiple effects",
        code: Some("C014"),
        severity: Some(Severity::Error),
        help: Some("single failure triggers cascading errors"),
        url: None,
        source_idx: Some(0),
        labels: &[primary("pool_size", 108, 9)],
        related_idxs: &[7, 18, 19],
        diag_source_idx: Some(11),
    },
    // 18: fan-out sub a
    NodeDesc {
        message: "timeout connecting to database",
        code: Some("C014"),
        severity: Some(Severity::Error),
        help: None,
        url: None,
        source_idx: Some(1),
        labels: &[primary("fmt.Errorf", 128, 10)],
        related_idxs: &[],
        diag_source_idx: Some(1),
    },
    // 19: fan-out sub b
    NodeDesc {
        message: "transform pipeline rejected item",
        code: Some("C014"),
        severity: Some(Severity::Error),
        help: None,
        url: None,
        source_idx: Some(3),
        labels: &[primary("log.error", 516, 9)],
        related_idxs: &[],
        diag_source_idx: Some(2),
    },
    // 20: full chaos
    NodeDesc {
        message: "full chaos: causal + related + labels + cross-file + nested",
        code: Some("C019"),
        severity: Some(Severity::Error),
        help: Some("maximal diagnostic chain complexity"),
        url: Some("https://example.invalid/chaos"),
        source_idx: Some(2),
        labels: &[primary("employees", 146, 9), secondary("dept_id", 55, 7)],
        related_idxs: &[4, 7, 12, 15],
        diag_source_idx: Some(0),
    },
];

pub fn build(sources: Vec<Source>) -> Vec<ChainedDiagnostic> {
    let sources = Rc::new(sources);

    // Pre-allocate so pointers remain stable
    let mut diags = Vec::with_capacity(DESCS.len());

    // First pass: create all entries with empty chain fields
    for desc in DESCS {
        diags.push(ChainedDiagnostic {
            message: desc.message,
            code: desc.code,
            severity: desc.severity,
            help: desc.help,
            url: desc.url,
            source_idx: desc.source_idx,
            sources: Rc::clone(&sources),
            labels: desc.labels,
            related: Vec::new(),
            diag_source: None,
        });
    }

    // Take raw pointers while we have no mutable borrows
    let ptrs: Vec<*const ChainedDiagnostic> = diags.iter().map(|d| d as *const _).collect();

    // SAFETY: raw pointers point into the stable Vec allocation.
    // Vec will not reallocate because capacity == length.
    // Each diag's chain fields are only set once, here, before any
    // user code can access them.
    for (i, desc) in DESCS.iter().enumerate() {
        diags[i].related = desc
            .related_idxs
            .iter()
            .map(|&idx| ptrs[idx])
            .collect();
        diags[i].diag_source = desc.diag_source_idx.map(|idx| ptrs[idx]);
    }

    diags
}
