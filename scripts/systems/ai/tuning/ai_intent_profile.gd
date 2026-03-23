class_name AIIntentProfile
extends Resource


@export var intent_name: String = "intent"
@export var activation_phase: AIActionProfile
@export var target_phase: AIActionProfile
@export var destination_phase: AIActionProfile
@export var module_phase: AIActionProfile
@export var intent_bias: float = 1.0
