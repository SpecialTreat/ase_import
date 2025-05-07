class_name Coin2D
extends Area2D


func _on_body_entered(_body: Node2D) -> void:
	$AnimationPlayer.play(&"pickup")
	$PickupAudio.play()
