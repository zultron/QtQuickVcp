import QtQuick 2.0
import QtQuick.Controls 1.2
import Machinekit.Application 1.0

Label {
    property alias core: object.core
    property alias status: object.status

    property bool _ready: status.synced
    property var _mcodes: _ready ? status.interp.mcodes : []
    property var _gcodes: _ready ? status.interp.gcodes : []

    text: {
        var mcodes = ""
        for (var i = 1; i < _mcodes.length; ++i) {
            if (_mcodes[i] > -1) {
                mcodes += "M" + _mcodes[i].toString() + " "
            }
        }
        var gcodes = ""
        for (var i = 1; i < _gcodes.length; ++i) {
            if (_gcodes[i] > -1) {
                gcodes += "G" + (_gcodes[i]/10).toString() + " "
            }
        }
        return gcodes + mcodes
    }

    ApplicationObject {
        id: object
    }
}
