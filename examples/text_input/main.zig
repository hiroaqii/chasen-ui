const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows a TextInput component that owns editable text memory.
//
// The app initializes the component with the app allocator, routes input
// events through handleEvent, and decides what submit means in update.
const App = struct {
    allocator: ?std.mem.Allocator = null,
    input: ?ui.TextInput = null,
    last_submitted: ?[]const u8 = null,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        input: ui.TextInput.Msg,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();

        // Components that own memory should use the app allocator from Ctx.
        // This keeps their lifetime tied to the app, not to a render frame.
        self.input = try ui.TextInput.init(self.allocator.?, .{
            .placeholder = "Type something and press Enter",
        });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts get first chance. Escape quits instead of being
        // forwarded to the TextInput.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
            },
            else => {},
        }

        // Component-level key handling is delegated to TextInput, then wrapped
        // in the app's Msg type so update remains the only mutation point.
        if (self.input) |*input| {
            if (input.handleEvent(event)) |msg| {
                return .{ .input = msg };
            }
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .input => |input_msg| {
                // Component messages still pass through the app update.
                // This is where the app can observe submit/change events and
                // update its own model before delegating to the component.
                if (input_msg == .submit) {
                    try self.setSubmitted(self.input.?.text());
                    try self.input.?.update(.clear);
                } else {
                    self.clearSubmitted();
                    try self.input.?.update(input_msg);
                }
            },
            .quit => {
                // Chasen does not currently call an app deinit hook, so this
                // example releases the component before requesting shutdown.
                self.clearSubmitted();
                if (self.input) |*input| {
                    input.deinit();
                    self.input = null;
                }
                ctx.quit();
            },
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "TextInput Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Enter: submit  Esc: quit", .{ .fg = .gray });

        if (self.input) |*input| {
            // view only draws. Input handling and mutation happen in
            // handleEvent/update above.
            var input_area = sfc.child(.{ .col = 0, .row = 3, .width = 40, .height = 1 });
            input.view(&input_area, .{});

            _ = sfc.borrowTextAt(0, 5, "Value:", .{ .fg = .gray });
            _ = sfc.borrowTextAt(7, 5, input.text(), .{});
        }

        if (self.last_submitted) |submitted| {
            _ = sfc.borrowTextAt(0, 7, "Submitted:", .{ .fg = .{ .index = 2 } });
            _ = sfc.borrowTextAt(11, 7, submitted, .{ .fg = .{ .index = 2 } });
        }
    }

    fn setSubmitted(self: *App, text: []const u8) !void {
        self.clearSubmitted();
        self.last_submitted = try self.allocator.?.dupe(u8, text);
    }

    fn clearSubmitted(self: *App) void {
        if (self.last_submitted) |submitted| {
            self.allocator.?.free(submitted);
            self.last_submitted = null;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
