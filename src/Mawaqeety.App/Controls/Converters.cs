using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace Mawaqeety.App.Controls;

public sealed class BoolToVisibilityConverter : IValueConverter
{
    public bool Invert { get; set; }
    /// <summary>ConverterParameter="inv" inverts for a single binding.</summary>
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        (value is true) ^ Invert ^ (parameter as string == "inv") ? Visibility.Visible : Visibility.Collapsed;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        (value is Visibility.Visible) ^ Invert;
}

public sealed class NotEmptyToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        string.IsNullOrWhiteSpace(value as string) ? Visibility.Collapsed : Visibility.Visible;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

public sealed class EmptyToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        string.IsNullOrEmpty(value as string) ? Visibility.Visible : Visibility.Collapsed;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

public sealed class InverseBoolConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) => value is not true;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => value is not true;
}

/// <summary>Displays a GeoLocation search result in the current language.</summary>
public sealed class LocationNameConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is Core.Models.GeoLocation l ? l.DisplayName(Localization.Loc.I.IsArabic) : "";
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>Multiplies a number (e.g. font size → line height).</summary>
public sealed class Scale(double factor) : IValueConverter
{
    public static readonly Scale ByTwo = new(1.9);
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is double d ? d * factor : value;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>"#RRGGBB" → brush (palette swatches).</summary>
public sealed class HexBrush : IValueConverter
{
    public static readonly HexBrush Instance = new();
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        try { return new System.Windows.Media.SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString((string)value)); }
        catch { return System.Windows.Media.Brushes.Transparent; }
    }
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

/// <summary>True when all bound values are equal.</summary>
public sealed class Equal : IMultiValueConverter
{
    public static readonly Equal Instance = new();
    public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture) =>
        values.Length > 1 && values.Skip(1).All(v => Equals(v, values[0]));
    public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture) => [];
}

public sealed class Not : IValueConverter
{
    public static readonly Not Instance = new();
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) => value is not true;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => value is not true;
}

public sealed class NotNullVisibility : IValueConverter
{
    public static readonly NotNullVisibility Instance = new();
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) => value is null ? Visibility.Collapsed : Visibility.Visible;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}
