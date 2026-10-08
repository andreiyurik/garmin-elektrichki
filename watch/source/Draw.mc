import Toybox.Graphics;
import Toybox.Lang;

//! Drawing helpers. The arrow is a polygon because system fonts on these
//! devices have no "→" glyph (shows as a box in the simulator).
(:glance)
module Draw {

    //! Right-pointing filled triangle, centered vertically on y, starting at x.
    function arrow(dc as Dc, x as Number, y as Number, size as Number) as Void {
        var half = size / 2;
        dc.fillPolygon([[x, y - half], [x + size, y], [x, y + half]]);
    }

    //! "▸ text" centered on cx.
    function arrowTextCentered(dc as Dc, cx as Number, y as Number, font as FontType, text as String) as Void {
        var size = dc.getFontHeight(font) / 3;
        var gap = size / 2 + 2;
        var width = size + gap + dc.getTextWidthInPixels(text, font);
        var x = cx - width / 2;
        arrow(dc, x, y, size);
        dc.drawText(x + size + gap, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
