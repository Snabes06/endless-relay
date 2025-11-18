extends CanvasLayer

@onready var stamina_bar = $StaminaBar
@onready var momentum_bar = $MomentumBar
@onready var stamina_label = $StaminaLabel
@onready var momentum_label = $MomentumLabel
@onready var perfect_label = $PerfectLabel
@onready var obstacle_label = $ObstacleLabel

func _ready():
    perfect_label.visible = false
    obstacle_label.visible = false

func update_hud(stamina: float, _pace: float, momentum: float, burst_ready: bool):
    stamina_bar.value = stamina
    stamina_label.text = str(int(stamina))
    momentum_bar.value = momentum
    momentum_label.text = str(int(momentum))
    $BurstLabel.visible = burst_ready

func show_perfect():
    perfect_label.visible = true
    $PerfectTimer.start()

func _on_PerfectTimer_timeout():
    perfect_label.visible = false

func show_obstacle():
    obstacle_label.visible = true
    $ObstacleTimer.start()

func _on_ObstacleTimer_timeout():
    obstacle_label.visible = false
