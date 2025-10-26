const UITextNode = @import("ui-text-node.zig").UITextNode;
const UIElement = @import("ui-element.zig").UIElement;

pub const UINode = union(enum) {
    text: UITextNode,
    element: UIElement,

    pub fn createElement() !*UIElement {
        return try UIElement.init();
    }
};
