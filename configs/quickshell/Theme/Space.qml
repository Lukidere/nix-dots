pragma Singleton
import QtQuick

QtObject {
    readonly property int xs:  4
    readonly property int sm:  8
    readonly property int md:  12
    readonly property int lg:  16
    readonly property int xl:  24
    // motion tiers (ms)
    readonly property int fast: 120
    readonly property int med:  180
    readonly property int slow: 300
}
