// plasma-liquid-glass panel layout: a top bar and a floating dock on every screen.
// Applied by System Settings > Global Theme only when "Desktop and window layout" is ticked (that replaces your panels).
// The top bar's "Floating: applets only" setting cannot be set from here; install.sh --layout does that too.
for (var s = 0; s < screenCount; s++) {
    var bar = new Panel;
    bar.location = "top";
    bar.lengthMode = "fill";
    bar.hiding = "none";
    bar.floating = false;
    bar.addWidget("org.kde.plasma.kickoff");
    var appmenu = bar.addWidget("org.kde.plasma.appmenu");
    appmenu.currentConfigGroup = ["Appearance"];
    appmenu.writeConfig("compactView", false);
    bar.addWidget("org.kde.plasma.panelspacer");
    bar.addWidget("org.kde.plasma.systemtray");
    bar.addWidget("org.kde.plasma.digitalclock");
    bar.height = 32;   // after the widgets, or their minimum size overrides it
    bar.screen = s;

    var dock = new Panel;
    dock.location = "bottom";
    dock.alignment = "center";
    dock.lengthMode = "fit";
    dock.hiding = "dodgewindows";
    dock.floating = true;
    dock.addWidget("org.kde.plasma.icontasks");
    var sp = dock.addWidget("org.kde.plasma.panelspacer");
    sp.currentConfigGroup = ["General"];
    sp.writeConfig("expanding", false);
    sp.writeConfig("length", 8);
    dock.addWidget("org.kde.plasma.trash");
    dock.height = 56;
    dock.screen = s;
}
