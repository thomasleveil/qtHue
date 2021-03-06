import QtQuick 2.4
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import QtQuick.LocalStorage 2.0
import "./content"
import "content/functions.js" as Functions

ApplicationWindow {
    visible: true
    title: qsTr("qtHue")
    width: 1360
    height: 768
    Rectangle {
        id: background
        color: "#212126"
        anchors.fill: parent
    }

    property string bridgeIp: "127.0.0.1"
    property string username: ""
    property string locale: "en_RO"
    property string city: "city"
    property string apikey: "apikey"  //free registration on openweathermap.org

    ///end user configuration
    property bool any_on: false
    property bool bridgeConnected: false
    property var config: { "groups": {}, "lights": {}, "scenes": {} }

    FontLoader {
        source: "content/fontawesome-webfont.ttf"
    }


    function pyconn(reqType, path, data, callback) {
        var xhr = new XMLHttpRequest
        xhr.open(reqType,
                 'http://' + bridgeIp + '/api/' + username + path, true)
        xhr.setRequestHeader("Content-type", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4 && xhr.status === 200) {
                var response = JSON.parse(xhr.responseText)
                callback(response)
                return response.length
            } else if (xhr.readyState === 4 && xhr.status === 0 && stackView.currentItem.objectName !== "BridgeConnect") {
                stackView.push(Qt.resolvedUrl("content/BridgeConnect.qml"))
            }
        }
        xhr.send(JSON.stringify(data))
    }

    function saveWheatherDetails() {
        var db = LocalStorage.openDatabaseSync(
                    "qtHue", "", "Store bridge connection data", 10000)
        db.transaction(function (tx) {
            tx.executeSql('UPDATE hue_bridge SET city = "' + city + '", apikey = "' + apikey + '"' )
        })
    }

    function bridgePair(data) {
        if ("success" in data[0]) {
            username = data[0]["success"]["username"]
            pyconn('GET', '', {

                   }, Functions.updateLightsStatus)
            var db = LocalStorage.openDatabaseSync(
                        "qtHue", "", "Store bridge connection data", 10000)
            db.transaction(function (tx) {
                // Create the database if it doesn't already exist
                tx.executeSql('UPDATE hue_bridge SET username = "'
                              + data[0]["success"]["username"] + '", ip = "' + bridgeIp + '"')
            })
            bridgeConnected = true;
        } else {
            bridgeConnected = false;
            console.warn("pair failed")
            stackView.push(Qt.resolvedUrl("content/BridgeConnect.qml"))
        }
    }

    Item {
        Component.onCompleted: {
            Functions.getWeather();
            var db = LocalStorage.openDatabaseSync(
                        "qtHue", "", "Store bridge connection data", 10000)
            db.transaction(function (tx) {
                //tx.executeSql('DROP TABLE hue_bridge')  //just for tests
                // Create the database if it doesn't already exist
                tx.executeSql(
                            'CREATE TABLE IF NOT EXISTS hue_bridge(ip TEXT, username TEXT, city TEXT, apikey TEXT)')

                var rs = tx.executeSql('SELECT * FROM hue_bridge')
                if (rs.rows.length === 0) {
                    tx.executeSql('INSERT INTO hue_bridge VALUES(?, ?, ?, ?)',
                                  ['', '', '', ''])
                    stackView.push(Qt.resolvedUrl("content/BridgeConnect.qml"))
                    pyconn('POST', '', {
                                         devicetype: "qtHue#diyHue"
                                     }, bridgePair)
                } else {
                    bridgeIp = rs.rows.item(0).ip
                    username = rs.rows.item(0).username
                    city = rs.rows.item(0).city
                    apikey = rs.rows.item(0).apikey
                    pyconn('GET', '', {

                                     }, Functions.updateLightsStatus)
                }
            })
        }
    }





    toolBar: BorderImage {

        border.bottom: 8
        source: "content/images/toolbar.png"
        width: parent.width
        height: 60

        Rectangle {
            id: menu
            x: 5
            anchors.verticalCenter: parent.verticalCenter
            width: 65
            antialiasing: true
            height: 50
            radius: 4
            color: menumouse.pressed ? "#222" : "transparent"
            Behavior on x {
                NumberAnimation {
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: menu_img
                anchors.centerIn: parent
                font.pointSize: 25
                font.family: "FontAwesome"
                color: "#cccccc"
                text: "\uf0c9"

                MouseArea {
                    id: menumouse
                    anchors.fill: parent
                    anchors.margins: -10
                    onClicked: {
                        if (menu_context.state === "OPEN") {
                            menu_context.state = "CLOSE";
                        } else {
                            menu_context.state = "OPEN";
                        }
                    }
                }
            }

            Rectangle {
                id: linie_menu
                anchors.left: parent.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 45
                color: "#424246"
            }
        }

        ////home image
        Item {
            id: home
            anchors.left: menu.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            height: 50

            Rectangle {
                id: home_background
                anchors.fill: parent
                anchors.leftMargin: 7
                antialiasing: true
                radius: 4
                color: homemouse.pressed ? "#222" : "transparent"
            }

            Text {
                id: home_img
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 18
                font.pointSize: 25
                font.family: "FontAwesome"
                color: any_on ? "#cccccc" : "#3a3a3a"
                text: "\uf015"
            }

            MouseArea {
                id: homemouse
                anchors.fill: parent
                anchors.margins: -10
                onClicked: {
                    pyconn('PUT', '/groups/0/action', {
                               on: !any_on
                           }, noCallback)
                    any_on = !any_on
                    for (var i = 0; i < groupsModel.count; i++) {
                        groupsModel.set(i, {
                                            on: any_on
                                        })
                    }
                }
            }
        }
        /////////////////////////
        Text {
            id: clock_txt
            font {
                family: "Droid Sans Regular"
                pixelSize: 45
            }
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 3
        }
        Text {
            id: zi_txt
            font {
                family: "Droid Sans Regular"
                pixelSize: 22
            }
            color: "white"
            anchors.right: parent.right
            anchors.rightMargin: 7 + clock_txt.width
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
        }
        Text {
            id: date_txt
            font {
                family: "Droid Sans Regular"
                pixelSize: 16
            }
            color: "white"
            anchors.right: parent.right
            anchors.rightMargin: 7 + clock_txt.width
            anchors.top: parent.top
            anchors.topMargin: 8
        }
        Text {
            id: nr_zi
            font {
                family: "Droid Sans Regular"
                pixelSize: 22
            }
            color: "#17aff6"
            anchors.right: parent.right
            anchors.rightMargin: 8 + clock_txt.width + date_txt.width
            anchors.top: parent.top
            anchors.topMargin: 1
        }
        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: {
                var date = new Date()
                clock_txt.text = date.toLocaleTimeString(Qt.locale(locale),
                                                         "hh:mm")
                date_txt.text = date.toLocaleDateString(Qt.locale(locale),
                                                        "MMM yyyy")
                zi_txt.text = date.toLocaleDateString(Qt.locale(locale), "dddd")
                nr_zi.text = date.toLocaleDateString(Qt.locale(locale), "d")
                if (date.toLocaleTimeString(Qt.locale(locale),
                                            "s").slice(-1) === "0") {
                    pyconn('GET', '', {

                           }, Functions.updateLightsStatus)
                    Functions.getWeather();
                }
            }
        }
        Rectangle {
            id: linie_data
            x: nr_zi.x < zi_txt.x? nr_zi.x - 10 : zi_txt.x - 10
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 40
            color: "#424246"
        }

        Image {
            id: wheather_icon
            anchors.right: linie_data.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 5
        }

        Text {
            id: temperature
            font {
                family: "Droid Sans Regular"
                pixelSize: 36
            }
            color: "white"
            anchors.right: wheather_icon.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 7
            //text: "Bucarest 5°C"
        }

    }


    ListModel {
        id: groupsModel
    }

    ListModel {
        id: scenesModel
    }


    Component {
        id: switchStyle
        SwitchStyle {

            groove: Rectangle {
                implicitHeight: 55
                implicitWidth: 120
                radius: 5
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    radius: 3
                    width: parent.width / 2 - 2
                    height: 20
                    anchors.margins: 2
                    color: control.checked ? "#468bb7" : "#222"
                    Behavior on color {
                        ColorAnimation {
                        }
                    }
                    Text {
                        font.pixelSize: 18
                        color: "white"
                        anchors.centerIn: parent
                        text: "ON"
                    }
                }
                Item {
                    width: parent.width / 2
                    height: parent.height
                    anchors.right: parent.right
                    Text {
                        font.pixelSize: 18
                        color: "white"
                        anchors.centerIn: parent
                        text: "OFF"
                    }
                }
                color: "#222"
                border.color: "#444"
                border.width: 2
            }
            handle: Rectangle {
                width: parent.parent.width / 2
                height: control.height
                radius: 5
                color: "#444"
                border.color: "#555"
                border.width: 2
            }
        }
    }

    Component {
        id: touchStyle
        SliderStyle {
            handle: Rectangle {
                width: 30
                height: 30
                radius: height
                antialiasing: true
                color: Qt.lighter("#468bb7", 1.2)
            }

            groove: Item {
                implicitHeight: 50
                implicitWidth: 240
                Rectangle {
                    height: 8
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#444"
                    opacity: 0.8
                    Rectangle {
                        antialiasing: true
                        radius: 1
                        color: "#468bb7"
                        height: parent.height
                        width: parent.width * control.value / control.maximumValue
                    }
                }
            }
        }
    }


    //////
    StackView {
        id: stackView
        anchors.fill: parent
        focus: true
        initialItem: GridView {
            id: gridViewProduse
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            model: groupsModel
            delegate: GroupStyle {

            }

            cellWidth: 460
            //cellHeight: 90
            flow: GridView.FlowTopToBottom
            interactive: false
            cacheBuffer: 1024
            focus: true
        }


        transitions: Transition {
            NumberAnimation {
                properties: "y,height"
                duration: 160
                easing.type: Easing.OutQuint
            }
        }
    }

    ListModel {
        id: menuModel
        ListElement {
            name: "Home"
            page: "main.qml"
        }
        ListElement {
            name: "Bridge"
            page: "/content/BridgeConnect.qml"
        }
        ListElement {
            name: "Weather"
            page: "/content/Weather.qml"
        }
    }

    Menu {
        id: menu_context
    }

    Color {
        id: color
    }
}
