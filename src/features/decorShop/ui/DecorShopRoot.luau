--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopRoot = require(ReplicatedStorage.Source.Features.Shop.UI.ShopRoot)

local DecorShopRoot = {}

function DecorShopRoot.create(props: ShopRoot.Props): Instance
	return ShopRoot({
		items = props.items,
		stock = props.stock,
		isOpen = props.isOpen,
		refreshSeconds = props.refreshSeconds,
		refreshLabel = "Decor Refresh",
		title = "DECORATIONS",
		menuName = "DecorShopMenu",
		titleMaxTextSize = 46,
		onClose = props.onClose,
		onBuy = props.onBuy,
		onRobuxBuy = props.onRobuxBuy,
	})
end

return DecorShopRoot
