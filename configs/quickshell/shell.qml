import QtQuick
import Quickshell
import "./Bar"
import "./Launcher"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Launcher {}
}
