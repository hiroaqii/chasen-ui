const std = @import("std");
const chasen = @import("chasen");

pub const text_input = @import("text_input.zig");
pub const TextInput = text_input.TextInput;

pub const checkbox = @import("checkbox.zig");
pub const Checkbox = checkbox.Checkbox;

test "chasen-ui imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}

test {
    std.testing.refAllDecls(@This());
}
