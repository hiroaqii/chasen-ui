const std = @import("std");
const chasen = @import("chasen");

pub const layout = @import("layout.zig");

pub const text_input = @import("text_input.zig");
pub const TextInput = text_input.TextInput;

pub const password_input = @import("password_input.zig");
pub const PasswordInput = password_input.PasswordInput;

pub const number_input = @import("number_input.zig");
pub const NumberInput = number_input.NumberInput;

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

pub const spinner = @import("spinner.zig");
pub const Spinner = spinner.Spinner;

pub const progress_bar = @import("progress_bar.zig");
pub const ProgressBar = progress_bar.ProgressBar;

pub const rating = @import("rating.zig");
pub const Rating = rating.Rating;

pub const badge = @import("badge.zig");
pub const Badge = badge.Badge;

pub const alert = @import("alert.zig");
pub const Alert = alert.Alert;

pub const divider = @import("divider.zig");
pub const Divider = divider.Divider;

pub const label = @import("label.zig");
pub const Label = label.Label;

pub const paragraph = @import("paragraph.zig");
pub const Paragraph = paragraph.Paragraph;

pub const status_line = @import("status_line.zig");
pub const StatusLine = status_line.StatusLine;

pub const select = @import("select.zig");
pub const Select = select.Select;

pub const help = @import("help.zig");
pub const Help = help.Help;

test "chasen-ui imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}

test {
    std.testing.refAllDecls(@This());
}
