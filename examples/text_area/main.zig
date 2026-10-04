const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows TextArea as an owned multi-line input component.
//
// TextArea owns the editable buffer and cursor. The app still owns the meaning
// of the text, save/submit policy, validation, and any scrolling or wrapping
// decisions around the visible rectangle.
const App = struct {
    allocator: ?std.mem.Allocator = null,
    area: ?ui.TextArea = null,
    last_saved: ?[]const u8 = null,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        area: ui.TextArea.Msg,
        save,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();

        // Components that own memory should use the app allocator from Ctx.
        // This keeps their lifetime tied to the app, not to a render frame.
        self.area = try ui.TextArea.init(self.allocator.?, .{
            .value = "Board game notes:\n- teach rules before setup\n- keep turns short",
            .placeholder = "Write notes...",
        });
    }

    pub fn deinit(self: *App, _: chasen.AppDeinitContext) void {
        self.clearSaved();
        if (self.area) |*area| {
            area.deinit();
            self.area = null;
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches('s', .{ .ctrl = true })) return .save;
            },
            else => {},
        }

        // Component-level editing is delegated to TextArea, then wrapped in the
        // app's Msg type so update remains the only mutation point.
        if (self.area) |*area| {
            if (area.handleEvent(event)) |msg| {
                return .{ .area = msg };
            }
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .area => |area_msg| {
                // Component messages still pass through the app update. This
                // keeps mutation centralized and lets the app layer observe or
                // reject edits before delegating to TextArea.
                self.clearSaved();
                try self.area.?.update(area_msg);
            },
            .save => {
                if (self.area) |*area| {
                    try self.setSaved(area.text());
                }
            },
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const size = sfc.size();
        const width = @min(size.width, 64);
        const height = @min(size.height -| @min(size.height, 8), 8);

        _ = sfc.borrowTextAt(0, 0, "TextArea Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Enter: newline  Ctrl+S: save  Esc: quit", .{ .fg = .gray });

        if (self.area) |*area| {
            // TextArea draws explicit lines inside the app-provided rectangle
            // and accepts an app-owned scroll offset. This example derives the
            // offset from the cursor so repeated Enter presses keep the cursor
            // visible without giving TextArea internal scroll state.
            const scroll_line = scrollLineForCursor(area.cursorLine(), height);
            var text_area = sfc.child(.{ .col = 0, .row = 3, .width = width, .height = height });
            area.view(&text_area, .{
                .scroll_line = scroll_line,
            });

            const meta_row = 4 + height;
            _ = sfc.borrowTextAt(0, meta_row, "Cursor:", .{ .fg = .gray });
            _ = try sfc.printAt(8, meta_row, .{}, "line {d}, chars {d}, cells {d}  visible {d}-{d}", .{
                area.cursorLine() + 1,
                area.cursorGraphemeColumn(),
                area.cursorColumn(),
                scroll_line + 1,
                scroll_line + @as(usize, height),
            });
        }

        if (self.last_saved) |saved| {
            const saved_row = 6 + height;
            _ = sfc.borrowTextAt(0, saved_row, "Saved snapshot:", .{ .fg = .{ .index = 2 } });
            _ = sfc.borrowTextAt(16, saved_row, saved, .{ .fg = .{ .index = 2 } });
        }
    }

    fn setSaved(self: *App, text: []const u8) !void {
        self.clearSaved();
        self.last_saved = try self.allocator.?.dupe(u8, text);
    }

    fn clearSaved(self: *App) void {
        if (self.last_saved) |saved| {
            self.allocator.?.free(saved);
            self.last_saved = null;
        }
    }
};

fn scrollLineForCursor(cursor_line: usize, height: u16) usize {
    if (height == 0) return 0;
    const visible_height: usize = height;
    if (cursor_line < visible_height) return 0;
    return cursor_line - visible_height + 1;
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
