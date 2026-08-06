local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local SellingSlice = require(ReplicatedStorage.Source.Features.Selling.SellingSlice)

local e = React.createElement

local function SlimeDepositBillboard()
	local deposits = ReactCharm.useAtom(SellingSlice.state.deposits)
	local billboards = {}

	for entryId, entry in deposits do
		billboards[entryId] = e("BillboardGui", {
			Adornee = entry.adornee,
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 100,
			Size = UDim2.fromScale(6, 1.6),
		}, {
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Size = UDim2.fromScale(1, 1),
				Text = "Deposit Slime",
				TextColor3 = Color3.fromRGB(65, 255, 55),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, {
				Stroke = e("UIStroke", {
					Color = Color3.new(0, 0, 0),
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 3,
				}),
				TextSizeConstraint = e("UITextSizeConstraint", {
					MaxTextSize = 36,
					MinTextSize = 1,
				}),
			}),
		})
	end

	return e(React.Fragment, nil, billboards)
end

return SlimeDepositBillboard
