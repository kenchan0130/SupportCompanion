﻿using Avalonia;
using Avalonia.ReactiveUI;

namespace SupportCompanion;

internal sealed class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any
    // SynchronizationContext-reliant code before AppMain is called: things aren't initialized
    // yet and stuff might break.
    //[STAThread]
    public static void Main(string[] args)
    {
        BuildAvaloniaApp()
            .StartWithClassicDesktopLifetime(args);
    }

    // Avalonia configuration, don't remove; also used by visual designer.
    public static AppBuilder BuildAvaloniaApp()
    {
        return AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace()
            .UseReactiveUI()
            .With(new MacOSPlatformOptions
            {
                ShowInDock = false,
                DisableDefaultApplicationMenuItems = true
            })
            .With(new AvaloniaNativePlatformOptions
            {
                RenderingMode = new[] { AvaloniaNativeRenderingMode.OpenGl, AvaloniaNativeRenderingMode.Metal }
            });
    }
}