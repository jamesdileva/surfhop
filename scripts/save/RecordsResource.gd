class_name RecordsResource
extends Resource

## PB storage container persisted to user://save/records.tres (architecture
## §14.3). Keys are map names; values are MapRecord sub-resources.

@export var records: Dictionary = {}  # map_name -> MapRecord


func get_record(map_name: String) -> MapRecord:
	return records.get(map_name)


func get_or_create_record(map_name: String) -> MapRecord:
	var record: MapRecord = records.get(map_name)
	if record == null:
		record = MapRecord.new()
		record.map_name = map_name
		records[map_name] = record
	return record
