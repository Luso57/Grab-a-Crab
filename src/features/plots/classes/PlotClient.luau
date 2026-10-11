--!strict

local Players = game:GetService("Players")

local PlotClient = {}
PlotClient.__index = PlotClient

export type PlotClient = typeof(setmetatable({} :: {
	index: number,
	model: Model,
	ownerUserId: number,
	ownerChangedConnection: RBXScriptConnection?,
}, PlotClient))

function PlotClient.new(model: Model): PlotClient
	local index = model:GetAttribute("Index") :: number

	local ownerUserId = model:GetAttribute("OwnerUserId")
	local self = setmetatable({
		index = index,
		model = model,
		ownerUserId = if type(ownerUserId) == "number" then ownerUserId else 0,
		ownerChangedConnection = nil :: RBXScriptConnection?,
	}, PlotClient) :: PlotClient

	self.ownerChangedConnection = model:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		local owner = model:GetAttribute("OwnerUserId")
		self.ownerUserId = if type(owner) == "number" then owner else 0
	end)

	return self
end

function PlotClient.isLocal(self: PlotClient): boolean
	return self.ownerUserId == Players.LocalPlayer.UserId
end

function PlotClient.destroy(self: PlotClient)
	if self.ownerChangedConnection then
		self.ownerChangedConnection:Disconnect()
		self.ownerChangedConnection = nil
	end
end

return PlotClient
