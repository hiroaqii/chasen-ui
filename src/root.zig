const std = @import("std");
const chasen = @import("chasen");

pub const text_input = @import("text_input.zig");
pub const TextInput = text_input.TextInput;

pub const checkbox = @import("checkbox.zig");
pub const Checkbox = checkbox.Checkbox;

pub const radio = @import("radio.zig");
pub const Radio = radio.Radio;

pub const button = @import("button.zig");
pub const Button = button.Button;

pub const focus_list = @import("focus_list.zig");
pub const FocusList = focus_list.FocusList;

pub const list = @import("list.zig");
pub const List = list.List;

test "chasen-ui imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}

test {
    std.testing.refAllDecls(@This());
}
