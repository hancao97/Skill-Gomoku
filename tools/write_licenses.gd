extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/licenses")
	var file := FileAccess.open("res://assets/licenses/Godot.txt",FileAccess.WRITE)
	file.store_string(Engine.get_license_text()+"\n\nGODOT THIRD PARTY COPYRIGHTS\n\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(),"\t"))
	file.store_string("\n\nLICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	for key in licenses:
		file.store_string(str(key)+"\n"+str(licenses[key])+"\n\n")
	file.close()
	print("Godot engine and dependency notices written")
	quit()
