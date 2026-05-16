const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const Field = enum {
    username,
    project,

    fn previous(self: Field) Field {
        return switch (self) {
            .username => .username,
            .project => .username,
        };
    }

    fn next(self: Field) Field {
        return switch (self) {
            .username => .project,
            .project => .project,
        };
    }
};

// This example shows FormField as display-only field chrome.
//
// FormField draws label/help/error rows and returns the rectangle where the app
// should draw the actual input. TextInput still owns editing state, while the
// app owns focus routing and validation policy.
const App = struct {
    allocator: ?std.mem.Allocator = null,
    username: ?ui.TextInput = null,
    project: ?ui.TextInput = null,
    username_field: ui.FormField = ui.FormField.init(.{
        .label = "Username",
        .help = "Required for saved settings",
    }),
    project_field: ui.FormField = ui.FormField.init(.{
        .label = "Project",
        .help = "Optional short display name",
    }),
    selected: Field = .username,

    pub const Msg = union(enum) {
        username: ui.TextInput.Msg,
        project: ui.TextInput.Msg,
        move_up,
        move_down,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();
        self.username = try ui.TextInput.init(self.allocator.?, .{
            .placeholder = "required",
        });
        self.project = try ui.TextInput.init(self.allocator.?, .{
            .placeholder = "optional",
        });
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .username => |input_msg| {
                if (input_msg == .submit) {
                    self.selected = self.selected.next();
                } else {
                    try self.username.?.update(input_msg);
                }
            },
            .project => |input_msg| {
                if (input_msg == .submit) {
                    self.selected = self.selected.next();
                } else {
                    try self.project.?.update(input_msg);
                }
            },
            .move_up => self.selected = self.selected.previous(),
            .move_down => self.selected = self.selected.next(),
            .quit => {
                if (self.username) |*username| {
                    username.deinit();
                    self.username = null;
                }
                if (self.project) |*project| {
                    project.deinit();
                    self.project = null;
                }
                ctx.quit();
            },
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "FormField Example - app-owned validation", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Up/Down: fields  Enter: next  Esc: quit", .{ .fg = .gray });

        const username_error: ?[]const u8 = if (self.username) |*username|
            if (username.text().len == 0) "Username is required" else null
        else
            null;

        const username_opts = ui.FormField.ViewOptions{
            .col = 0,
            .row = 3,
            .width = 36,
            .height = 3,
            .required = true,
            .error_text = username_error,
        };
        self.username_field.view(sfc, username_opts);
        const username_rect = self.username_field.contentRect(sfc, username_opts);
        if (self.username) |*username| {
            username.view(sfc, .{
                .col = username_rect.col,
                .row = username_rect.row,
                .width = username_rect.width,
                .show_cursor = self.selected == .username,
            });
        }

        const project_opts = ui.FormField.ViewOptions{
            .col = 0,
            .row = 7,
            .width = 36,
            .height = 3,
        };
        self.project_field.view(sfc, project_opts);
        const project_rect = self.project_field.contentRect(sfc, project_opts);
        if (self.project) |*project| {
            project.view(sfc, .{
                .col = project_rect.col,
                .row = project_rect.row,
                .width = project_rect.width,
                .show_cursor = self.selected == .project,
            });
        }

        _ = sfc.textAt(0, 12, "FormField owns chrome only; submit/save policy stays in app.", .{ .dim = true });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
                if (key.matches(chasen.Key.up, .{})) return .move_up;
                if (key.matches(chasen.Key.down, .{})) return .move_down;
            },
            else => {},
        }

        return switch (self.selected) {
            .username => if (self.username) |*username|
                if (username.handleEvent(event)) |msg| .{ .username = msg } else null
            else
                null,
            .project => if (self.project) |*project|
                if (project.handleEvent(event)) |msg| .{ .project = msg } else null
            else
                null,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
