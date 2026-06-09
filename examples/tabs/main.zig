const std = @import("std");
const chasen = @import("chasen");
const ui = @import("chasen_ui");

const tab_items = [_][]const u8{
    "Overview",
    "Details",
    "Logs",
};

// This example shows Tabs with local focus and active tab state.
//
// Tabs owns which tab is focused and active. The app still decides what each
// active tab means by rendering the matching panel content below.
const App = struct {
    tabs: ui.Tabs = ui.Tabs.init(.{ .items = &tab_items }),

    pub const Msg = union(enum) {
        tabs: ui.Tabs.Msg,
        quit,
    };

    pub fn handleEvent(self: *const App, event: chasen.Event) ?Msg {
        switch (event) {
            .key_press => |key| if (key.matches(chasen.Key.escape, .{})) return .quit,
            else => {},
        }

        // App-level shortcuts get first chance. Remaining events are delegated
        // to Tabs and wrapped in the app's Msg type.
        if (self.tabs.handleEvent(event)) |msg| {
            return .{ .tabs = msg };
        }
        return null;
    }

    pub fn update(self: *App, msg: Msg, ctx: *chasen.Ctx(Msg)) !void {
        switch (msg) {
            .tabs => |tabs_msg| self.tabs.update(tabs_msg),
            .quit => ctx.quit(),
        }
    }

    pub fn view(self: *const App, sfc: *chasen.Surface) !void {
        _ = sfc.borrowTextAt(0, 0, "Tabs Example - component-owned active tab", .{ .bold = true });
        _ = sfc.borrowTextAt(0, 1, "Left/Right: focus tab  Enter/Space: activate  Esc: quit", .{ .fg = .gray });

        // Tabs stores focus and active index locally. The app reads activeIndex
        // and decides which panel content belongs below the tab strip.
        var tabs_area = sfc.child(.{ .col = 0, .row = 3, .width = 46, .height = 1 });
        self.tabs.view(&tabs_area, .{
            .focused_style = .{ .bold = true },
            .active_style = .{ .fg = .{ .index = 2 } },
            .focused_active_style = .{ .bold = true, .fg = .{ .index = 2 } },
        });

        _ = sfc.borrowTextAt(0, 5, "Panel", .{ .bold = true, .fg = .{ .index = 2 } });
        switch (self.tabs.activeIndex()) {
            0 => {
                _ = sfc.borrowTextAt(0, 6, "System health: nominal", .{});
                _ = sfc.borrowTextAt(0, 7, "Open work items: 4", .{});
            },
            1 => {
                _ = sfc.borrowTextAt(0, 6, "Owner: Platform", .{});
                _ = sfc.borrowTextAt(0, 7, "Updated: today", .{});
            },
            2 => {
                _ = sfc.borrowTextAt(0, 6, "09:30 build passed", .{});
                _ = sfc.borrowTextAt(0, 7, "10:15 review requested", .{});
            },
            else => {},
        }

        _ = sfc.borrowTextAt(0, 10, "Tabs owns focus and active index", .{ .dim = true });
        _ = sfc.borrowTextAt(0, 11, "Panel meaning stays in app", .{ .dim = true });
    }
};

pub fn main(init: std.process.Init) !void {
    try chasen.run(init, App{});
}
