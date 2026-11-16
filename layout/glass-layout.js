// plasma-liquid-glass panel layout: a top bar and a floating dock on every screen.
// Run by install.sh --layout through plasmashell's scripting interface. REMOVES all existing panels first
// (install.sh saves the previous layout; uninstall.sh --restore-layout puts it back).
// Prints "bar <id>" / "dock <id>" lines; the installer finishes the per-panel settings scripting cannot set.
panels().forEach(function (p) { p.remove(); });
var out = [];
for (var s = 0; s < screenCount; s++) {
    var bar = new Panel;
    bar.location = "top";
    bar.lengthMode = "fill";
    bar.hiding = "none";
    bar.floating = false;
    // The widgets install.sh puts in place: the System Menu opens the bar and the Launchpad sits in the dock.
    // Without them the bar gets a launcher of its own, the Launchpad or else Plasma's.
    var haveMenu = knownWidgetTypes.indexOf("org.liquidglass.systemmenu") >= 0;
    var haveLaunchpad = knownWidgetTypes.indexOf("org.liquidglass.launchpad") >= 0;
    if (haveMenu) {
        bar.addWidget("org.liquidglass.systemmenu");
    }
    if (!(haveMenu && haveLaunchpad)) {
        bar.addWidget(haveLaunchpad ? "org.liquidglass.launchpad" : "org.kde.plasma.kickoff");
    }
    var appmenu = bar.addWidget("org.kde.plasma.appmenu");
    appmenu.currentConfigGroup = ["Appearance"];
    appmenu.writeConfig("compactView", false);
    bar.addWidget("org.kde.plasma.panelspacer");
    bar.addWidget("org.kde.plasma.systemtray");
    if (knownWidgetTypes.indexOf("org.liquidglass.controlcenter") >= 0) {
        bar.addWidget("org.liquidglass.controlcenter");
    }
    bar.addWidget("org.kde.plasma.digitalclock");
    bar.height = 32;   // after the widgets, or their minimum size overrides it
    bar.screen = s;
    out.push("bar " + bar.id);

    var dock = new Panel;
    dock.location = "bottom";
    dock.alignment = "center";
    dock.lengthMode = "fit";
    dock.hiding = "dodgewindows";
    dock.floating = true;
    if (haveMenu && haveLaunchpad) {
        var launchpad = dock.addWidget("org.liquidglass.launchpad");
        launchpad.currentConfigGroup = ["General"];
        launchpad.writeConfig("icon", "view-app-grid");
    }
    // our own task manager with hover magnification when install.sh built it (dock/), the stock one otherwise
    if (knownWidgetTypes.indexOf("org.liquidglass.icontasks") >= 0) {
        var tasks = dock.addWidget("org.liquidglass.icontasks");
        tasks.currentConfigGroup = ["General"];
        tasks.writeConfig("magnification", 150);
    } else {
        dock.addWidget("org.kde.plasma.icontasks");
    }
    var sp = dock.addWidget("org.kde.plasma.panelspacer");
    sp.currentConfigGroup = ["General"];
    sp.writeConfig("expanding", false);
    sp.writeConfig("length", 8);
    dock.addWidget("org.kde.plasma.trash");
    dock.height = 56;
    dock.screen = s;
    out.push("dock " + dock.id);
}
print(out.join("\n"));
