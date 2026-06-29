import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts

Scope {
  id: lockScope

  property bool authenticating: false
  property string errorMessage: ""
  property string pendingPassword: ""

  function tryAuth(password: string) {
    if (lockScope.authenticating)
      return;
    lockScope.authenticating = true;
    lockScope.errorMessage = "";
    lockScope.pendingPassword = password;
    pam.start();
  }

  Connections {
    function onLockedChanged() {
      sessionLock.locked = LockService.locked;
    }

    target: LockService
  }
  IpcHandler {
    function lock(): void {
      LockService.locked = true;
    }

    target: "lock"
  }
  PamContext {
    id: pam

    config: "quickshell"

    onCompleted: result => {
      lockScope.authenticating = false;

      if (result === PamResult.Success) {
        lockScope.errorMessage = "";
        LockService.locked = false;
      } else {
        lockScope.errorMessage = "Authentication failed";
        errorTimer.restart();
      }
    }
    onError: error => {
      console.warn("[Lock] PAM error:", PamError.toString(error));
      lockScope.authenticating = false;
      lockScope.errorMessage = "Auth error";
      errorTimer.restart();
    }
    onPamMessage: {
      if (pam.responseRequired) {
        pam.respond(lockScope.pendingPassword);
        lockScope.pendingPassword = "";
      }
    }
  }
  Timer {
    id: errorTimer

    interval: 3000

    onTriggered: lockScope.errorMessage = ""
  }
  WlSessionLock {
    id: sessionLock

    surface: Component {
      WlSessionLockSurface {
        id: lockSurface

        function requestPasswordFocus() {
          focusRetryTimer.restart();
          Qt.callLater(() => passwordField.forceActiveFocus());
        }

        color: "#141414"

        Component.onCompleted: {
          lockSurface.requestPasswordFocus();
        }

        // Click anywhere to recover focus
        MouseArea {
          anchors.fill: parent

          onClicked: lockSurface.requestPasswordFocus()
        }
        Connections {
          function onLockedChanged() {
            if (LockService.locked)
              lockSurface.requestPasswordFocus();
          }

          target: LockService
        }
        Timer {
          id: focusRetryTimer

          interval: 75
          repeat: false

          onTriggered: passwordField.forceActiveFocus()
        }
        Timer {
          id: clockTimer

          interval: 1000
          repeat: true
          running: true

          onTriggered: {
            timeLabel.text = Qt.formatTime(new Date(), "hh:mm");
            dateLabel.text = Qt.formatDate(new Date(), "dddd, MMMM d");
          }
        }
        ColumnLayout {
          anchors.centerIn: parent
          spacing: 8

          Text {
            id: timeLabel

            Layout.alignment: Qt.AlignHCenter
            color: "#ffffff"
            font.letterSpacing: 2
            font.pixelSize: 96
            font.weight: Font.Thin
            text: Qt.formatTime(new Date(), "hh:mm")
          }
          Text {
            id: dateLabel

            Layout.alignment: Qt.AlignHCenter
            color: "#aaaaaa"
            font.pixelSize: 22
            font.weight: Font.Normal
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
          }
          Item {
            Layout.preferredHeight: 40
          }
          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            border.color: lockScope.errorMessage ? "#ff453a" : passwordField.activeFocus ? "#5ac8fa" : "#3a3a3a"
            border.width: 1
            color: "#2a2a2a"
            height: 40
            radius: 20
            width: 260

            Behavior on border.color {
              ColorAnimation {
                duration: 150
              }
            }

            TextInput {
              id: passwordField

              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              clip: true
              color: "#ffffff"
              echoMode: TextInput.Password
              enabled: !lockScope.authenticating
              focus: true
              font.pixelSize: 15
              verticalAlignment: Text.AlignVCenter

              Keys.onReturnPressed: {
                if (passwordField.text && !lockScope.authenticating) {
                  lockScope.tryAuth(passwordField.text);
                  passwordField.text = "";
                }
              }

              // Re-grab focus when re-enabled after auth attempt
              onEnabledChanged: {
                if (enabled)
                  lockSurface.requestPasswordFocus();
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#666666"
                font.pixelSize: 15
                text: lockScope.authenticating ? "Authenticating..." : "Enter Password"
                visible: !passwordField.text
              }
            }
          }
          Text {
            Layout.alignment: Qt.AlignHCenter
            color: "#ff453a"
            font.pixelSize: 13
            text: lockScope.errorMessage
            visible: lockScope.errorMessage !== ""
          }
          Item {
            Layout.preferredHeight: 16
          }
        }
      }
    }

    onLockStateChanged: {
      if (!locked) {
        LockService.locked = false;
      }
    }
  }
}
