pragma Singleton
import QtQuick
QtObject { property bool onBattery: false; property QtObject displayDevice: QtObject { property bool isPresent: true; property real percentage: 0.78; property int state: 1 } }
