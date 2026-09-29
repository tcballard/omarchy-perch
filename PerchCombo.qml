import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

// Dropdown popups render in the window overlay, outside the masked view.
// Report open/close so the panel can extend its input region and hold hover.
Controls.ComboBox {
    id: root
    property color ink: Color.foreground
    property color surface: Color.background
    signal popupToggled(bool open)
    palette.button: surface
    palette.buttonText: ink
    palette.text: ink
    palette.base: surface
    // A collapsing or disabled view must not leave a detached dropdown behind.
    onEnabledChanged: if (!enabled && popup.visible)
        popup.close()
    Connections {
        target: root.popup
        function onVisibleChanged() {
            root.popupToggled(root.popup.visible);
        }
    }
}
