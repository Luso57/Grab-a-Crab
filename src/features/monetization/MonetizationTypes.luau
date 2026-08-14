export type ProductKey =
	"doubleRolls"
	| "doubleRollSpeed"
	| "doublePermanentLuck"
	| "quadruplePermanentLuck"
	| "autoCollect"
	| "doubleCash"

export type Product = { id: number }

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
