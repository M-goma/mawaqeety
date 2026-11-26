using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Mawaqeety.App.Controls;

/// <summary>
/// A compass face with north at the top and a needle pointing to the Qibla.
/// A PC has no compass sensor, so the dial is fixed: the user turns towards the Qibla using true north.
/// </summary>
public sealed class CompassDial : FrameworkElement
{
    public static readonly DependencyProperty BearingProperty = DependencyProperty.Register(
        nameof(Bearing), typeof(double), typeof(CompassDial), new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender));

    public double Bearing { get => (double)GetValue(BearingProperty); set => SetValue(BearingProperty, value); }

    public CompassDial() => FlowDirection = FlowDirection.LeftToRight;

    private Brush Res(string key, Brush fallback) => TryFindResource(key) as Brush ?? fallback;

    protected override void OnRender(DrawingContext dc)
    {
        var size = Math.Min(ActualWidth, ActualHeight);
        if (size < 40) return;
        var c = new Point(ActualWidth / 2, ActualHeight / 2);
        var r = size / 2 - 4;
        var text = Res("TextBrush", Brushes.White);
        var muted = Res("TextMutedBrush", Brushes.Gray);
        var gold = Res("GoldBrush", Brushes.Goldenrod);
        var accent = Res("AccentBrush", Brushes.SeaGreen);
        var face = Res("SurfaceBrush", Brushes.Black);
        var line = Res("LineBrush", Brushes.DimGray);
        var dpi = VisualTreeHelper.GetDpi(this).PixelsPerDip;
        var font = new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal);
        var arabic = TryFindResource("AppFont") as FontFamily ?? new FontFamily("Segoe UI");
        var arabicFace = new Typeface(arabic, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal);

        // Bezel and face
        var bezel = new RadialGradientBrush(((SolidColorBrush)gold).Color, Color.FromArgb(255, 90, 70, 20)) { RadiusX = 0.55, RadiusY = 0.55 };
        dc.DrawEllipse(bezel, null, c, r, r);
        dc.DrawEllipse(face, new Pen(line, 1), c, r * 0.92, r * 0.92);

        Point At(double deg, double rad) => new(c.X + rad * Math.Sin(deg * Math.PI / 180), c.Y - rad * Math.Cos(deg * Math.PI / 180));

        // Ticks every 5°, longer every 30°
        for (var d = 0; d < 360; d += 5)
        {
            var major = d % 30 == 0;
            var pen = new Pen(major ? text : muted, major ? 2 : 1);
            dc.DrawLine(pen, At(d, r * 0.9), At(d, r * (major ? 0.8 : 0.85)));
        }
        // Degree labels
        for (var d = 30; d < 360; d += 30)
        {
            if (d % 90 == 0) continue;
            var ft = new FormattedText(d.ToString(CultureInfo.InvariantCulture), CultureInfo.InvariantCulture, FlowDirection.LeftToRight, font, r * 0.07, muted, dpi);
            var p = At(d, r * 0.71);
            dc.DrawText(ft, new Point(p.X - ft.Width / 2, p.Y - ft.Height / 2));
        }
        // Cardinal points in Arabic
        var names = new[] { ("ش", 0), ("ق", 90), ("ج", 180), ("غ", 270) };
        foreach (var (n, d) in names)
        {
            var ft = new FormattedText(n, CultureInfo.GetCultureInfo("ar"), FlowDirection.RightToLeft, arabicFace, r * 0.13, d == 0 ? new SolidColorBrush(Color.FromRgb(229, 103, 107)) : text, dpi);
            var p = At(d, r * 0.68);
            dc.DrawText(ft, new Point(p.X - ft.Width / 2 + (ft.FlowDirection == FlowDirection.RightToLeft ? ft.Width : 0), p.Y - ft.Height / 2));
        }

        // Qibla needle
        var tip = At(Bearing, r * 0.58);
        var left = At(Bearing - 90, r * 0.06);
        var right = At(Bearing + 90, r * 0.06);
        var tail = At(Bearing + 180, r * 0.25);
        var needle = new StreamGeometry();
        using (var g = needle.Open())
        {
            g.BeginFigure(tip, true, true);
            g.LineTo(left, true, false);
            g.LineTo(tail, true, false);
            g.LineTo(right, true, false);
        }
        needle.Freeze();
        dc.DrawGeometry(accent, new Pen(Brushes.White, 1.2), needle);
        dc.DrawEllipse(gold, new Pen(Brushes.White, 1.5), c, r * 0.05, r * 0.05);

        // Kaaba marker at the end of the needle
        var k = At(Bearing, r * 0.8);
        var s = r * 0.085;
        dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromRgb(20, 20, 20)), new Pen(gold, 2), new Rect(k.X - s, k.Y - s, 2 * s, 2 * s), 3, 3);
        dc.DrawLine(new Pen(gold, 2.5), new Point(k.X - s, k.Y - s * 0.35), new Point(k.X + s, k.Y - s * 0.35));
    }
}
