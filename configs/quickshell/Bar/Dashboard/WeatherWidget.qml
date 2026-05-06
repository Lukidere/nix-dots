import QtQuick
import Quickshell.Io
import "../../Theme"

Item {
    id: root
    height: col.implicitHeight

    property string temp:      "--"
    property string feelsLike: "--"
    property string desc:      "Loading..."
    property string wIcon:     "\uE302"
    property var    forecast:  []
    property real   lat: 0
    property real   lon: 0

    function wmoIcon(code) {
        const c = parseInt(code || "0")
        if (c === 0)                          return "\uE30D"  // clear
        if (c <= 3)                           return "\uE302"  // partly cloudy
        if (c === 45 || c === 48)             return "\uE313"  // fog
        if (c >= 51 && c <= 57)               return "\uE319"  // drizzle
        if (c >= 61 && c <= 67)               return "\uE318"  // rain
        if (c >= 71 && c <= 77)               return "\uE30A"  // snow
        if (c >= 80 && c <= 82)               return "\uE318"  // rain showers
        if (c >= 85 && c <= 86)               return "\uE30A"  // snow showers
        if (c === 95 || c === 96 || c === 99) return "\uE31D"  // thunderstorm
        return "\uE302"
    }

    function wmoDesc(code) {
        const c = parseInt(code || "0")
        if (c === 0)              return "Clear sky"
        if (c === 1)              return "Mainly clear"
        if (c === 2)              return "Partly cloudy"
        if (c === 3)              return "Overcast"
        if (c === 45 || c === 48) return "Fog"
        if (c >= 51 && c <= 57)   return "Drizzle"
        if (c >= 61 && c <= 67)   return "Rain"
        if (c >= 71 && c <= 77)   return "Snow"
        if (c >= 80 && c <= 82)   return "Rain showers"
        if (c >= 85 && c <= 86)   return "Snow showers"
        if (c === 95 || c === 96 || c === 99) return "Thunderstorm"
        return "Unknown"
    }

    function dayName(dateStr) {
        const d = new Date(dateStr)
        return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()]
    }

    // Step 1: get location
    readonly property Process _geoProc: Process {
        command: ["sh", "-c", "curl -sf 'https://ipapi.co/json' 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.lat = d.latitude || 0
                    root.lon = d.longitude || 0
                    if (root.lat !== 0) {
                        root._weatherProc.running = false
                        root._weatherProc.running = true
                    }
                } catch(e) {}
            }
        }
    }

    // Step 2: get weather
    readonly property Process _weatherProc: Process {
        command: ["sh", "-c",
            "curl -sf 'https://api.open-meteo.com/v1/forecast?latitude=" + root.lat +
            "&longitude=" + root.lon +
            "&current_weather=true&daily=temperature_2m_max,temperature_2m_min,weathercode" +
            "&hourly=apparent_temperature&forecast_days=7" +
            "&timezone=auto' 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    const cur = d.current_weather || {}
                    root.temp  = Math.round(cur.temperature || 0) + "\u00B0C"
                    root.wIcon = root.wmoIcon(cur.weathercode)
                    root.desc  = root.wmoDesc(cur.weathercode)

                    // apparent_temperature from hourly data (index = current hour)
                    const hourly = d.hourly || {}
                    const apparentTemps = hourly.apparent_temperature || []
                    const hour = new Date().getHours()
                    root.feelsLike = apparentTemps[hour] !== undefined
                        ? Math.round(apparentTemps[hour]) + "\u00B0C"
                        : root.temp

                    // daily forecast
                    const daily = d.daily || {}
                    const dates = daily.time || []
                    const highs = daily.temperature_2m_max || []
                    const lows  = daily.temperature_2m_min || []
                    const codes = daily.weathercode || []
                    let fc = []
                    for (let i = 0; i < dates.length && i < 7; i++) {
                        fc.push({
                            day:  root.dayName(dates[i]),
                            date: dates[i],
                            high: Math.round(highs[i]),
                            low:  Math.round(lows[i]),
                            icon: root.wmoIcon(codes[i]),
                            code: codes[i]
                        })
                    }
                    root.forecast = fc
                } catch(e) { root.desc = "Unavailable" }
            }
        }
    }

    Timer {
        interval: 900000; running: true; repeat: true
        onTriggered: { root._weatherProc.running = false; root._weatherProc.running = true }
    }

    Column {
        id: col
        width: parent.width; spacing: 10

        // Current weather
        Row {
            width: parent.width; spacing: 12

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wIcon
                font.family: "Iosevka Nerd Font"; font.pixelSize: 30
                color: Colors.color3
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text {
                    text: root.temp + "  \u00B7  feels " + root.feelsLike
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 13; font.bold: true
                    color: Colors.foreground
                }
                Text {
                    text: root.desc
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                    color: Colors.color8
                }
            }
        }

        // 7-day forecast
        Row {
            width: parent.width; spacing: 0
            visible: root.forecast.length > 0

            Repeater {
                model: root.forecast
                delegate: Column {
                    width: Math.floor(parent.width / 7)
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.day
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 9; font.bold: index === 0
                        color: index === 0 ? Colors.color4 : Colors.color8
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: Colors.color3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.high + "\u00B0"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: Colors.foreground
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.low + "\u00B0"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 10
                        color: Colors.color8
                    }
                }
            }
        }
    }
}
