import QtQuick
import QtQuick.Shapes
import qs.Config as SC

Shape {
	id: root

	readonly property int iconSize: 14
	readonly property real outline: 1.8
	readonly property string glyph: String.fromCodePoint(0xE2DE)
	readonly property rect tight: metrics.tightBoundingRect(root.glyph)

	function token(light) {
		const bg = Qt.color(SC.Config.colors.bg);
		const fg = Qt.color(SC.Config.colors.fg);
		const bgIsLight = bg.hslLightness >= fg.hslLightness;
		return light === bgIsLight ? bg : fg;
	}

	preferredRendererType: Shape.CurveRenderer

	FontMetrics {
		id: metrics

		font.family: "Phosphor-Fill"
		font.pointSize: root.iconSize
	}

	ShapePath {
		capStyle: ShapePath.RoundCap
		fillColor: Qt.alpha(root.token(true), 0.9)
		fillRule: ShapePath.WindingFill
		joinStyle: ShapePath.RoundJoin
		strokeColor: root.token(false)
		strokeWidth: root.outline

		PathText {
			font.family: "Phosphor-Fill"
			font.pointSize: root.iconSize
			text: root.glyph
			x: 7
			y: -1
		}
	}
}
