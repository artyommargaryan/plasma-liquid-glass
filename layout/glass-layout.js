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
    // the Launchpad widget install.sh puts in place; Plasma's own launcher if it is missing
    bar.addWidget(knownWidgetTypes.indexOf("org.liquidglass.launchpad") >= 0 ? "org.liquidglass.launchpad" : "org.kde.plasma.kickoff");
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
