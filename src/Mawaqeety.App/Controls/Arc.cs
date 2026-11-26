using System.Windows;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Mawaqeety.App.Controls;

/// <summary>A circular progress arc starting at the top, clockwise.</summary>
public sealed class Arc : Shape
{
    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(
        nameof(Progress), typeof(double), typeof(Arc),
        new FrameworkPropertyMetadata(0.0, FrameworkPropertyMetadataOptions.AffectsRender | FrameworkPropertyMetadataOptions.AffectsMeasure));

    public double Progress
    {
        get => (double)GetValue(ProgressProperty);
        set => SetValue(ProgressProperty, value);
    }

    protected override Geometry DefiningGeometry
    {
        get
        {
            var p = Math.Clamp(Progress, 0, 1);
            var w = Math.Max(0, ActualWidth - StrokeThickness);
            var h = Math.Max(0, ActualHeight - StrokeThickness);
            if (p <= 0 || w <= 0) return Geometry.Empty;
            var cx = ActualWidth / 2; var cy = ActualHeight / 2; double rx = w / 2, ry = h / 2;
            if (p >= 0.9999) return new EllipseGeometry(new Point(cx, cy), rx, ry);
            var a = p * 2 * Math.PI;
            var start = new Point(cx, cy - ry);
            var end = new Point(cx + rx * Math.Sin(a), cy - ry * Math.Cos(a));
            var g = new StreamGeometry();
            using (var ctx = g.Open())
            {
                ctx.BeginFigure(start, false, false);
                ctx.ArcTo(end, new Size(rx, ry), 0, p > 0.5, SweepDirection.Clockwise, true, false);
            }
            g.Freeze();
            return g;
        }
    }
}
