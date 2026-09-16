import QtQuick
import Company.UI

Item {
    id: root

    property string name: "dashboard"
    property color color: CompanyTheme.textSecondary
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineWidth = 1.5
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var s = width
            var f = s / 16.0 // scale factor based on 16x16 coordinate space

            switch (root.name) {
                case "dashboard":
                    // 4 rounded squares
                    ctx.strokeRect(2*f, 2*f, 4.5*f, 4.5*f)
                    ctx.strokeRect(9.5*f, 2*f, 4.5*f, 4.5*f)
                    ctx.strokeRect(2*f, 9.5*f, 4.5*f, 4.5*f)
                    ctx.strokeRect(9.5*f, 9.5*f, 4.5*f, 4.5*f)
                    break

                case "flight":
                    // Target reticle / flight shield
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 6*f, 0, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(8*f, 2*f); ctx.lineTo(8*f, 5*f)
                    ctx.moveTo(8*f, 11*f); ctx.lineTo(8*f, 14*f)
                    ctx.moveTo(2*f, 8*f); ctx.lineTo(5*f, 8*f)
                    ctx.moveTo(11*f, 8*f); ctx.lineTo(14*f, 8*f)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 1.5*f, 0, 2*Math.PI)
                    ctx.fill()
                    break

                case "missions":
                    // Navigation / Rocket
                    ctx.beginPath()
                    ctx.moveTo(8*f, 2*f)
                    ctx.lineTo(13*f, 13*f)
                    ctx.lineTo(8*f, 10.5*f)
                    ctx.lineTo(3*f, 13*f)
                    ctx.closePath()
                    ctx.stroke()
                    break

                case "fleet":
                    // Multi-user / Fleet
                    ctx.beginPath()
                    ctx.arc(6*f, 5*f, 2.5*f, 0, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(6*f, 14*f, 4.5*f, Math.PI, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(11.5*f, 6*f, 2*f, 0, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(11.5*f, 14*f, 3.5*f, Math.PI * 1.1, 2*Math.PI)
                    ctx.stroke()
                    break

                case "logs":
                    // Document with lines
                    ctx.strokeRect(3*f, 2*f, 10*f, 12*f)
                    ctx.beginPath()
                    ctx.moveTo(5.5*f, 5.5*f); ctx.lineTo(10.5*f, 5.5*f)
                    ctx.moveTo(5.5*f, 8*f);   ctx.lineTo(10.5*f, 8*f)
                    ctx.moveTo(5.5*f, 10.5*f); ctx.lineTo(8.5*f, 10.5*f)
                    ctx.stroke()
                    break

                case "settings":
                    // Gear icon
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 4*f, 0, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 1.8*f, 0, 2*Math.PI)
                    ctx.stroke()
                    for (var i = 0; i < 6; i++) {
                        var ang = i * Math.PI / 3.0
                        var x1 = 8*f + Math.cos(ang) * 4*f
                        var y1 = 8*f + Math.sin(ang) * 4*f
                        var x2 = 8*f + Math.cos(ang) * 6.5*f
                        var y2 = 8*f + Math.sin(ang) * 6.5*f
                        ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
                    }
                    break

                case "uas":
                case "radio":
                    // Antenna mast
                    ctx.beginPath()
                    ctx.moveTo(8*f, 14*f); ctx.lineTo(8*f, 6*f)
                    ctx.moveTo(4*f, 14*f); ctx.lineTo(12*f, 14*f)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(8*f, 5*f, 1.5*f, 0, 2*Math.PI)
                    ctx.fill()
                    ctx.beginPath()
                    ctx.arc(8*f, 5*f, 4*f, Math.PI * 1.25, Math.PI * 1.75)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(8*f, 5*f, 6.5*f, Math.PI * 1.25, Math.PI * 1.75)
                    ctx.stroke()
                    break

                case "arm":
                case "lock":
                    // Padlock
                    ctx.strokeRect(4*f, 7*f, 8*f, 7*f)
                    ctx.beginPath()
                    ctx.arc(8*f, 7*f, 3*f, Math.PI, 0)
                    ctx.stroke()
                    break

                case "rtl":
                    // House with arrow
                    ctx.beginPath()
                    ctx.moveTo(8*f, 2.5*f)
                    ctx.lineTo(13.5*f, 7.5*f)
                    ctx.lineTo(11.5*f, 7.5*f)
                    ctx.lineTo(11.5*f, 13.5*f)
                    ctx.lineTo(4.5*f, 13.5*f)
                    ctx.lineTo(4.5*f, 7.5*f)
                    ctx.lineTo(2.5*f, 7.5*f)
                    ctx.closePath()
                    ctx.stroke()
                    break

                case "hold":
                    // Pause bars in circle
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 6*f, 0, 2*Math.PI)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(6.5*f, 5.5*f); ctx.lineTo(6.5*f, 10.5*f)
                    ctx.moveTo(9.5*f, 5.5*f); ctx.lineTo(9.5*f, 10.5*f)
                    ctx.stroke()
                    break

                case "land":
                    // Down arrow into runway line
                    ctx.beginPath()
                    ctx.moveTo(8*f, 3*f); ctx.lineTo(8*f, 10.5*f)
                    ctx.moveTo(5*f, 7.5*f); ctx.lineTo(8*f, 10.5*f); ctx.lineTo(11*f, 7.5*f)
                    ctx.moveTo(3*f, 13.5*f); ctx.lineTo(13*f, 13.5*f)
                    ctx.stroke()
                    break

                case "battery":
                    // Battery
                    ctx.strokeRect(2.5*f, 5*f, 10*f, 6*f)
                    ctx.fillRect(12.5*f, 6.5*f, 1.5*f, 3*f)
                    break

                case "satellite":
                    // Satellite dish / waves
                    ctx.beginPath()
                    ctx.arc(4*f, 12*f, 2*f, 0, 2*Math.PI)
                    ctx.fill()
                    ctx.beginPath()
                    ctx.arc(4*f, 12*f, 5*f, Math.PI * 1.5, 0)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(4*f, 12*f, 8.5*f, Math.PI * 1.5, 0)
                    ctx.stroke()
                    break

                case "signal":
                    // Signal bars
                    ctx.fillRect(2*f, 11*f, 2*f, 3*f)
                    ctx.fillRect(5.5*f, 8.5*f, 2*f, 5.5*f)
                    ctx.fillRect(9*f, 6*f, 2*f, 8*f)
                    ctx.fillRect(12.5*f, 3*f, 2*f, 11*f)
                    break

                case "video":
                    // Video camera
                    ctx.strokeRect(2.5*f, 4*f, 7.5*f, 8*f)
                    ctx.beginPath()
                    ctx.moveTo(10*f, 6.5*f); ctx.lineTo(13.5*f, 4.5*f); ctx.lineTo(13.5*f, 11.5*f); ctx.lineTo(10*f, 9.5*f)
                    ctx.stroke()
                    break

                case "gps":
                    // Location pin
                    ctx.beginPath()
                    ctx.arc(8*f, 5.5*f, 3.5*f, 0, 2*Math.PI)
                    ctx.moveTo(8*f, 9*f); ctx.lineTo(8*f, 14*f)
                    ctx.stroke()
                    break

                case "chevron_down":
                    ctx.beginPath()
                    ctx.moveTo(4*f, 6*f); ctx.lineTo(8*f, 10*f); ctx.lineTo(12*f, 6*f)
                    ctx.stroke()
                    break

                case "image_placeholder":
                    // Image placeholder outline
                    ctx.strokeRect(3*f, 3*f, 10*f, 10*f)
                    ctx.beginPath()
                    ctx.arc(6*f, 6*f, 1.2*f, 0, 2*Math.PI)
                    ctx.fill()
                    ctx.beginPath()
                    ctx.moveTo(4*f, 11*f); ctx.lineTo(7*f, 8*f); ctx.lineTo(9.5*f, 10*f); ctx.lineTo(12*f, 7.5*f)
                    ctx.stroke()
                    break

                default:
                    ctx.beginPath()
                    ctx.arc(8*f, 8*f, 4*f, 0, 2*Math.PI)
                    ctx.stroke()
                    break
            }
        }
    }

    onColorChanged: canvas.requestPaint()
    onNameChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
}
