import QtQuick
import Company.UI

Item {
    id: root

    property color accentColor: CompanyTheme.textSecondary

    implicitWidth: 70
    implicitHeight: 60

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2.0
            var cy = height / 2.0
            var s = Math.min(width, height) / 60.0

            // Drone arms
            ctx.strokeStyle = "#384759"
            ctx.lineWidth = 2.5 * s
            ctx.lineCap = "round"

            // Diagonal arms (X shape)
            ctx.beginPath()
            ctx.moveTo(cx - 22 * s, cy - 18 * s)
            ctx.lineTo(cx + 22 * s, cy + 18 * s)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(cx - 22 * s, cy + 18 * s)
            ctx.lineTo(cx + 22 * s, cy - 18 * s)
            ctx.stroke()

            // Propeller circles (4 rotors)
            ctx.strokeStyle = "#4B5B6D"
            ctx.lineWidth = 1.2 * s

            var rotors = [
                { x: cx - 22 * s, y: cy - 18 * s },
                { x: cx + 22 * s, y: cy - 18 * s },
                { x: cx - 22 * s, y: cy + 18 * s },
                { x: cx + 22 * s, y: cy + 18 * s }
            ]

            rotors.forEach(function(r) {
                // Rotor motor mount
                ctx.fillStyle = "#283544"
                ctx.beginPath()
                ctx.arc(r.x, r.y, 4 * s, 0, 2 * Math.PI)
                ctx.fill()
                ctx.stroke()

                // Rotor blade sweep
                ctx.beginPath()
                ctx.ellipse(r.x, r.y, 8 * s, 3 * s, Math.PI / 4, 0, 2 * Math.PI)
                ctx.stroke()
            })

            // Central fuselage body
            ctx.fillStyle = "#1E2A38"
            ctx.strokeStyle = "#3B82F6"
            ctx.lineWidth = 1.5 * s

            var bx = cx - 8 * s
            var by = cy - 13 * s
            var bw = 16 * s
            var bh = 26 * s
            var br = 4 * s

            ctx.beginPath()
            ctx.moveTo(bx + br, by)
            ctx.lineTo(bx + bw - br, by)
            ctx.arcTo(bx + bw, by, bx + bw, by + br, br)
            ctx.lineTo(bx + bw, by + bh - br)
            ctx.arcTo(bx + bw, by + bh, bx + bw - br, by + bh, br)
            ctx.lineTo(bx + br, by + bh)
            ctx.arcTo(bx, by + bh, bx, by + bh - br, br)
            ctx.lineTo(bx, by + br)
            ctx.arcTo(bx, by, bx + br, by, br)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()

            // Camera / Gimbal forward nose
            ctx.fillStyle = "#3B82F6"
            ctx.beginPath()
            ctx.arc(cx, cy - 13 * s, 3 * s, Math.PI, 0)
            ctx.fill()

            // Power LED indicator
            ctx.fillStyle = "#22C55E"
            ctx.beginPath()
            ctx.arc(cx, cy + 8 * s, 1.8 * s, 0, 2 * Math.PI)
            ctx.fill()
        }
    }

    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
