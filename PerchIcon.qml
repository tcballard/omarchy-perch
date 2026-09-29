import QtQuick

Canvas {
    id: root
    property string name: "play"
    property color ink: "white"
    implicitWidth: 20
    implicitHeight: 20
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = ink;
        c.fillStyle = ink;
        c.lineWidth = 1.8;
        c.lineCap = "round";
        c.lineJoin = "round";
        function line(x, y, a, b) {
            c.beginPath();
            c.moveTo(x, y);
            c.lineTo(a, b);
            c.stroke();
        }
        function triangle(a, b, d, e, f, g) {
            c.beginPath();
            c.moveTo(a, b);
            c.lineTo(d, e);
            c.lineTo(f, g);
            c.closePath();
            c.fill();
        }
        if (name === "play")
            triangle(8, 5, 19, 12, 8, 19);
        else if (name === "pause") {
            c.fillRect(7, 5, 3, 14);
            c.fillRect(14, 5, 3, 14);
        } else if (name === "next") {
            triangle(5, 5, 16, 12, 5, 19);
            line(18, 5, 18, 19);
        } else if (name === "previous") {
            triangle(19, 5, 8, 12, 19, 19);
            line(6, 5, 6, 19);
        } else if (name === "close") {
            line(7, 7, 17, 17);
            line(17, 7, 7, 17);
        } else if (name === "settings") {
            line(4, 7, 20, 7);
            line(4, 17, 20, 17);
            c.fillRect(8, 4, 3, 6);
            c.fillRect(14, 14, 3, 6);
        } else if (name === "players") {
            c.strokeRect(4, 4, 12, 10);
            line(9, 18, 20, 18);
            line(20, 18, 20, 9);
        } else if (name === "music") {
            line(10, 17, 10, 6);
            line(10, 6, 19, 4);
            line(19, 4, 19, 15);
            c.beginPath();
            c.ellipse(4, 15, 6, 5);
            c.fill();
            c.beginPath();
            c.ellipse(13, 13, 6, 5);
            c.fill();
        } else if (name === "timer") {
            c.beginPath();
            c.arc(12, 13, 8, 0, Math.PI * 2);
            c.stroke();
            line(12, 8, 12, 13);
            line(12, 13, 16, 13);
            line(9, 2, 15, 2);
        } else if (name === "system") {
            c.beginPath();
            c.moveTo(4, 9);
            c.lineTo(8, 9);
            c.lineTo(13, 5);
            c.lineTo(13, 19);
            c.lineTo(8, 15);
            c.lineTo(4, 15);
            c.closePath();
            c.stroke();
            c.beginPath();
            c.arc(13, 12, 7, -0.8, 0.8);
            c.stroke();
        } else if (name === "activity") {
            line(3, 13, 7, 13);
            line(7, 13, 10, 6);
            line(10, 6, 14, 18);
            line(14, 18, 17, 10);
            line(17, 10, 21, 10);
        } else if (name === "wave") {
            line(5, 10, 5, 14);
            line(10, 5, 10, 19);
            line(15, 8, 15, 16);
            line(20, 10, 20, 14);
        }
    }
}
