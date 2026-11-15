--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

type MenuName = "Index" | "ShopMono" | "Settings"

local activeMenu = Vide.source(nil :: MenuName?)

local PopupMenuState = {}

function PopupMenuState.isOpen(menuName: MenuName): () -> boolean
	return function()
		return activeMenu() == menuName
	end
end

function PopupMenuState.isOtherOpen(menuName: MenuName): () -> boolean
	return function()
		return activeMenu() ~= nil and activeMenu() ~= menuName
	end
end

function PopupMenuState.toggle(menuName: MenuName)
	activeMenu(if activeMenu() == menuName then nil else menuName)
end

function PopupMenuState.close(menuName: MenuName)
	if activeMenu() == menuName then
		activeMenu(nil)
	end
end

return PopupMenuState
