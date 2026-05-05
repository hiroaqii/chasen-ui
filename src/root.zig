const std = @import("std");
const chasen = @import("chasen");

pub const text_input = @import("text_input.zig");
pub const TextInput = text_input.TextInput;

pub const checkbox = @import("checkbox.zig");
pub const Checkbox = checkbox.Checkbox;

pub const focus_list = @import("focus_list.zig");
pub const FocusList = focus_list.FocusList;

test "chasen-ui imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}

test {
    std.testing.refAllDecls(@This());
}
