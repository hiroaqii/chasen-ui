const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the PasswordInput component.
//
// PasswordInput owns editable text and local cursor state, but it never draws
// the real value. The app still owns submit policy, validation, and when the
// secret should be cleared.
const App = struct {
    allocator: ?std.mem.Allocator = null,
    password: ?ui.PasswordInput = null,
    status: ?[]const u8 = null,

    pub const Msg = union(enum) {
        password: ui.PasswordInput.Msg,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();
        self.password = try ui.PasswordInput.init(self.allocator.?, .{
            .placeholder = "Password",
        });
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .password => |password_msg| {
                if (password_msg == .submit) {
                    try self.setStatus(self.password.?.text().len);
                    try self.password.?.update(.clear);
                } else {
                    self.clearStatus();
                    try self.password.?.update(password_msg);
                }
            },
            .quit => {
                self.clearStatus();
                if (self.password) |*password| {
                    password.deinit();
                    self.password = null;
                }
                ctx.quit();
            },
        }
    }

    fn setStatus(self: *App, byte_len: usize) !void {
        self.clearStatus();
        self.status = try std.fmt.allocPrint(self.allocator.?, "Submitted secret with {d} bytes", .{byte_len});
    }

    fn clearStatus(self: *App) void {
        if (self.status) |status| {
            self.allocator.?.free(status);
            self.status = null;
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.textAt(0, 0, "PasswordInput Example", .{ .bold = true });
        _ = sfc.textAt(0, 1, "Enter: submit  Esc: quit", .{ .fg = .gray });

        if (self.password) |*password| {
            // PasswordInput handles editing like TextInput, but view draws mask
            // glyphs so the app never needs to render the secret itself.
            password.view(sfc, .{
                .col = 0,
                .row = 3,
                .width = 32,
            });
        }

        if (self.status) |status| {
            _ = sfc.textAt(0, 5, status, .{ .fg = .{ .index = 2 } });
        }
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts get first chance. Escape quits instead of being
        // forwarded to the PasswordInput.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
            },
            else => {},
        }

        // Component-level key handling is delegated to PasswordInput, then
        // wrapped in the app's Msg type.
        if (self.password) |*password| {
            if (password.handleEvent(event)) |msg| {
                return .{ .password = msg };
            }
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
