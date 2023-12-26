class_name Coin3D
extends Area3D


func _on_body_entered(_body: Node3D):
	$AnimationPlayer.play(&"pickup")
	$PickupAudio.play()
