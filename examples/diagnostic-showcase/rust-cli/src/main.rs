use miette::{
    GraphicalReportHandler, GraphicalTheme, JSONReportHandler,
};

mod example_basic;

fn main() {
    let use_json = std::env::args().any(|arg| arg == "--json");
    let json_handler = JSONReportHandler::new();
    let graphical_handler = GraphicalReportHandler::new_themed(GraphicalTheme::unicode_nocolor())
        .without_syntax_highlighting()
        .with_width(100);

    example_basic::examples().into_iter().for_each(|diag| {
        let mut out = String::new();
        if use_json {
            json_handler.render_report(&mut out, &diag).unwrap();
        } else {
            graphical_handler.render_report(&mut out, &diag).unwrap();
        }
        println!("{out}");
    });
}
