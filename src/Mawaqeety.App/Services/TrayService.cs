using System.Drawing;
using System.Reflection;
using System.Windows.Forms;
using Mawaqeety.App.Localization;

namespace Mawaqeety.App.Services;

/// <summary>
/// Notification-area icon (next to the Windows clock). Left click opens the quick menu,
/// double click opens the main window. Tooltip and header show the next prayer and remaining time.
/// </summary>
public sealed class TrayService : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripMenuItem _header;
    private readonly ToolStripMenuItem _open;
    private readonly ToolStripMenuItem _pause;
    private readonly ToolStripMenuItem _resume;
    private readonly ToolStripMenuItem _stopSound;
    private readonly ToolStripMenuItem _exit;
    private readonly ToolStripMenuItem _widget;
    private readonly ToolStripMenuItem[] _pauseItems;
    private bool _balloonShown;

    public event Action? OpenRequested;
    public event Action<TimeSpan?>? PauseRequested; // null = until tomorrow
    public event Action? ResumeRequested;
    public event Action? StopSoundRequested;
    public event Action? ExitRequested;
    public event Action? WidgetToggleRequested;

    public TrayService()
    {
        _menu = new ContextMenuStrip
        {
            Renderer = new ToolStripProfessionalRenderer(new TrayColors()),
            ShowImageMargin = false,
            Font = new Font("Segoe UI", 10f),
            ForeColor = Color.FromArgb(244, 247, 251),
            BackColor = Color.FromArgb(15, 37, 68),
            Padding = new Padding(4),
        };

        _header = new ToolStripMenuItem { Enabled = true, Font = new Font("Segoe UI", 10.5f, System.Drawing.FontStyle.Bold), ForeColor = Color.FromArgb(212, 175, 55) };
        _header.Click += (_, _) => OpenRequested?.Invoke();
        _open = new ToolStripMenuItem();
        _open.Click += (_, _) => OpenRequested?.Invoke();

        _pause = new ToolStripMenuItem();
        _pauseItems =
        [
            MakePause(TimeSpan.FromMinutes(30)),
            MakePause(TimeSpan.FromHours(1)),
            MakePause(TimeSpan.FromHours(3)),
            MakePause(null),
        ];
        _pause.DropDownItems.AddRange(_pauseItems);
        _pause.DropDown.BackColor = _menu.BackColor;
        _pause.DropDown.ForeColor = _menu.ForeColor;

        _resume = new ToolStripMenuItem();
        _resume.Click += (_, _) => ResumeRequested?.Invoke();
        _stopSound = new ToolStripMenuItem { Visible = false };
        _stopSound.Click += (_, _) => StopSoundRequested?.Invoke();
        _exit = new ToolStripMenuItem();
        _exit.Click += (_, _) => ExitRequested?.Invoke();
        _widget = new ToolStripMenuItem { CheckOnClick = false };
        _widget.Click += (_, _) => WidgetToggleRequested?.Invoke();

        _menu.Items.AddRange([_header, new ToolStripSeparator(), _open, _widget, _stopSound, _pause, _resume, new ToolStripSeparator(), _exit]);

        _icon = new NotifyIcon
        {
            Icon = LoadIcon(),
            ContextMenuStrip = _menu,
            Visible = true,
            Text = "Mawaqeety",
        };
        _icon.MouseUp += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) ShowMenu();
        };
        _icon.MouseDoubleClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) OpenRequested?.Invoke();
        };

        ApplyLanguage();
        Loc.I.LanguageChanged += (_, _) => ApplyLanguage();
    }

    private ToolStripMenuItem MakePause(TimeSpan? span)
    {
        var item = new ToolStripMenuItem { Tag = span };
        item.Click += (_, _) => PauseRequested?.Invoke(span);
        return item;
    }

    private static Icon LoadIcon()
    {
        try
        {
            if (File.Exists(AppPaths.IconFile)) return new Icon(AppPaths.IconFile, SystemInformation.SmallIconSize);
            return Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? SystemIcons.Application;
        }
        catch { return SystemIcons.Application; }
    }

    private void ShowMenu()
    {
        // NotifyIcon only opens the menu on right click; this internal method gives correct positioning/focus on left click too.
        var mi = typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic);
        mi?.Invoke(_icon, null);
    }

    public void SetWidgetChecked(bool on) => _widget.Checked = on;

    private void ApplyLanguage()
    {
        var l = Loc.I;
        _widget.Text = l["TrayWidget"];
        _menu.RightToLeft = l.IsArabic ? RightToLeft.Yes : RightToLeft.No;
        _pause.DropDown.RightToLeft = _menu.RightToLeft;
        _open.Text = l["TrayOpen"];
        _pause.Text = l["TrayPause"];
        _resume.Text = l["TrayResume"];
        _stopSound.Text = l["TrayStopSound"];
        _exit.Text = l["TrayExit"];
        _pauseItems[0].Text = l["TrayPause30"];
        _pauseItems[1].Text = l["TrayPause60"];
        _pauseItems[2].Text = l["TrayPause180"];
        _pauseItems[3].Text = l["TrayPauseTomorrow"];
    }

    /// <summary>Updates tooltip + header, e.g. "العصر بعد 1 س 20 د".</summary>
    public void UpdateStatus(string nextLine, string? pausedLine, bool paused)
    {
        _header.Text = nextLine;
        var tip = Loc.T("AppName") + "\n" + nextLine + (pausedLine is null ? "" : "\n" + pausedLine);
        _icon.Text = tip.Length > 127 ? tip[..127] : tip;
        _pause.Visible = !paused;
        _resume.Visible = paused;
    }

    public void SetSoundPlaying(bool playing) => _stopSound.Visible = playing;

    /// <summary>One-time hint after the window is closed for the first time.</summary>
    public void ShowStillRunningHint()
    {
        if (_balloonShown) return;
        _balloonShown = true;
        _icon.ShowBalloonTip(4000, Loc.T("AppName"), Loc.T("TrayStillRunning"), ToolTipIcon.Info);
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        _menu.Dispose();
    }

    private sealed class TrayColors : ProfessionalColorTable
    {
        private static readonly Color Bg = Color.FromArgb(15, 37, 68);
        private static readonly Color Hover = Color.FromArgb(22, 54, 97);
        private static readonly Color Line = Color.FromArgb(30, 59, 102);
        public override Color ToolStripDropDownBackground => Bg;
        public override Color MenuBorder => Line;
        public override Color MenuItemBorder => Hover;
        public override Color MenuItemSelected => Hover;
        public override Color MenuItemSelectedGradientBegin => Hover;
        public override Color MenuItemSelectedGradientEnd => Hover;
        public override Color MenuItemPressedGradientBegin => Hover;
        public override Color MenuItemPressedGradientEnd => Hover;
        public override Color SeparatorDark => Line;
        public override Color SeparatorLight => Line;
        public override Color ImageMarginGradientBegin => Bg;
        public override Color ImageMarginGradientMiddle => Bg;
        public override Color ImageMarginGradientEnd => Bg;
    }
}
