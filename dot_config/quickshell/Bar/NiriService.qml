pragma Singleton

import Quickshell
import qs.Config as SC
import Niri 0.1

Singleton {
	property Niri instance: Niri {
		miniMapHeight: SC.Config.sizes.small + 2

		onErrorOccurred: message => {
			console.error("Error:", message);
		}
	}
}
