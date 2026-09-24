//! Optional graphics-backed components. The main chasen_ui module stays independent.
pub const LoadingIndicator = @import("display/loading_indicator.zig").LoadingIndicator;

test {
    @import("std").testing.refAllDecls(@This());
}
