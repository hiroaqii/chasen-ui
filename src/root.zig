const std = @import("std");
const chasen = @import("chasen");

pub const layout = @import("layout.zig");

pub const text_projection = @import("text/projection.zig");

pub const viewport = @import("viewport.zig");
pub const Viewport = viewport.Viewport;

pub const text_input = @import("input/text_input.zig");
pub const TextInput = text_input.TextInput;

pub const text_area = @import("input/text_area.zig");
pub const TextArea = text_area.TextArea;

pub const form_field = @import("input/form_field.zig");
pub const FormField = form_field.FormField;

pub const password_input = @import("input/password_input.zig");
pub const PasswordInput = password_input.PasswordInput;

pub const number_input = @import("input/number_input.zig");
pub const NumberInput = number_input.NumberInput;

pub const checkbox = @import("input/checkbox.zig");
pub const Checkbox = checkbox.Checkbox;

pub const radio = @import("input/radio.zig");
pub const Radio = radio.Radio;

pub const button = @import("input/button.zig");
pub const Button = button.Button;

pub const focus_list = @import("navigation/focus_list.zig");
pub const FocusList = focus_list.FocusList;

pub const list = @import("navigation/list.zig");
pub const List = list.List;

pub const list_view = @import("navigation/list_view.zig");
pub const ListViewport = list_view.ListViewport;

pub const block_viewport = @import("navigation/block_viewport.zig");
pub const BlockViewport = block_viewport.BlockViewport;

pub const list_filter = @import("navigation/list_filter.zig");
pub const ListFilter = list_filter.ListFilter;

pub const column_list = @import("navigation/column_list.zig");
pub const ColumnList = column_list.ColumnList;

pub const selectable_list = @import("navigation/selectable_list.zig");
pub const SelectableList = selectable_list.SelectableList;

pub const multi_select_list = @import("navigation/multi_select_list.zig");
pub const MultiSelectList = multi_select_list.MultiSelectList;

pub const menu = @import("navigation/menu.zig");
pub const Menu = menu.Menu;

pub const tabs = @import("navigation/tabs.zig");
pub const Tabs = tabs.Tabs;

pub const breadcrumbs = @import("navigation/breadcrumbs.zig");
pub const Breadcrumbs = breadcrumbs.Breadcrumbs;

pub const box = @import("structure/box.zig");
pub const Box = box.Box;

pub const panel = @import("structure/panel.zig");
pub const Panel = panel.Panel;

pub const modal = @import("structure/modal.zig");
pub const Modal = modal.Modal;

pub const overlay = @import("structure/overlay.zig");
pub const Overlay = overlay.Overlay;

pub const table = @import("structure/table.zig");
pub const Table = table.Table;

pub const tree = @import("structure/tree.zig");
pub const Tree = tree.Tree;

pub const accordion = @import("navigation/accordion.zig");
pub const Accordion = accordion.Accordion;

pub const spinner = @import("display/spinner.zig");
pub const Spinner = spinner.Spinner;

pub const progress_bar = @import("display/progress_bar.zig");
pub const ProgressBar = progress_bar.ProgressBar;

pub const gauge = @import("display/gauge.zig");
pub const Gauge = gauge.Gauge;

pub const toast = @import("display/toast.zig");
pub const Toast = toast.Toast;

pub const rating = @import("display/rating.zig");
pub const Rating = rating.Rating;

pub const badge = @import("display/badge.zig");
pub const Badge = badge.Badge;

pub const alert = @import("display/alert.zig");
pub const Alert = alert.Alert;

pub const divider = @import("display/divider.zig");
pub const Divider = divider.Divider;

pub const label = @import("display/label.zig");
pub const Label = label.Label;

pub const paragraph = @import("display/paragraph.zig");
pub const Paragraph = paragraph.Paragraph;

pub const status_line = @import("display/status_line.zig");
pub const StatusLine = status_line.StatusLine;

pub const key_hint = @import("display/key_hint.zig");

pub const select = @import("input/select.zig");
pub const Select = select.Select;

pub const message_block = @import("display/message_block.zig");
pub const MessageBlock = message_block.MessageBlock;

test "chasen-ui imports chasen core" {
    try std.testing.expect(@hasDecl(chasen, "Surface"));
    try std.testing.expect(@hasDecl(chasen, "Ctx"));
}

test {
    std.testing.refAllDecls(@This());
}
