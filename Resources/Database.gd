extends Node

const default_last_map_path: String = "./Maps/TK010000.cmp"

var db: SQLite
const db_path := "res://config.db"
var db_is_new := true

func _ready() -> void:
	db = SQLite.new()
	var db_is_new := not FileAccess.file_exists(db_path)
	db.path = db_path
	db.open_db()
	
	# Check Database Tables (Initialize if any tables are missing)
	if not table_exists("config"):
		db.create_table("config", {
			"id": {
				"data_type":"integer",
				"primary_key":"true",
				"auto_increment":"true"
			},
			"config_key":	{"data_type":"text"},
			"config_value": {"data_type":"text"},
		})
		upsert_config_item("last_map_path", default_last_map_path)

func table_exists(table_name: String) -> bool:
	db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='" + table_name + "';")
	return len(db.query_result) > 0

func get_config_item_value(config_key: String) -> String:
	return get_config_item(config_key)[0]['config_value']

func get_config_item(config_key: String) -> Array[Dictionary]:
	db.select_rows("config", "config_key == '%s'" % config_key, ["*"])
	return db.query_result

func config_key_exists(config_key: String) -> bool:
	return len(get_config_item(config_key)) > 0

func upsert_config_item(
		config_key: String,
		config_value: String) -> bool:
	if config_key_exists(config_key):
		return db.update_rows("config", "config_key == '%s'" % config_key, {"config_value": config_value})
	else:
		return db.insert_row("config", {
			"config_key": config_key,
			"config_value": config_value,
		})
