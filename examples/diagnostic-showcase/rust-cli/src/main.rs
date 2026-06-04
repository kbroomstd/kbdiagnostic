use std::path::PathBuf;

use miette::{
    GraphicalReportHandler, GraphicalTheme, JSONReportHandler,
};

mod example_basic;
mod example_chained;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut use_json = false;
    let mut sources_dir = PathBuf::from("../sources");

    {
        let mut argv = std::env::args().skip(1).peekable();
        while let Some(arg) = argv.next() {
            match arg.as_str() {
                "--json" => use_json = true,
                "--sources-dir" => {
                    sources_dir = PathBuf::from(
                        argv.next().ok_or("missing value for --sources-dir")?,
                    );
                }
                _ => {}
            }
        }
    }

    let source_names = &[
        "config.yaml", "handler.go", "query.sql", "pipeline.py", "template.tera",
    ];
    let sources: Vec<example_chained::Source> = source_names
        .iter()
        .map(|name| {
            let path = sources_dir.join(name);
            let data = std::fs::read_to_string(&path)?;
            Ok(example_chained::Source {
                name: name.to_string(),
                data,
            })
        })
        .collect::<Result<Vec<_>, Box<dyn std::error::Error>>>()?;

    let json_handler = JSONReportHandler::new();
    let graphical_handler = GraphicalReportHandler::new_themed(GraphicalTheme::unicode_nocolor())
        .without_syntax_highlighting()
        .with_width(100);

    let render = |diag: &dyn miette::Diagnostic| {
        let mut out = String::new();
        if use_json {
            json_handler.render_report(&mut out, diag).unwrap();
        } else {
            graphical_handler.render_report(&mut out, diag).unwrap();
        }
        println!("{out}");
    };

    for diag in &example_basic::examples() {
        render(diag);
    }

    let chained = example_chained::build(sources);
    for diag in &chained {
        render(diag);
    }

    Ok(())
}
