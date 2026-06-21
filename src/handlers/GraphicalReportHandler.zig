const std = @import("std");
const diag = @import("../diagnostic.zig");
const sev = @import("../severity.zig");
const span = @import("../span.zig");
const source = @import("../source.zig");
const report = @import("../report.zig");

pub const GraphicalReportHandler = @This();
const Self = @This();
pub fn base(self: *const Self) report.ReportHandler {
    return report.ReportHandler.implBy(self);
}

const chars = struct {
    const hbar = "─";
    const vbar = "│";
    const vbar_break = "·";
    const uarrow = "▲";
    const rarrow = "▶";
    const ltop = "╭";
    const lbot = "╰";
    const lcross = "├";
    const rcross = "┤";
    const underbar = "┬";
    const underline = "─";
};

fn icon(s: ?sev.Severity) []const u8 {
    return switch (s orelse .Error) {
        .Error => "×",
        .Warning => "⚠",
        .Advice => "☞",
    };
}

fn sevName(s: ?sev.Severity) []const u8 {
    return switch (s orelse .Error) {
        .Error => "Error",
        .Warning => "Warning",
        .Advice => "Advice",
    };
}

pub fn display(_: *const Self, allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
    try renderReportInner(allocator, writer, err, true, true, false);
}

fn renderReportInner(
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
    err: *const diag.Diagnostic,
    show_footer: bool,
    show_cause_chain: bool,
    show_related_as_nested: bool,
) std.Io.Writer.Error!void {
    try renderHeader(writer, err, false);
    try renderCauses(allocator, writer, err, show_cause_chain);
    if (err.sourceCode()) |src| {
        try renderSnippets(allocator, writer, err, src);
    }
    if (show_footer) {
        try renderFooter(writer, err);
    }
    try renderRelated(allocator, writer, err, show_related_as_nested);
}

fn renderHeader(writer: *std.Io.Writer, err: *const diag.Diagnostic, is_nested: bool) std.Io.Writer.Error!void {
    var need_newline = is_nested;
    if (err.code()) |code| {
        if (err.url()) |url| {
            try writer.print("\x1b]8;;{s}\x1b\\{s} ({s})\x1b]8;;\x1b\\\n", .{ url, code, "link" });
        } else {
            try writer.print("{s}\n", .{code});
        }
        need_newline = true;
    }
    if (need_newline) try writer.writeByte('\n');
}

fn renderCauses(allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic, show_cause_chain: bool) std.Io.Writer.Error!void {
    try writer.print("  {s} {s}\n", .{ icon(err.severity()), err.message() });
    if (show_cause_chain) {
        try renderCauseChain(allocator, writer, err);
    }
}

fn renderCauseChain(allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
    var current = err.diagnosticSource();
    while (current) |cause| {
        const next = cause.diagnosticSource();
        const initial_prefix = if (next == null) "  ╰─▶ " else "  ├─▶ ";
        const rest_prefix = if (next == null) "      " else "  │   ";
        var inner: std.ArrayList(u8) = .empty;
        defer inner.deinit(allocator);
        var inner_writer: std.Io.Writer.Allocating = .fromArrayList(allocator, &inner);
        defer inner_writer.deinit();

        try renderReportInner(allocator, &inner_writer.writer, cause, true, false, false);
        const committed = inner_writer.toArrayList();
        const trimmed = trimStartNewlines(committed.items);
        if (trimmed.len > 0) try writeIndentedBlock(writer, trimmed, initial_prefix, rest_prefix);
        current = next;
    }
}

fn renderFooter(writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
    if (err.help()) |help| {
        try writer.print("  help: {s}\n", .{help});
    }
}

fn renderRelated(allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic, show_related_as_nested: bool) std.Io.Writer.Error!void {
    if (err.related()) |related| {
        if (show_related_as_nested) {
            for (related, 0..) |cause, idx| {
                const is_last = idx + 1 == related.len;
                const initial_prefix = if (is_last) "  ╰─▶ " else "  ├─▶ ";
                const rest_prefix = if (is_last) "      " else "  │   ";
                var inner = std.ArrayList(u8).empty;
                defer inner.deinit(allocator);
                var inner_writer: std.Io.Writer.Allocating = .fromArrayList(allocator, &inner);
                defer inner_writer.deinit();

                try renderReportInner(allocator, &inner_writer.writer, &cause, true, false, true);

                const committed = inner_writer.toArrayList();
                const trimmed = trimNewlines(committed.items);
                if (trimmed.len == 0) continue;
                try writeIndentedBlock(writer, trimmed, initial_prefix, rest_prefix);
            }
        } else {
            for (related) |cause| {
                try writer.writeByte('\n');
                try writer.print("{s}: ", .{sevName(cause.severity())});
                try renderHeader(writer, &cause, true);
                try renderCauses(allocator, writer, &cause, true);
                if (cause.sourceCode()) |src| {
                    try renderSnippets(allocator, writer, &cause, src);
                }
                try renderFooter(writer, &cause);
                try renderRelated(allocator, writer, &cause, false);
            }
        }
    }
}

fn trimStartNewlines(text: []const u8) []const u8 {
    var start: usize = 0;
    while (start < text.len and text[start] == '\n') start += 1;
    return text[start..];
}

fn trimNewlines(text: []const u8) []const u8 {
    var start: usize = 0;
    var end = text.len;
    while (start < end and text[start] == '\n') start += 1;
    while (end > start and text[end - 1] == '\n') end -= 1;
    return text[start..end];
}

fn trimRightSpaces(text: []const u8) []const u8 {
    var end = text.len;
    while (end > 0 and (text[end - 1] == ' ' or text[end - 1] == '\t')) end -= 1;
    return text[0..end];
}

fn writeIndentedBlock(writer: *std.Io.Writer, text: []const u8, initial_prefix: []const u8, rest_prefix: []const u8) std.Io.Writer.Error!void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    var first = true;
    while (lines.next()) |line| {
        const trimmed_line = trimRightSpaces(line);
        try writer.writeAll(if (first) initial_prefix else rest_prefix);
        try writer.writeAll(trimmed_line);
        try writer.writeByte('\n');
        first = false;
    }
}

fn renderSnippets(_: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic, src: *const source.SourceCode) std.Io.Writer.Error!void {
    const raw_labels = err.labels() orelse return;
    if (raw_labels.len == 0) return;

    const gpa = std.heap.smp_allocator;
    var labels: std.ArrayList(span.LabeledSpan) = .empty;
    defer labels.deinit(gpa);
    labels.appendSlice(gpa, raw_labels) catch unreachable;
    std.mem.sort(span.LabeledSpan, labels.items, {}, lessLabelOffset);

    var contexts: std.ArrayList(span.LabeledSpan) = .empty;
    defer contexts.deinit(gpa);

    for (labels.items) |right| {
        const right_conts = src.readSpan(right.inner(), 1, 1) catch return;
        if (contexts.items.len == 0) {
            contexts.append(gpa, right) catch unreachable;
            continue;
        }

        const left = contexts.items[contexts.items.len - 1];
        const left_conts = src.readSpan(left.inner(), 1, 1) catch return;
        if (left_conts.line() + left_conts.lineCount() >= right_conts.line()) {
            const left_end = left.offset() + left.len();
            const right_end = right.offset() + right.len();
            const new_end = @max(left_end, right_end);
            const new_span = span.LabeledSpan.new(left.label(), left.offset(), new_end - left.offset());
            _ = src.readSpan(new_span.inner(), 1, 1) catch {
                contexts.append(gpa, right) catch unreachable;
                continue;
            };
            contexts.items[contexts.items.len - 1] = new_span;
            continue;
        }
        contexts.append(gpa, right) catch unreachable;
    }

    for (contexts.items) |ctx| {
        try renderContext(writer, src, &ctx, labels.items);
    }
}

fn lessLabelOffset(_: void, a: span.LabeledSpan, b: span.LabeledSpan) bool {
    return a.offset() < b.offset();
}

fn renderContext(writer: *std.Io.Writer, src: *const source.SourceCode, context: *const span.LabeledSpan, labels: []const span.LabeledSpan) std.Io.Writer.Error!void {
    const gpa = std.heap.smp_allocator;
    const line_result = getLines(gpa, src, context.inner()) catch return;
    const contents = line_result.@"0";
    var lines = line_result.@"1";
    defer lines.deinit(gpa);

    const primary_label = findPrimaryInContext(context, labels);
    const primary_contents = if (primary_label) |label|
        src.readSpan(label.inner(), 0, 0) catch contents
    else
        contents;

    var fancy: std.ArrayList(FancySpan) = .empty;
    defer fancy.deinit(gpa);
    for (labels) |label| {
        fancy.append(gpa, .{ .label = label.label(), .sp = label.inner().* }) catch unreachable;
    }

    var max_gutter: usize = 0;
    for (lines.items) |line| {
        var num: usize = 0;
        for (fancy.items) |hl| {
            if (!line.spanLineOnly(&hl) and line.spanAppliesGutter(&hl)) num += 1;
        }
        max_gutter = @max(max_gutter, num);
    }

    const linum_width = if (lines.items.len == 0) 1 else digits(lines.items[lines.items.len - 1].line_number);
    try writeSpaces(writer, linum_width + 2);
    try writer.print("{s}{s}", .{ chars.ltop, chars.hbar });
    if (primary_contents.name()) |name| {
        try writer.print("[{s}:{d}:{d}]\n", .{ name, primary_contents.line() + 1, primary_contents.column() + 1 });
    } else if (lines.items.len > 1) {
        try writer.print("[{d}:{d}]\n", .{ primary_contents.line() + 1, primary_contents.column() + 1 });
    } else {
        try writer.print("{s}{s}{s}\n", .{ chars.hbar, chars.hbar, chars.hbar });
    }

    for (lines.items) |line| {
        try writeLinum(writer, linum_width, line.line_number);
        try renderLineGutter(writer, max_gutter, &line, fancy.items);
        try renderLineText(writer, line.text);

        var single: std.ArrayList(*const FancySpan) = .empty;
        defer single.deinit(gpa);
        var multi: std.ArrayList(*const FancySpan) = .empty;
        defer multi.deinit(gpa);
        for (fancy.items) |*hl| {
            if (!line.spanApplies(hl)) continue;
            if (line.spanLineOnly(hl)) {
                single.append(gpa, hl) catch unreachable;
            } else {
                multi.append(gpa, hl) catch unreachable;
            }
        }
        if (single.items.len > 0) {
            try writeNoLinum(writer, linum_width);
            try renderHighlightGutter(writer, max_gutter, &line, fancy.items, .single_line);
            try renderSingleLineHighlights(writer, &line, linum_width, max_gutter, single.items, fancy.items);
        }
        for (multi.items) |hl| {
            if (hl.label != null and line.spanEnds(hl) and !line.spanStarts(hl)) {
                try renderMultiLineEnd(writer, fancy.items, max_gutter, linum_width, &line, hl);
            }
        }
    }

    try writeSpaces(writer, linum_width + 2);
    try writer.print("{s}{s}{s}{s}{s}\n", .{ chars.lbot, chars.hbar, chars.hbar, chars.hbar, chars.hbar });
}

fn findPrimaryInContext(context: *const span.LabeledSpan, labels: []const span.LabeledSpan) ?span.LabeledSpan {
    var first: ?span.LabeledSpan = null;
    for (labels) |label| {
        const ctx_start = context.offset();
        const ctx_end = context.offset() + context.len();
        const label_start = label.offset();
        const label_end = label.offset() + label.len();
        if (ctx_start <= label_start and label_end <= ctx_end) {
            if (first == null) first = label;
            if (label.primary()) return label;
        }
    }
    return first;
}

fn writeLinum(writer: *std.Io.Writer, width: usize, linum: usize) std.Io.Writer.Error!void {
    try writer.writeByte(' ');
    try writePaddedUsize(writer, linum, width);
    try writer.print(" {s} ", .{chars.vbar});
}

fn writeNoLinum(writer: *std.Io.Writer, width: usize) std.Io.Writer.Error!void {
    try writer.writeByte(' ');
    try writeSpaces(writer, width);
    try writer.print(" {s} ", .{chars.vbar_break});
}

fn writePaddedUsize(writer: *std.Io.Writer, value: usize, width: usize) std.Io.Writer.Error!void {
    const d = digits(value);
    if (d < width) try writeSpaces(writer, width - d);
    try writer.print("{d}", .{value});
}

fn renderLineText(writer: *std.Io.Writer, text: []const u8) std.Io.Writer.Error!void {
    for (text) |c| {
        if (c == '\t') {
            try writeSpaces(writer, 4);
        } else {
            try writer.writeByte(c);
        }
    }
    try writer.writeByte('\n');
}

fn renderLineGutter(writer: *std.Io.Writer, max_gutter: usize, line: *const Line, highlights: []const FancySpan) std.Io.Writer.Error!void {
    if (max_gutter == 0) return;
    var gutter_cols: usize = 0;
    var arrow = false;
    var i: usize = 0;
    for (highlights) |hl| {
        if (!line.spanAppliesGutter(&hl)) continue;
        if (line.spanStarts(&hl)) {
            try writer.writeAll(chars.ltop);
            try repeatStr(writer, chars.hbar, max_gutter - i);
            try writer.writeAll(chars.rarrow);
            gutter_cols += 2 + max_gutter - i;
            arrow = true;
            break;
        } else if (line.spanEnds(&hl)) {
            try writer.writeAll(if (hl.label != null) chars.lcross else chars.lbot);
            try repeatStr(writer, chars.hbar, max_gutter - i);
            try writer.writeAll(chars.rarrow);
            gutter_cols += 2 + max_gutter - i;
            arrow = true;
            break;
        } else if (line.spanFlyby(&hl)) {
            try writer.writeAll(chars.vbar);
            gutter_cols += 1;
        } else {
            try writer.writeByte(' ');
            gutter_cols += 1;
        }
        i += 1;
    }
    const spaces = (if (arrow) @as(usize, 1) else @as(usize, 3)) + (max_gutter -| gutter_cols);
    try writeSpaces(writer, spaces);
}

fn renderHighlightGutter(writer: *std.Io.Writer, max_gutter: usize, line: *const Line, highlights: []const FancySpan, mode: LabelRenderMode) std.Io.Writer.Error!void {
    if (max_gutter == 0) return;
    var gutter_cols: usize = 0;
    var i: usize = 0;
    for (highlights) |hl| {
        if (!line.spanAppliesGutter(&hl)) continue;
        if (!line.spanLineOnly(&hl) and line.spanEnds(&hl)) {
            if (mode == .multi_line_rest) {
                const horizontal_space = max_gutter - i + 2;
                try writeSpaces(writer, horizontal_space);
                gutter_cols += horizontal_space + 1;
            } else {
                const num_repeat = max_gutter - i + 2;
                try writer.writeAll(chars.lbot);
                try repeatStr(writer, chars.hbar, num_repeat - if (mode == .multi_line_first) @as(usize, 1) else @as(usize, 0));
                gutter_cols += num_repeat + 1;
            }
            break;
        } else {
            try writer.writeAll(chars.vbar);
            gutter_cols += 1;
        }
        i += 1;
    }
    try writeSpaces(writer, (max_gutter + 3) -| gutter_cols);
}

fn renderSingleLineHighlights(writer: *std.Io.Writer, line: *const Line, linum_width: usize, max_gutter: usize, single_liners: []const *const FancySpan, all: []const FancySpan) std.Io.Writer.Error!void {
    const gpa = std.heap.smp_allocator;
    var offsets: std.ArrayList(LabelOffset) = .empty;
    defer offsets.deinit(gpa);

    var highest: usize = 0;
    for (single_liners) |hl| {
        const byte_start = hl.offset();
        const byte_end = hl.offset() + hl.len();
        const start = @max(visualOffset(line, byte_start, true), highest);
        const end = if (hl.len() == 0) start + 1 else @max(visualOffset(line, byte_end, false), start + 1);
        const vbar_offset = (start + end) / 2;
        try writeSpaces(writer, start - highest);
        try repeatStr(writer, chars.underline, vbar_offset - start);
        if (hl.len() == 0) {
            try writer.writeAll(chars.uarrow);
        } else if (hl.label != null) {
            try writer.writeAll(chars.underbar);
        } else {
            try writer.writeAll(chars.underline);
        }
        try repeatStr(writer, chars.underline, end - vbar_offset - 1);
        highest = @max(highest, end);
        offsets.append(gpa, .{ .hl = hl, .offset = vbar_offset }) catch unreachable;
    }
    try writer.writeByte('\n');

    var idx = single_liners.len;
    while (idx > 0) {
        idx -= 1;
        const hl = single_liners[idx];
        if (hl.label) |label| {
            var parts = std.mem.splitScalar(u8, label, '\n');
            var first = true;
            while (parts.next()) |part| {
                try writeLabelText(writer, line, linum_width, max_gutter, all, offsets.items, hl, part, if (first) .single_line else .multi_line_rest);
                first = false;
            }
        }
    }
}

fn writeLabelText(writer: *std.Io.Writer, line: *const Line, linum_width: usize, max_gutter: usize, all: []const FancySpan, offsets: []const LabelOffset, hl: *const FancySpan, label: []const u8, mode: LabelRenderMode) std.Io.Writer.Error!void {
    try writeNoLinum(writer, linum_width);
    try renderHighlightGutter(writer, max_gutter, line, all, .single_line);
    var curr_offset: usize = 1;
    for (offsets) |item| {
        while (curr_offset < item.offset + 1) {
            try writer.writeByte(' ');
            curr_offset += 1;
        }
        if (item.hl != hl) {
            try writer.writeAll(chars.vbar);
            curr_offset += 1;
        } else {
            switch (mode) {
                .single_line => try writer.print("{s}{s}{s} {s}\n", .{ chars.lbot, chars.hbar, chars.hbar, label }),
                .multi_line_first => try writer.print("{s}{s}{s} {s}\n", .{ chars.lbot, chars.hbar, chars.rcross, label }),
                .multi_line_rest => try writer.print("  {s} {s}\n", .{ chars.vbar, label }),
            }
            break;
        }
    }
}

fn renderMultiLineEnd(writer: *std.Io.Writer, all: []const FancySpan, max_gutter: usize, linum_width: usize, line: *const Line, label: *const FancySpan) std.Io.Writer.Error!void {
    try writeNoLinum(writer, linum_width);
    if (label.label) |text| {
        var parts = std.mem.splitScalar(u8, text, '\n');
        const first = parts.next() orelse "";
        if (parts.peek() == null) {
            try renderHighlightGutter(writer, max_gutter, line, all, .single_line);
            try writer.print("{s} {s}\n", .{ chars.hbar, first });
        } else {
            try renderHighlightGutter(writer, max_gutter, line, all, .multi_line_first);
            try writer.print("{s} {s}\n", .{ chars.rcross, first });
            while (parts.next()) |part| {
                try writeNoLinum(writer, linum_width);
                try renderHighlightGutter(writer, max_gutter, line, all, .multi_line_rest);
                try writer.print("{s} {s}\n", .{ chars.vbar, part });
            }
        }
    } else {
        try renderHighlightGutter(writer, max_gutter, line, all, .single_line);
        try writer.print("{s}\n", .{chars.hbar});
    }
}

fn repeatStr(writer: *std.Io.Writer, text: []const u8, count: usize) std.Io.Writer.Error!void {
    var i: usize = 0;
    while (i < count) : (i += 1) try writer.writeAll(text);
}

fn writeSpaces(writer: *std.Io.Writer, count: usize) std.Io.Writer.Error!void {
    var i: usize = 0;
    while (i < count) : (i += 1) try writer.writeByte(' ');
}

fn visualOffset(line: *const Line, offset: usize, start: bool) usize {
    var text_index = offset - line.offset;
    while (text_index <= line.text.len and !std.unicode.utf8ValidateSlice(line.text[0..@min(text_index, line.text.len)])) {
        if (start) text_index -= 1 else text_index += 1;
    }
    if (text_index > line.text.len) return visualWidth(line.text) + 1;
    return visualWidth(line.text[0..text_index]);
}

fn visualWidth(text: []const u8) usize {
    var width: usize = 0;
    for (text) |c| {
        width += if (c == '\t') 4 - (width % 4) else 1;
    }
    return width;
}

fn getLines(gpa: std.mem.Allocator, src: *const source.SourceCode, context_span: *const span.SourceSpan) !struct { span.SpanContents, std.ArrayList(Line) } {
    const context_data = try src.readSpan(context_span, 1, 1);
    const context = context_data.data();
    var line = context_data.line();
    var column = context_data.column();
    var offset = context_data.span().offset;
    var line_offset = offset;
    var line_start: usize = 0;
    var lines: std.ArrayList(Line) = .empty;
    var i: usize = 0;
    while (i < context.len) {
        const c = context[i];
        offset += 1;
        var at_end_of_file = false;
        switch (c) {
            '\r' => {
                if (i + 1 < context.len and context[i + 1] == '\n') {
                    i += 1;
                    offset += 1;
                    line += 1;
                    column = 0;
                } else {
                    column += 1;
                }
                at_end_of_file = i + 1 >= context.len;
            },
            '\n' => {
                at_end_of_file = i + 1 >= context.len;
                line += 1;
                column = 0;
            },
            else => column += 1,
        }
        if (i + 1 >= context.len and !at_end_of_file) line += 1;
        if (column == 0 or i + 1 >= context.len) {
            const line_end = if (c == '\n' or c == '\r') i else i + 1;
            try lines.append(gpa, .{
                .line_number = line,
                .offset = line_offset,
                .length = offset - line_offset,
                .text = context[line_start..line_end],
            });
            line_start = i + 1;
            line_offset = offset;
        }
        i += 1;
    }
    return .{ context_data, lines };
}

fn digits(value: usize) usize {
    var n = value;
    var d: usize = 1;
    while (n >= 10) {
        n /= 10;
        d += 1;
    }
    return d;
}

const LabelRenderMode = enum {
    single_line,
    multi_line_first,
    multi_line_rest,
};

const LabelOffset = struct {
    hl: *const FancySpan,
    offset: usize,
};

const FancySpan = struct {
    label: ?[]const u8,
    sp: span.SourceSpan,

    fn offset(self: *const FancySpan) usize {
        return self.sp.offset;
    }

    fn len(self: *const FancySpan) usize {
        return self.sp.length;
    }
};

const Line = struct {
    line_number: usize,
    offset: usize,
    length: usize,
    text: []const u8,

    fn spanLineOnly(self: *const Line, sp: *const FancySpan) bool {
        return sp.offset() >= self.offset and sp.offset() + sp.len() <= self.offset + self.length;
    }

    fn spanApplies(self: *const Line, sp: *const FancySpan) bool {
        const span_len = if (sp.len() == 0) 1 else sp.len();
        return (sp.offset() >= self.offset and sp.offset() < self.offset + self.length) or
            (sp.offset() < self.offset and sp.offset() + span_len > self.offset + self.length) or
            (sp.offset() + span_len > self.offset and sp.offset() + span_len <= self.offset + self.length);
    }

    fn spanAppliesGutter(self: *const Line, sp: *const FancySpan) bool {
        const span_len = if (sp.len() == 0) 1 else sp.len();
        return self.spanApplies(sp) and
            !((sp.offset() >= self.offset and sp.offset() < self.offset + self.length) and
                (sp.offset() + span_len > self.offset and sp.offset() + span_len <= self.offset + self.length));
    }

    fn spanFlyby(self: *const Line, sp: *const FancySpan) bool {
        return sp.offset() < self.offset and sp.offset() + sp.len() > self.offset + self.length;
    }

    fn spanStarts(self: *const Line, sp: *const FancySpan) bool {
        return sp.offset() >= self.offset;
    }

    fn spanEnds(self: *const Line, sp: *const FancySpan) bool {
        return sp.offset() + sp.len() >= self.offset and sp.offset() + sp.len() <= self.offset + self.length;
    }
};
