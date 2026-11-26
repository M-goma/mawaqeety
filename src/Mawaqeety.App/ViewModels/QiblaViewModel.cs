using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using Mawaqeety.Core.Content;

namespace Mawaqeety.App.ViewModels;

/// <summary>Direction of the Qibla from the chosen city (true north, clockwise) and the distance to Makkah.</summary>
public sealed partial class QiblaViewModel : ObservableObject
{
    [ObservableProperty] private double _bearing;
    [ObservableProperty] private string _bearingText = "";
    [ObservableProperty] private string _directionText = "";
    [ObservableProperty] private string _distanceText = "";
    [ObservableProperty] private string _placeText = "";

    public QiblaViewModel() => Reload();

    public void Reload()
    {
        var loc = App.Instance.Settings.Current.Location;
        Bearing = Qibla.Bearing(loc.Latitude, loc.Longitude);
        BearingText = QuranRepository.ArabicDigits((int)Math.Round(Bearing)) + "°";
        DirectionText = $"باتجاه {Qibla.DirectionName(Bearing)}";
        var km = Qibla.DistanceKm(loc.Latitude, loc.Longitude);
        DistanceText = $"{QuranRepository.ArabicDigits((int)Math.Round(km))} كم إلى مكة المكرمة";
        PlaceText = string.IsNullOrEmpty(loc.NameAr) ? loc.NameEn : loc.NameAr;
    }
}
