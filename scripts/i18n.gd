extends Node
## Tiny in-code localisation. Yandex Games tells us the player's language; we ship ru, en and tr.

signal language_changed

const SUPPORTED := ["ru", "en", "tr"]

const S := {
	"title": {"ru": "Алмазная братва", "en": "Bizarre Gems", "tr": "Bizarre Gems"},
	"tagline": {"ru": "Выбивай пары камней крестом на время", "en": "Knock out gem pairs with a cross strike, against the clock", "tr": "Taş çiftlerini çapraz vuruşla kır, süreye karşı"},
	"play": {"ru": "Играть", "en": "Play", "tr": "Oyna"},
	"how_title": {"ru": "Как играть", "en": "How to play", "tr": "Nasıl oynanır"},
	"rule1": {"ru": "Нажми на пустую клетку. Игра смотрит вверх, вниз, влево и вправо и берёт первый камень с каждой стороны.",
		"en": "Tap an empty slot. The game looks up, down, left and right and takes the first gem on each side.",
		"tr": "Boş bir hücreye dokun. Oyun yukarı, aşağı, sola ve sağa bakar ve her yöndeki ilk taşı alır."},
	"rule2": {"ru": "Камни, которые встретились хотя бы дважды, выбиваются.",
		"en": "Every gem that shows up at least twice is knocked out.",
		"tr": "En az iki kez görünen her taş kırılır."},
	"rule3": {"ru": "Промах отнимает секунду. На старте — 120 секунд. В классике партия кончается, когда ходов не осталось.",
		"en": "A miss costs one second. You start with 120 seconds. In Classic the round ends when no moves are left.",
		"tr": "Iska bir saniye kaybettirir. 120 saniyeyle başlarsın. Klasik modda hamle kalmayınca tur biter."},
	"pay2": {"ru": "2 камня: +2 очка", "en": "2 gems: +2 points", "tr": "2 taş: +2 puan"},
	"pay3": {"ru": "3 камня: +4 очка, +1 с", "en": "3 gems: +4 points, +1 s", "tr": "3 taş: +4 puan, +1 sn"},
	"pay4": {"ru": "4 камня: +6 очков, +2 с", "en": "4 gems: +6 points, +2 s", "tr": "4 taş: +6 puan, +2 sn"},
	"time": {"ru": "Время", "en": "Time", "tr": "Süre"},
	"score": {"ru": "Очки", "en": "Score", "tr": "Puan"},
	"best": {"ru": "Рекорд", "en": "Best", "tr": "Rekor"},
	"paused": {"ru": "Пауза", "en": "Paused", "tr": "Duraklatıldı"},
	"resume": {"ru": "Продолжить", "en": "Resume", "tr": "Devam et"},
	"menu": {"ru": "В меню", "en": "Menu", "tr": "Menü"},
	"again": {"ru": "Ещё раз", "en": "Play again", "tr": "Tekrar oyna"},
	"times_up": {"ru": "Время вышло", "en": "Time's up", "tr": "Süre doldu"},
	"stuck": {"ru": "Ходов больше нет", "en": "No moves left", "tr": "Hamle kalmadı"},
	"cleared": {"ru": "Выбито камней: {n} · Полей: {w}", "en": "Gems knocked out: {n} · Boards: {w}", "tr": "Kırılan taş: {n} · Tahta: {w}"},
	"new_best": {"ru": "Новый рекорд!", "en": "New best!", "tr": "Yeni rekor!"},
	"continue_ad": {"ru": "+15 секунд за рекламу", "en": "+15 seconds for an ad", "tr": "Reklam izle, +15 saniye"},
	"shuffle_ad": {"ru": "Перемешать за рекламу", "en": "Shuffle for an ad", "tr": "Reklam izle, karıştır"},
	"leaders": {"ru": "Лидеры", "en": "Leaderboard", "tr": "Lider tablosu"},
	"leaders_loading": {"ru": "Загружаем таблицу…", "en": "Loading the leaderboard…", "tr": "Lider tablosu yükleniyor…"},
	"leaders_empty": {"ru": "Пока никого нет. Сыграй первым!", "en": "No scores yet. Be the first!", "tr": "Henüz skor yok. İlk sen ol!"},
	"leaders_offline": {"ru": "Таблица лидеров работает в Яндекс Играх.", "en": "The leaderboard works on Yandex Games.", "tr": "Lider tablosu Yandex Games'te çalışır."},
	"login": {"ru": "Войти, чтобы попасть в таблицу", "en": "Sign in to get on the board", "tr": "Tabloya girmek için oturum aç"},
	"close": {"ru": "Закрыть", "en": "Close", "tr": "Kapat"},
	"you": {"ru": "Вы", "en": "You", "tr": "Sen"},
	"anon": {"ru": "Игрок", "en": "Player", "tr": "Oyuncu"},
	"ad_failed": {"ru": "Реклама сейчас недоступна, попробуй позже", "en": "No ad available right now, try again later", "tr": "Şu anda reklam yok, daha sonra dene"},
	"plus_time": {"ru": "+15 с", "en": "+15 s", "tr": "+15 sn"},
	"daily": {"ru": "Расклад дня", "en": "Daily board", "tr": "Günün dizilimi"},
	"daily_best": {"ru": "Рекорд дня: {n}", "en": "Today's best: {n}", "tr": "Günün rekoru: {n}"},
	"new_daily_best": {"ru": "Новый рекорд дня!", "en": "New daily best!", "tr": "Yeni günlük rekor!"},
	"rule5": {"ru": "Сверкающие камни дают +5 очков и +2 секунды. Расклад дня — одно и то же поле для всех, обновляется каждые сутки.",
		"en": "Sparkling gems give +5 points and +2 seconds. The daily board is the same layout for everyone and changes every day.",
		"tr": "Işıldayan taşlar +5 puan ve +2 saniye verir. Günün dizilimi herkes için aynıdır ve her gün değişir."},
	"pay_shine": {"ru": "Сверкающий камень: +5 очков, +2 с", "en": "Sparkling gem: +5 points, +2 s", "tr": "Işıldayan taş: +5 puan, +2 sn"},
	"rotate": {"ru": "Поверните телефон вертикально", "en": "Turn your phone upright", "tr": "Telefonunu dikey çevir"},
	"new_board": {"ru": "Новое поле!", "en": "New board!", "tr": "Yeni tahta!"},
	"clear_board": {"ru": "Чистое поле!", "en": "Board cleared!", "tr": "Tahta temizlendi!"},
	"praise_great": {"ru": "Отлично!", "en": "Great!", "tr": "Harika!"},
	"praise_super": {"ru": "Супер!", "en": "Super!", "tr": "Süper!"},
	"praise_wow": {"ru": "Невероятно!", "en": "Incredible!", "tr": "İnanılmaz!"},
	"restart": {"ru": "Заново", "en": "Restart", "tr": "Yeniden"},
	"mode_classic": {"ru": "Классика", "en": "Classic", "tr": "Klasik"},
	"mode_bright": {"ru": "Яркий режим", "en": "Bright mode", "tr": "Parlak mod"},
	"rule_bright": {"ru": "Яркий режим: уровни — каждое новое поле больше и сложнее. Бустеры: бомба (квадрат 3×3), перемешать, +10 секунд; новый бустер за уровень и идеальное комбо. Новый множитель комбо даёт +2 с, каждые 10 ударов подряд +3 с.",
		"en": "Bright mode: levels — every new board is bigger and harder. Boosters: bomb (3×3 square), shuffle, +10 seconds; earn one per level and per perfect combo. A new combo multiplier gives +2 s, every 10 hits in a row +3 s.",
		"tr": "Parlak mod: seviyeler — her yeni tahta daha büyük ve zor. Güçlendiriciler: bomba (3×3 kare), karıştır, +10 saniye; her seviye ve kusursuz kombo için bir tane. Yeni kombo çarpanı +2 sn, üst üste her 10 vuruş +3 sn verir."},
	"choose_mode": {"ru": "Выбор режима", "en": "Choose a mode", "tr": "Mod seç"},
	"mode_classic_desc": {"ru": "Бархат, огранённые камни и широкое поле на 270 самоцветов.", "en": "Velvet, faceted gems and a wide board of 270 jewels.", "tr": "Kadife, kesme taşlar ve 270 mücevherlik geniş tahta."},
	"mode_bright_desc": {"ru": "Крупные яркие плитки, новое поле, как кончились ходы, и смена цвета на комбо.", "en": "Big bright tiles, a new board when moves run out, and colours that change on combos.", "tr": "Büyük parlak karolar, hamle bitince yeni tahta ve kombolarda değişen renkler."},
	"level_up": {"ru": "Уровень {n}!", "en": "Level {n}!", "tr": "Seviye {n}!"},
	"level_short": {"ru": "Ур. {n}", "en": "Lv {n}", "tr": "Sv {n}"},
	"bomb_aim": {"ru": "Нажми, куда бросить бомбу", "en": "Tap where to drop the bomb", "tr": "Bombayı atacağın yere dokun"},
	"booster_got": {"ru": "+1 бустер: {name}", "en": "+1 booster: {name}", "tr": "+1 güçlendirici: {name}"},
	"b_bomb": {"ru": "Бомба", "en": "Bomb", "tr": "Bomba"},
	"b_shuffle": {"ru": "Перемешать", "en": "Shuffle", "tr": "Karıştır"},
	"b_time": {"ru": "+10 секунд", "en": "+10 seconds", "tr": "+10 saniye"},
	"settings": {"ru": "Настройки", "en": "Settings", "tr": "Ayarlar"},
	"sounds": {"ru": "Звуки", "en": "Sound effects", "tr": "Ses efektleri"},
	"music_opt": {"ru": "Музыка", "en": "Music", "tr": "Müzik"},
	"vibration": {"ru": "Вибрация", "en": "Vibration", "tr": "Titreşim"},
	"done": {"ru": "Готово", "en": "Done", "tr": "Tamam"},
	"combo": {"ru": "Комбо", "en": "Combo", "tr": "Kombo"},
	"combo_count": {"ru": "серия {n}", "en": "streak {n}", "tr": "seri {n}"},
	"precise": {"ru": "Точное комбо!", "en": "Precise combo!", "tr": "Hassas kombo!"},
	"perfect": {"ru": "Идеальное комбо!", "en": "Perfect combo!", "tr": "Kusursuz kombo!"},
	"bonus_line": {"ru": "+{p} очков · +{s} с", "en": "+{p} points · +{s} s", "tr": "+{p} puan · +{s} sn"},
	"stats": {"ru": "Лучшая серия: {combo} · Точных комбо: {precise}", "en": "Best streak: {combo} · Precise combos: {precise}", "tr": "En iyi seri: {combo} · Hassas kombo: {precise}"},
	"rule4": {"ru": "Бей без промахов и пауз дольше 3 секунд — растёт комбо и множитель очков. Три удара подряд по 3–4 камня дают точное комбо, четыре и больше — идеальное.",
		"en": "Strike without misses or pauses over 3 seconds to build a combo and a points multiplier. Three strikes in a row of 3–4 gems make a precise combo, four or more a perfect one.",
		"tr": "Iskalamadan ve 3 saniyeden uzun durmadan vur, kombo ve puan çarpanı artsın. Üst üste üç kez 3–4 taş kırmak hassas kombo, dört ve fazlası kusursuz kombo verir."},
	"pay_combo": {"ru": "Комбо: ×2 со 2-го удара, ×3 с 5-го, ×4 с 9-го", "en": "Combo: ×2 from strike 2, ×3 from 5, ×4 from 9", "tr": "Kombo: 2. vuruştan ×2, 5.'den ×3, 9.'dan ×4"},
	"pay_precise": {"ru": "Точное: +10 очков, +3 с · идеальное: +20, +5 с", "en": "Precise: +10 points, +3 s · perfect: +20, +5 s", "tr": "Hassas: +10 puan, +3 sn · kusursuz: +20, +5 sn"},
}

var lang := "ru"


func set_language(code: String) -> void:
	code = code.substr(0, 2).to_lower()
	# Yandex recommends Russian for CIS languages and English elsewhere.
	if code in ["be", "kk", "uk", "uz"]:
		code = "ru"
	lang = code if code in SUPPORTED else "en"
	language_changed.emit()


func t(key: String, args := {}) -> String:
	var row: Dictionary = S.get(key, {})
	var s: String = row.get(lang, row.get("en", key))
	return s.format(args) if not args.is_empty() else s
