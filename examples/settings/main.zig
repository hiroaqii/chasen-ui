const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example combines TextInput, Checkbox, and Button in one small settings
// form. Each component handles its own local event mapping, but the app owns
// the cross-component policy: which field is focused, what Save means, and what
// Reset clears.
//
// The layout is intentionally small: layout helpers calculate a few rectangles
// while the app still decides which component goes in each region. Up/Down
// moves between form rows. Left/Right only moves across the horizontal
// Save/Reset button row.
const Field = enum {
    username,
    notifications,
    compact_layout,
    save,
    reset,

    fn previous(self: Field) Field {
        return switch (self) {
            .username => .username,
            .notifications => .username,
            .compact_layout => .notifications,
            .save => .compact_layout,
            .reset => .compact_layout,
        };
    }

    fn next(self: Field) Field {
        return switch (self) {
            .username => .notifications,
            .notifications => .compact_layout,
            .compact_layout => .save,
            .save => .save,
            .reset => .reset,
        };
    }

    fn left(self: Field) Field {
        return switch (self) {
            .reset => .save,
            else => self,
        };
    }

    fn right(self: Field) Field {
        return switch (self) {
            .save => .reset,
            else => self,
        };
    }
};

const App = struct {
    allocator: ?std.mem.Allocator = null,
    username: ?ui.TextInput = null,
    // Checkbox components own their checked state, but this app decides when
    // they receive input.
    notifications: ui.Checkbox = ui.Checkbox.init(.{
        .label = "Enable notifications",
    }),
    compact_layout: ui.Checkbox = ui.Checkbox.init(.{
        .label = "Use compact layout",
    }),
    // Button components do not own mutable state. They only report `.press`;
    // the app maps that press to Save or Reset behavior.
    save_button: ui.Button = ui.Button.init(.{ .label = "Save" }),
    reset_button: ui.Button = ui.Button.init(.{ .label = "Reset" }),
    selected: Field = .username,
    saved: ?[]const u8 = null,

    pub const Msg = union(enum) {
        username: ui.TextInput.Msg,
        notifications: ui.Checkbox.Msg,
        compact_layout: ui.Checkbox.Msg,
        save: ui.Button.Msg,
        reset: ui.Button.Msg,
        move_up,
        move_down,
        move_left,
        move_right,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();

        // TextInput owns an editable buffer, so it is initialized with the app
        // allocator and deinitialized before shutdown.
        self.username = try ui.TextInput.init(self.allocator.?, .{
            .placeholder = "username",
        });
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .username => |input_msg| {
                if (input_msg == .submit) {
                    self.selected = self.selected.next();
                } else {
                    self.clearSaved();
                    try self.username.?.update(input_msg);
                }
            },
            .notifications => |checkbox_msg| {
                self.clearSaved();
                self.notifications.update(checkbox_msg);
            },
            .compact_layout => |checkbox_msg| {
                self.clearSaved();
                self.compact_layout.update(checkbox_msg);
            },
            .save => |button_msg| switch (button_msg) {
                // Button does not know that this means "save settings"; that
                // policy lives in the app.
                .press => try self.saveSummary(),
            },
            .reset => |button_msg| switch (button_msg) {
                // Reset is also app policy. The Button only produced `.press`.
                .press => try self.resetSettings(),
            },
            .move_up => self.selected = self.selected.previous(),
            .move_down => self.selected = self.selected.next(),
            .move_left => self.selected = self.selected.left(),
            .move_right => self.selected = self.selected.right(),
            .quit => {
                self.clearSaved();
                if (self.username) |*username| {
                    username.deinit();
                    self.username = null;
                }
                ctx.quit();
            },
        }
    }

    fn saveSummary(self: *App) !void {
        self.clearSaved();
        self.saved = try std.fmt.allocPrint(
            self.allocator.?,
            "Saved username='{s}', notifications={s}, compact={s}",
            .{
                self.username.?.text(),
                if (self.notifications.checked()) "yes" else "no",
                if (self.compact_layout.checked()) "yes" else "no",
            },
        );
    }

    fn resetSettings(self: *App) !void {
        self.clearSaved();
        try self.username.?.update(.clear);
        self.notifications.update(.{ .set_checked = false });
        self.compact_layout.update(.{ .set_checked = false });
        self.saved = try std.fmt.allocPrint(self.allocator.?, "Reset settings", .{});
    }

    fn clearSaved(self: *App) void {
        if (self.saved) |saved| {
            self.allocator.?.free(saved);
            self.saved = null;
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        const root = surfaceRect(sfc);
        var page_rows_buf: [4]chasen.Rect = undefined;
        const page_rows = ui.layout.splitVertical(&page_rows_buf, root, &.{
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .fill = 1 },
        });

        const title_row = page_rows[0];
        const help_row = page_rows[1];

        var form_rows_buf: [8]chasen.Rect = undefined;
        const form_rows = ui.layout.splitVertical(&form_rows_buf, page_rows[3], &.{
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
            .{ .length = 1 },
        });
        const username_row = form_rows[0];
        const notifications_row = form_rows[2];
        const compact_row = form_rows[3];
        const buttons_row = form_rows[5];
        const status_row = form_rows[7];

        _ = sfc.textAt(title_row.col, title_row.row, "Settings Example", .{ .bold = true });
        _ = sfc.textAt(help_row.col, help_row.row, "Up/Down: fields  Left/Right: buttons  Enter/Space: action  Esc: quit", .{ .fg = .gray });

        // Labels are drawn by the app. The TextInput only draws the editable
        // one-line input area at the region we assign to it. The row helper
        // keeps label/input column math out of the component.
        var username_cols_buf: [2]chasen.Rect = undefined;
        const username_cols = ui.layout.row(&username_cols_buf, username_row, &.{
            .{ .width = 16, .height = 1 },
            .{ .width = 32, .height = 1 },
        }, .{});
        const username_label = username_cols[0];
        const username_input = username_cols[1];

        _ = sfc.textAt(username_label.col, username_label.row, "Username", .{});
        if (self.username) |*username| {
            var username_area = sfc.child(username_input);
            username.view(&username_area, .{
                .show_cursor = self.selected == .username,
            });
        }

        // Checkbox focus is represented by cursor placement. The app decides
        // which checkbox receives the selected/focused state.
        var notifications_area = sfc.child(.{
            .col = notifications_row.col,
            .row = notifications_row.row,
            .width = 48,
            .height = 1,
        });
        self.notifications.view(&notifications_area, .{
            .show_cursor = self.selected == .notifications,
        });
        var compact_layout_area = sfc.child(.{
            .col = compact_row.col,
            .row = compact_row.row,
            .width = 48,
            .height = 1,
        });
        self.compact_layout.view(&compact_layout_area, .{
            .show_cursor = self.selected == .compact_layout,
        });

        // The buttons are visually horizontal, so Left/Right handles movement
        // within this row while Up/Down enters or leaves the row.
        var button_cols_buf: [2]chasen.Rect = undefined;
        const button_cols = ui.layout.row(&button_cols_buf, buttons_row, &.{
            .{ .width = 8, .height = 1 },
            .{ .width = 9, .height = 1 },
        }, .{ .gap = 2 });
        var save_area = sfc.child(button_cols[0]);
        self.save_button.view(&save_area, .{
            .focused = self.selected == .save,
            .show_cursor = self.selected == .save,
        });
        var reset_area = sfc.child(button_cols[1]);
        self.reset_button.view(&reset_area, .{
            .focused = self.selected == .reset,
            .show_cursor = self.selected == .reset,
        });

        if (self.saved) |saved| {
            _ = sfc.textAt(status_row.col, status_row.row, saved, .{ .fg = .{ .index = 2 } });
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts and navigation get first chance. This keeps
        // cross-component focus policy outside the individual components.
        //
        // Left/Right are reserved for the Save/Reset button row in this
        // example, so they are not forwarded to TextInput for cursor movement.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
                if (key.matches(chasen.Key.left, .{})) return .move_left;
                if (key.matches(chasen.Key.right, .{})) return .move_right;
            },
            else => {},
        }

        // Component-level key handling is delegated only to the selected
        // component, then wrapped in the app Msg type. This is the same
        // handleEvent -> app Msg -> update flow used by the smaller examples.
        return switch (self.selected) {
            .username => if (self.username) |*username|
                if (username.handleEvent(event)) |msg| .{ .username = msg } else null
            else
                null,
            .notifications => if (self.notifications.handleEvent(event)) |msg|
                .{ .notifications = msg }
            else
                null,
            .compact_layout => if (self.compact_layout.handleEvent(event)) |msg|
                .{ .compact_layout = msg }
            else
                null,
            .save => if (self.save_button.handleEvent(event)) |msg|
                .{ .save = msg }
            else
                null,
            .reset => if (self.reset_button.handleEvent(event)) |msg|
                .{ .reset = msg }
            else
                null,
        };
    }
};

fn surfaceRect(surface: *const chasen.Surface) chasen.Rect {
    const size = surface.size();
    return .{
        .col = 0,
        .row = 0,
        .width = size.width,
        .height = size.height,
    };
}

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
