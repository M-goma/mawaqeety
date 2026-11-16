namespace Mawaqeety.App.Services;

public static class AppPaths
{
    /// <summary>%AppData%\Mawaqeety — kept separate from the install folder so updates never touch user data.</summary>
    public static string DataDir { get; } = Ensure(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Mawaqeety"));

    public static string LogDir { get; } = Ensure(Path.Combine(DataDir, "logs"));
    public static string DatabaseFile => Path.Combine(DataDir, "mawaqeety.db");
    public static string AppDir => AppContext.BaseDirectory;
    public static string DefaultSound => Path.Combine(AppDir, "Assets", "Sounds", "chime.wav");
    public static string LogoPng => Path.Combine(AppDir, "Assets", "logo.png");
    public static string IconFile => Path.Combine(AppDir, "Assets", "mawaqeety.ico");
    public static string FontsDir => Path.Combine(AppDir, "Assets", "Fonts");

    private static string Ensure(string dir)
    {
        Directory.CreateDirectory(dir);
        return dir;
    }
}
