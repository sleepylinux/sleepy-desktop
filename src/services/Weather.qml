// SPDX-License-Identifier: GPL-3.0-only
// Modified for Sleepy on 2026-08-31: weather lookup and cache are daemon-owned.

pragma Singleton

import QtQuick
import Quickshell
import Sleepy.Config
import qs.utils

Singleton {
    id: root

    readonly property var weatherState: DesktopModel.weather || ({})
    readonly property var current: weatherState.current || weatherState.currentConditions || ({})
    readonly property string city: weatherState.location?.displayName
                                   || weatherState.location?.city
                                   || weatherState.city || ""
    readonly property string loc: weatherState.location?.coordinates || weatherState.loc || ""
    readonly property var cc: ({
        "weatherCode": current.weatherCode ?? current.code ?? 0,
        "weatherDesc": current.weatherDesc || current.description || getWeatherCondition(current.weatherCode ?? current.code ?? 0),
        "tempC": current.tempC ?? current.temperatureC,
        "feelsLikeC": current.feelsLikeC ?? current.apparentTemperatureC,
        "humidity": current.humidity ?? current.relativeHumidity ?? 0,
        "windSpeed": current.windSpeed ?? current.windKph ?? 0,
        "isDay": current.isDay ?? true,
        "sunrise": current.sunrise || weatherState.daily?.[0]?.sunrise || "",
        "sunset": current.sunset || weatherState.daily?.[0]?.sunset || ""
    })
    readonly property list<var> forecast: (weatherState.forecast || weatherState.daily || []).map(dayRecord)
    readonly property list<var> hourlyForecast: (weatherState.hourlyForecast || weatherState.hourly || []).map(hourRecord)
    readonly property string icon: Icons.getWeatherIcon(cc.weatherCode)
    readonly property string description: cc.weatherDesc ?? qsTr("No weather")
    readonly property string temp: formatTemp(cc.tempC)
    readonly property string feelsLike: formatTemp(cc.feelsLikeC)
    readonly property int humidity: cc.humidity ?? 0
    readonly property real windSpeed: cc.windSpeed ?? 0
    readonly property string sunrise: formatClock(cc.sunrise)
    readonly property string sunset: formatClock(cc.sunset)

    function dayRecord(day: var): var {
        const code = day.weatherCode ?? day.code ?? 0;
        return Object.assign({
            "date": day.date || day.day || "",
            "maxTempC": day.maxTempC ?? day.highC,
            "minTempC": day.minTempC ?? day.lowC,
            "weatherCode": code,
            "icon": day.icon || Icons.getWeatherIcon(code)
        }, day);
    }

    function hourRecord(hour: var): var {
        const code = hour.weatherCode ?? hour.code ?? 0;
        const timestamp = hour.timestamp || hour.time || "";
        const parsed = Date.parse(timestamp);
        return Object.assign({
            "timestamp": timestamp,
            "hour": Number.isNaN(parsed) ? (hour.hour ?? 0) : new Date(parsed).getHours(),
            "tempC": hour.tempC ?? hour.temperatureC,
            "precipChance": hour.precipChance ?? hour.precipitationProbability ?? 0,
            "weatherCode": code,
            "icon": hour.icon || Icons.getWeatherIcon(code)
        }, hour);
    }

    function formatClock(value: var): string {
        if (!value)
            return "--:--";
        const date = value instanceof Date ? value : new Date(value);
        if (Number.isNaN(date.getTime()))
            return "--:--";
        return Qt.formatDateTime(date, GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm");
    }

    function formatTemp(temp: var): string {
        return GlobalConfig.services.useFahrenheit
            ? `${temp !== undefined ? Math.round(toFahrenheit(temp)) : "--"}°F`
            : `${temp !== undefined ? Math.round(temp) : "--"}°C`;
    }

    function reload(): bool {
        return CommandClient.launcher({
            "type": "refreshWeather",
            "data": {"location": GlobalConfig.services.weatherLocation || ""}
        });
    }

    function toFahrenheit(celsius: real): real {
        return celsius * 9 / 5 + 32;
    }

    function getWeatherCondition(code: var): string {
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[String(code)] || "Unknown";
    }

    Connections {
        function onWeatherLocationChanged(): void {
            root.reload();
        }

        target: GlobalConfig.services
    }
}
