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

  Connections {
    target: LockService
    function onLockedChanged() {
      sessionLock.locked = LockService.locked;
    }
  }

  IpcHandler {
    target: "lock"
    function lock(): void {
      LockService.locked = true;
    }
  }

  PamContext {
    id: pam
    config: "quickshell"

    onPamMessage: {
      if (pam.responseRequired) {
        pam.respond(lockScope.pendingPassword);
        lockScope.pendingPassword = "";
      }
    }

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
  }

  Timer {
    id: errorTimer
    interval: 3000
    onTriggered: lockScope.errorMessage = ""
  }

  function tryAuth(password: string) {
    if (lockScope.authenticating) return;
    lockScope.authenticating = true;
    lockScope.errorMessage = "";
    lockScope.pendingPassword = password;
    pam.start();
  }

  WlSessionLock {
    id: sessionLock

    onLockStateChanged: {
      if (!locked) {
        LockService.locked = false;
      }
    }

    surface: Component {
      WlSessionLockSurface {
        id: lockSurface
        color: "#141414"

        function requestPasswordFocus() {
          focusRetryTimer.restart();
          Qt.callLater(() => passwordField.forceActiveFocus());
        }

        // Click anywhere to recover focus
        MouseArea {
          anchors.fill: parent
          onClicked: lockSurface.requestPasswordFocus()
        }

        Component.onCompleted: {
          lockSurface.requestPasswordFocus();
        }

        Connections {
          target: LockService

          function onLockedChanged() {
            if (LockService.locked)
              lockSurface.requestPasswordFocus();
          }
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
          running: true
          repeat: true
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
            text: Qt.formatTime(new Date(), "hh:mm")
            color: "#ffffff"
            font.pixelSize: 96
            font.weight: Font.Thin
            font.letterSpacing: 2
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            id: dateLabel
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            color: "#aaaaaa"
            font.pixelSize: 22
            font.weight: Font.Normal
            Layout.alignment: Qt.AlignHCenter
          }

          Item { Layout.preferredHeight: 40 }

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 260
            height: 40
            radius: 20
            color: "#2a2a2a"
            border.color: lockScope.errorMessage ? "#ff453a"
                        : passwordField.activeFocus ? "#5ac8fa"
                        : "#3a3a3a"
            border.width: 1

            Behavior on border.color {
              ColorAnimation { duration: 150 }
            }

            TextInput {
              id: passwordField
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              verticalAlignment: Text.AlignVCenter
              color: "#ffffff"
              font.pixelSize: 15
              echoMode: TextInput.Password
              clip: true
              focus: true
              enabled: !lockScope.authenticating

              // Re-grab focus when re-enabled after auth attempt
              onEnabledChanged: {
                if (enabled) lockSurface.requestPasswordFocus();
              }

              Keys.onReturnPressed: {
                if (passwordField.text && !lockScope.authenticating) {
                  lockScope.tryAuth(passwordField.text);
                  passwordField.text = "";
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: lockScope.authenticating ? "Authenticating..." : "Enter Password"
                color: "#666666"
                font.pixelSize: 15
                visible: !passwordField.text
              }
            }
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: lockScope.errorMessage
            color: "#ff453a"
            font.pixelSize: 13
            visible: lockScope.errorMessage !== ""
          }

          Item { Layout.preferredHeight: 16 }
        }
      }
    }
  }
}
