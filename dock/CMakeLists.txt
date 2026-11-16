# SPDX-License-Identifier: GPL-2.0-or-later
# Standalone build of Plasma's task manager applet (plasma-desktop, applets/taskmanager) under its own id,
# with hover magnification for docks. See README.md in this directory for what was changed and why.
cmake_minimum_required(VERSION 3.20)
project(liquidglass-dock VERSION 6.8.2)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQtDeclareLoggingCategory)
include(ECMQmlModule)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Config CoreAddons GlobalAccel I18n KIO Notifications Service WindowSystem XmlGui)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(KSysGuard REQUIRED)
find_package(LibNotificationManager REQUIRED)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# the strings are Plasma's own, so its installed translations apply
add_definitions(-DTRANSLATION_DOMAIN="plasma_applet_org.kde.plasma.taskmanager")

plasma_add_applet(org.liquidglass.taskmanager
    QML_SOURCES
        qml/AudioStream.qml
        qml/ConfigAppearance.qml
        qml/ConfigBehavior.qml
        qml/config.qml
        qml/ContextMenu.qml
        qml/GroupDialog.qml
        qml/GroupExpanderOverlay.qml
        qml/main.qml
        qml/MouseHandler.qml
        qml/PipeWireThumbnail.qml
        qml/PlayerController.qml
        qml/PulseAudio.qml
        qml/ScrollableTextWrapper.qml
        qml/TaskBadgeOverlay.qml
        qml/TaskList.qml
        qml/TaskProgressOverlay.qml
        qml/Task.qml
        qml/ToolTipDelegate.qml
        qml/ToolTipInstance.qml
        qml/ToolTipWindowMouseArea.qml
        qml/code/LayoutMetrics.js
        qml/code/TaskTools.js
    CPP_SOURCES
        backend.cpp
        smartlauncherbackend.cpp
        smartlauncheritem.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

kconfig_add_kcfg_files(org.liquidglass.taskmanager kactivitymanagerd_plugins_settings.kcfgc)

ecm_qt_declare_logging_category(org.liquidglass.taskmanager
    HEADER log_settings.h
    IDENTIFIER TASKMANAGER_DEBUG
    CATEGORY_NAME org.liquidglass.taskmanager)

target_link_libraries(org.liquidglass.taskmanager PRIVATE
    Qt::Core Qt::Qml Qt::Quick
    Plasma::Activities Plasma::ActivitiesStats
    KF6::ConfigGui KF6::GlobalAccel KF6::I18n KF6::KIOCore KF6::KIOGui KF6::KIOFileWidgets
    KF6::Notifications KF6::XmlGui KSysGuard::ProcessCore KF6::Service KF6::WindowSystem
    PW::LibNotificationManager)

# the icons-only variant is the same plugin under a second id (X-Plasma-RootPath in its metadata)
install(FILES icontasks/metadata.json DESTINATION ${KDE_INSTALL_DATADIR}/plasma/plasmoids/org.liquidglass.icontasks)
