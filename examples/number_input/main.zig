const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

// This example shows the NumberInput component.
//
// NumberInput owns editable text and filters inserted characters to an integer
// shape. The app still owns range validation, submit behavior, and what the
// number means.
const App = struct {
    allocator: ?std.mem.Allocator = null,
    quantity: ?ui.NumberInput = null,
    status: ?[]const u8 = null,

    pub const Msg = union(enum) {
        pub const undelivered_policy = .plain;

        quantity: ui.NumberInput.Msg,
        quit,
    };

    pub fn init(self: *App, ctx: *chasen.Ctx(Msg)) !void {
        self.allocator = ctx.allocator();
        self.quantity = try ui.NumberInput.init(self.allocator.?, .{
            .placeholder = "Quantity",
            .allow_negative = false,
        });
    }

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        // App-level shortcuts get first chance. Escape quits instead of being
        // forwarded to the NumberInput.
        switch (event) {
            .key_press => |key| {
                if (key.matches(chasen.Key.escape, .{})) return .quit;
            },
            else => {},
        }

        // Component-level key handling is delegated to NumberInput, then
        // wrapped in the app's Msg type.
        if (self.quantity) |*quantity| {
            if (quantity.handleEvent(event)) |msg| {
                return .{ .quantity = msg };
            }
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .quantity => |quantity_msg| {
                if (quantity_msg == .submit) {
                    try self.setStatus();
                } else {
                    self.clearStatus();
                    try self.quantity.?.update(quantity_msg);
                }
            },
            .quit => {
                self.clearStatus();
                if (self.quantity) |*quantity| {
                    quantity.deinit();
                    self.quantity = null;
                }
                ctx.quit();
            },
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "NumberInput Example", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Digits only  Enter: submit  Esc: quit", .{ .fg = .gray });

        if (self.quantity) |*quantity| {
            // NumberInput filters inserted characters. The app still decides
            // whether an empty value is valid and how to use the parsed number.
            var quantity_area = sfc.child(.{ .col = 0, .row = 3, .width = 16, .height = 1 });
            quantity.view(&quantity_area, .{});
        }

        if (self.status) |status| {
            _ = sfc.borrowTextAt(0, 5, status, .{ .fg = .{ .index = 2 } });
        }
    }

    fn setStatus(self: *App) !void {
        self.clearStatus();
        if (self.quantity.?.intValue()) |value| {
            self.status = try std.fmt.allocPrint(self.allocator.?, "Submitted quantity: {d}", .{value});
        } else {
            self.status = try std.fmt.allocPrint(self.allocator.?, "Enter a quantity before submitting", .{});
        }
    }

    fn clearStatus(self: *App) void {
        if (self.status) |status| {
            self.allocator.?.free(status);
            self.status = null;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
