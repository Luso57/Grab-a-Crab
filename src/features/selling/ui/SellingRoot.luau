local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CollectCashBillboard = require(ReplicatedStorage.Source.Features.Selling.UI.Screens.CollectCashBillboard)
local SlimeDepositBillboard = require(
	ReplicatedStorage.Source.Features.Selling.UI.Screens.SlimeDepositBillboard
)
local SlimeQueueSign = require(ReplicatedStorage.Source.Features.Selling.UI.Screens.SlimeQueueSign)
local UpgradePerSecondBillboard = require(
	ReplicatedStorage.Source.Features.Selling.UI.Screens.UpgradePerSecondBillboard
)

local function SellingRoot()
	return React.createElement(React.Fragment, nil, {
		CollectCashBillboard = React.createElement(CollectCashBillboard),
		SlimeDepositBillboard = React.createElement(SlimeDepositBillboard),
		SlimeQueueSign = React.createElement(SlimeQueueSign),
		UpgradePerSecondBillboard = React.createElement(UpgradePerSecondBillboard),
	})
end

return SellingRoot
