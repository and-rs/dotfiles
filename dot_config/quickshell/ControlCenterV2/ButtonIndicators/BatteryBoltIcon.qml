import QtQuick
import QtQuick.Shapes
import qs.Config as SC

Shape {
	id: root

	required property string borderColor
	readonly property int iconSize: 14
	readonly property real outline: 1.8
	readonly property string glyph: String.fromCodePoint(0xE2DE)
	readonly property rect tight: metrics.tightBoundingRect(root.glyph)

	preferredRendererType: Shape.CurveRenderer

	FontMetrics {
		id: metrics

		font.family: "Phosphor-Fill"
		font.pointSize: root.iconSize
	}

	ShapePath {
		capStyle: ShapePath.RoundCap
		fillColor: Qt.alpha(SC.Config.colors.bg, 0.9)
		fillRule: ShapePath.WindingFill
		joinStyle: ShapePath.RoundJoin
		strokeColor: root.borderColor
		strokeWidth: root.outline

		PathText {
			font.family: "Phosphor-Fill"
			font.pointSize: root.iconSize
			text: root.glyph
			x: (root.width - root.tight.width) / 2 - root.tight.x
			y: root.tight.y / (root.iconSize + root.outline)
		}
	}
}
