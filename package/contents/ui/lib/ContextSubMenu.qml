import QtQuick

// A MenuItem whose action owns a nested menu. QMenuProxy::setVisualParent()
// still calls QAction::setMenu() when handed a QAction, same as Plasma 5.
//
// The nested ContextMenu is created on demand (see ContextMenu.qml) to avoid a
// circular compile time dependency between the two files.
ContextMenuItem {
	id: subMenuItem

	property var subContextMenu: null

	function menu() {
		if (!subContextMenu) {
			var comp = Qt.createComponent(Qt.resolvedUrl("ContextMenu.qml"))
			if (comp.status === Component.Error) {
				console.log('ContextSubMenu: failed to load ContextMenu.qml', comp.errorString())
				return null
			}
			subContextMenu = comp.createObject(subMenuItem, {
				visualParent: subMenuItem.action,
			})
		}
		return subContextMenu
	}

	function newSeperator() {
		return menu().newSeperator()
	}
	function newMenuItem() {
		return menu().newMenuItem()
	}
	function newSubMenu() {
		return menu().newSubMenu()
	}
	function addMenuItem(menuItem) {
		menu().addMenuItem(menuItem)
	}

	Component.onCompleted: menu() // ensure the QAction owns its submenu early
}
