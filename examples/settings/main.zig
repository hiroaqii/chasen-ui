const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows how to combine TextInput and Checkbox components in one
// app while keeping focus/navigation state in the app model.
const Field = enum {
    username,
    notifications,
    compact_layout,

    fn previous(self: Field) Field {
        return switch (self) {
            .username => .username,
            .notifications => .username,
            .compact_layout => .notifications,
        };
    }

    fn next(self: Field) Field {
        return switch (self) {
            .username => .notifications,
            .notifications => .compact_layout,
            .compact_layout => .compact_layout,
        };
    }
};

const App = struct {
    allocator: ?std.mem.Allocator = null,
    username: ?ui.TextInput = null,
    notifications: ui.Checkbox = ui.Checkbox.init(.{
        .label = "Enable notifications",
    }),
    compact_layout: ui.Checkbox = ui.Checkbox.init(.{
        .label = "Use compact layout",
    }),
    selected: Field = .username,
    saved: ?[]const u8 = null,

    pub const Msg = union(enum) {
        username: ui.TextInput.Msg,
        notifications: ui.Checkbox.Msg,
        compact_layout: ui.Checkbox.Msg,
        move_up,
        move_down,
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
                    try self.saveSummary();
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
            .move_up => self.selected = self.selected.previous(),
            .move_down => self.selected = self.selected.next(),
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

    fn clearSaved(self: *App) void {
        if (self.saved) |saved| {
            self.allocator.?.free(saved);
            self.saved = null;
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "Settings Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: move  Enter: action  Space: checkbox toggle  Esc: quit", .{ .fg = .gray });

        _ = sfc.textAt(0, 3, "Username", .{ .fg = .gray });
        if (self.username) |*username| {
            username.view(sfc, .{
                .col = 16,
                .row = 3,
                .width = 32,
                .show_cursor = self.selected == .username,
            });
        }

        self.notifications.view(sfc, .{
            .col = 0,
            .row = 5,
            .width = 48,
            .show_cursor = self.selected == .notifications,
        });
        self.compact_layout.view(sfc, .{
            .col = 0,
            .row = 6,
            .width = 48,
            .show_cursor = self.selected == .compact_layout,
        });

        if (self.saved) |saved| {
            _ = sfc.textAt(0, 8, saved, .{ .fg = .{ .index = 2 } });
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts and navigation get first chance. Up/Down changes
        // which component receives input.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
            },
            else => {},
        }

        // Component-level key handling is delegated only to the selected
        // component, then wrapped in the app Msg type.
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
        };
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
