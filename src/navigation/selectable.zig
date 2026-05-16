const chasen = @import("chasen");

/// Return whether a key should activate a selectable component.
///
/// Enter and Space activate by default. Command-style modified Space is
/// ignored so applications can reserve those bindings for app-level shortcuts.
pub fn isActivationKey(key: chasen.Key) bool {
    if (key.matches(chasen.Key.enter, .{})) return true;
    if (key.mods.ctrl or key.mods.alt or key.mods.super or key.mods.hyper or key.mods.meta) {
        return false;
    }
    return key.matches(chasen.Key.space, .{});
}
