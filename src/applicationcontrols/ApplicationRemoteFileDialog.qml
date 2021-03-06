import QtQuick 2.2
import QtQuick.Controls 1.2
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.0
import Machinekit.Application 1.0

Dialog {
    property var core: null
    property var status: core === null ? {"synced": false} : core.status
    property var command: core === null ? {"ready": false} : core.command
    property var file: core === null ? {"localPath":"", "remotePath":"", "localFilePath":"", "ready":false} : core.file
    property var fileDialog: null
    property alias width: content.implicitWidth
    property alias height: content.implicitHeight

    property bool _ready: status.synced && file.ready && (file.transferState === ApplicationFile.NoTransfer)

    QtObject {
        id: d
        property string rootFolder: ""
        property string currentFolder: ""
        readonly property string serverFolder: rootFolder + currentFolder

        readonly property bool directorySelected: (tableView.currentRow > -1) && tableView.model.getIsDir(tableView.currentRow)

        onServerFolderChanged: {
            if (root.file !== undefined) {
                root.file.serverDirectory = serverFolder;
                if (root.file.refreshFiles) {
                    root.file.refreshFiles();
                }
            }
        }

        function folderUp(folder) {
            var pos = folder.lastIndexOf("/", folder.length-2);
            if (pos > -1) {
                folder = folder.slice(0, pos+1);
            }
            else if (folder !== "") {
                folder = "";
            }

            return folder;
        }

        function openFile(row) {
            if (row < 0) {
                return;
            }

            if (status.task.taskMode !== ApplicationStatus.TaskModeAuto) {
                command.setTaskMode('execute', ApplicationCommand.TaskModeAuto);
            }
            command.resetProgram('execute');
            var dir = tableView.model.getIsDir(row);
            var fileName = tableView.model.getName(row);
            if (dir) {
                d.currentFolder += fileName + "/";
                deselectRow();
            }
            else {
                var newPath = file.remotePath + '/' + file.serverDirectory + '/' + fileName;
                command.openProgram('execute', newPath);
                root.close();
            }
        }

        function removeFile(row) {
            if (row < 0) {
                return;
            }

            var fileName = tableView.model.getName(row);
            var dir = tableView.model.getIsDir(row);
            if (!dir) {
                file.removeFile(fileName);
            }
            else {
                file.removeDirectory(fileName);
            }
            deselectRow();
        }

        function createDirectory(name) {
            file.createDirectory(name);
            deselectRow();
        }

        function uploadFileDialog() {
            root.close();
            fileDialog.open();
        }

        function uploadFile(url) {
            file.localFilePath = url;
            file.startUpload();
        }

        function deselectRow() {
            tableView.currentRow = -1;
        }
    }

    SystemPalette { id: systemPalette }

    id: root
    title: qsTr("Remote Files")

    contentItem: Rectangle {
        id: content
        color: systemPalette.window

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Screen.pixelDensity

        RowLayout {
            id: header

            Button {
                text: qsTr("Up")
                iconName: "go-up"
                onClicked: d.currentFolder = d.folderUp(d.currentFolder);
            }

            Label {
                text: (".../" + d.currentFolder).split("/").join(" / ")
            }
        }

        TableView {
            id: tableView
            Layout.fillHeight: true
            Layout.fillWidth: true
            enabled: _ready
            model: file.model

            TableViewColumn {
                role: "name"
                title: qsTr("Name")
                width: root.width * 0.4
            }
            TableViewColumn {
                role: "size"
                title: qsTr("Size")
                width: root.width * 0.2
            }
            TableViewColumn {
                role: "lastModified"
                title: qsTr("Last Modified")
                width: root.width * 0.3
            }

            onDoubleClicked: d.openFile(row)
            onPressAndHold: fileMenu.popup()
            Keys.onReturnPressed: d.openFile(currentRow)
            Keys.onDeletePressed: d.removeFile(currentRow)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: {
                    fileMenu.popup();
                }
            }

            DropArea {
                anchors.fill: parent
                onDropped: {
                    if (drop.hasUrls) {
                        d.uploadFile(drop.urls[0]);
                    }
                }
            }

            Menu {
                id: fileMenu
                MenuItem {
                    text: d.directorySelected ? qsTr("Open directory") : qsTr("Open file")
                    enabled: _ready && (tableView.currentRow > -1)
                    onTriggered: d.openFile(tableView.currentRow)
                }

                MenuItem {
                    text: d.directorySelected ? qsTr("Remove directory") : qsTr("Remove file")
                    enabled: _ready && (tableView.currentRow > -1)
                    onTriggered: d.removeFile(tableView.currentRow)
                }

                MenuItem {
                    text: qsTr("Upload file...")
                    enabled: _ready
                    onTriggered: d.uploadFileDialog()
                }

                MenuItem {
                    text: qsTr("Create directory")
                    enabled: _ready
                    onTriggered: directoryNameDialog.open()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            ApplicationProgressBar {
                Layout.fillWidth: true
            }

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Refresh")
                enabled: _ready
                iconName: "view-refresh"
                onClicked: file.refreshFiles()
            }

            Button {
                text: qsTr("Upload...")
                enabled: _ready
                iconName: "document-open"
                onClicked: d.uploadFileDialog()
            }

            Button {
                text: qsTr("Remove")
                iconName: "edit-delete"
                enabled: _ready && (tableView.currentRow > -1)
                onClicked: d.removeFile(tableView.currentRow)
            }

            Button {
                text: qsTr("Open")
                iconName: "document-open-remote"
                enabled: _ready && (tableView.currentRow > -1)
                onClicked: d.openFile(tableView.currentRow)
            }

            Button {
                text: qsTr("Close")
                iconName: "dialog-close"
                onClicked: root.close()
            }
        }
    }
    }

    Dialog {
        id: directoryNameDialog
        standardButtons: StandardButton.Ok | StandardButton.Cancel
        title: qsTr("Enter Directory Name")

        onVisibleChanged: {
            if (visible) {
                textField.text = "";
                textField.forceActiveFocus();
            }
        }

        TextField {
            id: textField
            anchors.fill: parent
        }

        onAccepted: d.createDirectory(textField.text)
    }

    onVisibleChanged: {
        if (visible) {
            file.refreshFiles();
        }
    }

    Component.onCompleted: {
        if (core === null)
        {
            try {
                var x = applicationCore;
                core = Qt.binding(function() { return x; });
            }
            catch (err) {
            }
        }
    }
}

