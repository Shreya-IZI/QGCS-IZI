import QtQuick

Item {
    id: root

    implicitWidth: 32
    implicitHeight: 24

    property color color: "#FFFFFF"
    property real lineWidth: 0  // If 0, auto-scaled to width

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            var w = width;
            var h = height;

            ctx.fillStyle = root.color;

            // Geometry based on official IZI brand logo:
            // Standard bounding box normalized to 94 x 70
            // 1. Left vertical pillar:   x=[0, 7],   y=[0, 70]
            // 2. Right vertical pillar:  x=[87, 94], y=[0, 70]
            // 3. Top bar of Z:           polygon [(25,0), (55,0), (51,6), (25,6)]
            // 4. Diagonal slash of Z:    polygon [(64,0), (72,0), (38,56), (30,56)] (ends at y=56)
            // 5. Bottom bar of Z:        polygon [(25,64), (71,64), (71,70), (21,70)]

            var sx = w / 94.0;
            var sy = h / 70.0;

            // 1. Left Bar
            var barW = Math.max(1.5, 7.0 * sx);
            ctx.fillRect(0, 0, barW, h);

            // 2. Right Bar
            ctx.fillRect(w - barW, 0, barW, h);

            // 3. Top Bar of Z
            ctx.beginPath();
            ctx.moveTo(25.0 * sx, 0);
            ctx.lineTo(55.0 * sx, 0);
            ctx.lineTo(51.0 * sx, 6.0 * sy);
            ctx.lineTo(25.0 * sx, 6.0 * sy);
            ctx.closePath();
            ctx.fill();

            // 4. Diagonal Slash of Z
            ctx.beginPath();
            ctx.moveTo(64.0 * sx, 0);
            ctx.lineTo(72.0 * sx, 0);
            ctx.lineTo(38.0 * sx, 56.0 * sy);
            ctx.lineTo(30.0 * sx, 56.0 * sy);
            ctx.closePath();
            ctx.fill();

            // 5. Bottom Bar of Z
            ctx.beginPath();
            ctx.moveTo(25.0 * sx, 64.0 * sy);
            ctx.lineTo(71.0 * sx, 64.0 * sy);
            ctx.lineTo(71.0 * sx, 70.0 * sy);
            ctx.lineTo(21.0 * sx, 70.0 * sy);
            ctx.closePath();
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onColorChanged: canvas.requestPaint()
}
