import QtQuick

import org.kde.plasma.extras as PlasmaExtras

// Plasma 6 moved the QMenu wrapper out of PlasmaComponents2 and into
// PlasmaExtras, but kept the API (content/visualParent/placement/openRelative/
// addMenuItem/removeMenuItem).
// https://invent.kde.org/plasma/libplasma/-/blob/master/src/declarativeimports/plasmaextracomponents/qmenu.cpp
//
// NOTE: the item components are resolved lazily via Qt.createComponent() rather
// than declared as inline `Component { ContextSubMenu {} }`. ContextSubMenu
// itself contains a ContextMenu, so an inline declaration forms a circular
// compile time type dependency and Qt 6 fails both files with
// "Type ContextMenu unavailable".
PlasmaExtras.Menu {
	id: contextMenu

	property var _menuItemComponent: null
	property var _subMenuComponent: null

	function _componentFor(fileName, cached) {
		if (cached && cached.status === Component.Ready) {
			return cached
		}
		var comp = Qt.createComponent(Qt.resolvedUrl(fileName))
		if (comp.status === Component.Error) {
			console.log('ContextMenu: failed to load', fileName, comp.errorString())
			return null
		}
		return comp
	}

	function newMenuItem() {
		_menuItemComponent = _componentFor("ContextMenuItem.qml", _menuItemComponent)
		return _menuItemComponent ? _menuItemComponent.createObject(contextMenu) : null
	}

	function newSeperator() {
		var item = newMenuItem()
		if (item) {
			item.separator = true
		}
		return item
	}

	function newSubMenu() {
		_subMenuComponent = _componentFor("ContextSubMenu.qml", _subMenuComponent)
		return _subMenuComponent ? _subMenuComponent.createObject(contextMenu) : null
	}

	property bool clearBeforeOpen: true
	signal beforeOpen(var menu)

	function removeAllItems() {
		// clearMenuItems() causes a segfault when trying to destroy a submenu,
		// so tear each one down manually instead.
		for (var i = content.length - 1; i >= 0; i--) {
			var item = content[i]
			if (item.hasOwnProperty("subContextMenu") && item.subContextMenu) {
				item.subContextMenu.removeAllItems() // for a sub-sub-menu
				item.subContextMenu.destroy() // or it segfaults on the 2nd open
			}
			removeMenuItem(item) // or it segfaults on the 3rd open
			item.destroy()
		}
	}

	function doBeforeOpen() {
		if (clearBeforeOpen) {
			removeAllItems()
		}
		beforeOpen(contextMenu)
	}

	function show(x, y) {
		doBeforeOpen()
		open(x, y)
	}

	function showRelative() {
		doBeforeOpen()
		openRelative()
	}

	function showBelow(item) {
		visualParent = item
		placement = PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
		showRelative()
	}
}
