class_name FragmentNames
extends RefCounted
## Подписи перенесённых фрагментов — то, что видит игрок, войдя в объём.

const KIOSK_SIGNS := ["ПРЕССА", "ТАБАК", "ЦВЕТЫ", "КВАС", "РЕМОНТ ОБУВИ", "ШАУРМА", "ОПТИКА", "ЛОТО"]
const TOWNS := ["Тверь", "Кимры", "Луга", "Бежецк", "Ржев", "Торжок", "Осташков", "Валдай", "Сасово", "Энгельс"]
const STOPS := ["Улица Мира", "Школа", "Посёлок Энергетиков", "Рынок", "Больница", "Кольцо", "Дом культуры"]
const ERAS := ["1974", "1983", "1991", "1998", "2004", "2011", "2019", "2023", "1968", "1987"]


static func pick(arr: Array, seed_value: int, salt: int) -> Variant:
	return arr[WorldGen.ihash(seed_value, salt, 97) % arr.size()]


static func title_for(v: Dictionary) -> String:
	var s: int = v.seed
	var era: String = pick(ERAS, s, 1)
	match v.type:
		"minigolf":
			return "Минигольф «Пасть динозавра» · радиус 14 м"
		"house":
			return "Дом с магазином «Продукты» · ул. Садовая, 14 · радиус 11 м"
		"road":
			return "Кусок дороги на %s · примерно %s год · радиус %d м" % [pick(TOWNS, s, 2), era, int(v.radius)]
		"shed":
			return "Дачный участок · сарай · примерно %s год · радиус %d м" % [era, int(v.radius)]
		"kiosk":
			return "Киоск «%s» у остановки · радиус %d м" % [pick(KIOSK_SIGNS, s, 3), int(v.radius)]
		"field":
			return "Край пшеничного поля · радиус %d м" % int(v.radius)
		"garages":
			return "Гаражный кооператив · радиус %d м" % int(v.radius)
	return "Перенесённый фрагмент"
