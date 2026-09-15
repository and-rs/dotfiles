import QtQuick
import QtQuick.Shapes
import qs.Config as SC

Shape {
	id: root

	readonly property string glyph: String.fromCodePoint(0xE2DE)
	readonly property int iconSize: 12
	readonly property real outline: 1.5
	readonly property rect tight: metrics.tightBoundingRect(root.glyph)

	preferredRendererType: Shape.CurveRenderer

	FontMetrics {
		id: metrics

		font.family: "Phosphor-Fill"
		font.pointSize: root.iconSize
	}

	ShapePath {
		capStyle: ShapePath.RoundCap
		fillColor: SC.Config.colors.bg
		fillRule: ShapePath.WindingFill
		joinStyle: ShapePath.RoundJoin
		strokeColor: SC.Config.colors.fg
		strokeWidth: root.outline

		PathText {
			font.family: "Phosphor-Fill"
			font.pointSize: root.iconSize
			text: root.glyph
			x: (root.width - root.tight.width) / 2 - root.tight.x
			y: 0
		}
	}
}
