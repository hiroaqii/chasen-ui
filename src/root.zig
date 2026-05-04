const std = @import("std");
const chasen = @import("chasen");

test "chasen-dogu imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}
