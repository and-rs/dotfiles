import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import qs.Bar

Scope {
  id: lockScope

  property bool authenticating: false
  property string errorMessage: ""
  property string pendingPassword: ""

  Component.onCompleted: {
    console.log("[Lock] module loaded successfully");
  }

  Connections {
    target: LockService
    function onLockedChanged() {
      console.log("[Lock] LockService.locked changed to:", LockService.locked);
      sessionLock.locked = LockService.locked;
    }
  }

  IpcHandler {
    target: "lock"
    function lock(): void {
      console.log("[Lock] IPC lock called");
      LockService.locked = true;
    }
  }

  PamContext {
    id: pam
    config: "quickshell"

    onPamMessage: {
      console.log("[Lock] PAM message:", pam.message, "responseRequired:", pam.responseRequired);
      if (pam.responseRequired) {
        console.log("[Lock] responding to PAM");
        pam.respond(lockScope.pendingPassword);
        lockScope.pendingPassword = "";
      }
    }

    onCompleted: result => {
      console.log("[Lock] PAM completed:", PamResult.toString(result));
      lockScope.authenticating = false;

      if (result === PamResult.Success) {
        console.log("[Lock] auth success, unlocking");
        lockScope.errorMessage = "";
        LockService.locked = false;
      } else {
        console.log("[Lock] auth failed");
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
    console.log("[Lock] starting PAM auth");
    pam.start();
  }

  WlSessionLock {
    id: sessionLock

    onLockStateChanged: {
      console.log("[Lock] lockStateChanged, locked=" + locked + " secure=" + secure);
      if (!locked) {
        LockService.locked = false;
      }
    }

    surface: Component {
      WlSessionLockSurface {
        color: "#141414"

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
