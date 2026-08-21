export type ProductKey =
	"doubleRolls"
	| "doubleRollSpeed"
	| "doublePermanentLuck"
	| "quadruplePermanentLuck"
	| "autoCollect"
	| "autoCollectSlime"
	| "doubleCash"
	| "doubleSlimeDeposit"
	| "buyCommonSlime"
	| "buyUncommonSlime"
	| "buyRareSlime"
	| "buyEpicSlime"
	| "buyLegendarySlime"
	| "buyExoticSlime"
	| "buySecretSlime"
	| "buyUpgradeOne"
	| "buyUpgradeTen"
	| "luck5Spin"
	| "finishNow"
	| "skipRebirth"
	| "doubleOfflineSlime"

export type Product = {
	id: number,
	permanent: boolean,
}

export type ProductInfo = {
	Name: string,
	Description: string,
	PriceInRobux: number?,
	IsForSale: boolean,
	IconImageAssetId: number?,
}

export type ReceiptInfo = {
	PlayerId: number,
	ProductId: number,
	PurchaseId: string,
	CurrencySpent: number,
	PlaceIdWherePurchased: number,
}

export type ReceiptHandler = (player: Player, receiptInfo: ReceiptInfo) -> boolean

return {}
