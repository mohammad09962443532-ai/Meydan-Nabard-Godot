extends Node2D

const GRAVITY = 900.0
const MOVE_SPEED = 300.0
const JUMP_SPEED = -430.0
const BULLET_SPEED = 800.0
const WORLD_WIDTH = 4000.0

var player_pos = Vector2(250, 400)
var player_velocity = Vector2.ZERO
var fuel = 100.0
var health = 100
var facing = 1.0
var shooting_cooldown = 0.0
var bots = []
var bullets = []
var platforms = []
var score = 0
var message = "MEYDAN NABARD"

var left_pressed = false
var right_pressed = false
var jump_pressed = false
var jetpack_pressed = false
var fire_pressed = false

var touch_buttons = {}
var camera_x = 0.0
var screen_size = Vector2(1280, 720)

func _ready():
    screen_size = get_viewport_rect().size
    platforms = [
        Rect2(0, 610, 900, 110),
        Rect2(1050, 550, 650, 170),
        Rect2(1850, 610, 800, 110),
        Rect2(2800, 530, 1000, 190),
        Rect2(400, 440, 180, 24),
        Rect2(1200, 380, 220, 24),
        Rect2(2100, 420, 240, 24),
        Rect2(3100, 350, 220, 24)
    ]

    for i in range(8):
        bots.append({
            "pos": Vector2(650 + i * 420, 500),
            "hp": 3,
            "dir": -1.0 if i % 2 == 0 else 1.0,
            "cooldown": randf_range(0.5, 2.0)
        })

    queue_redraw()

func _process(delta):
    if health <= 0:
        if Input.is_action_just_pressed("ui_accept"):
            restart_game()
        queue_redraw()
        return

    var move_dir = 0.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or left_pressed:
        move_dir -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or right_pressed:
        move_dir += 1.0

    if move_dir != 0:
        facing = sign(move_dir)

    player_velocity.x = move_dir * MOVE_SPEED
    player_velocity.y += GRAVITY * delta

    var wants_jump = Input.is_key_pressed(KEY_SPACE) or jump_pressed
    var wants_jet = Input.is_key_pressed(KEY_SHIFT) or jetpack_pressed

    if wants_jump and is_on_ground():
        player_velocity.y = JUMP_SPEED

    if wants_jet and fuel > 0:
        player_velocity.y = min(player_velocity.y, -500.0)
        fuel = max(0.0, fuel - 35.0 * delta)
    else:
        fuel = min(100.0, fuel + 12.0 * delta)

    player_pos += player_velocity * delta
    player_pos.x = clamp(player_pos.x, 20.0, WORLD_WIDTH - 20.0)

    for platform in platforms:
        if player_velocity.y >= 0:
            var feet = player_pos.y + 26
            if player_pos.x + 16 > platform.position.x and player_pos.x - 16 < platform.end.x:
                if feet >= platform.position.y and feet - player_velocity.y * delta <= platform.position.y:
                    player_pos.y = platform.position.y - 26
                    player_velocity.y = 0

    if player_pos.y > 850:
        health = 0

    shooting_cooldown = max(0.0, shooting_cooldown - delta)
    if (fire_pressed or Input.is_key_pressed(KEY_F) or Input.is_key_pressed(KEY_CTRL)) and shooting_cooldown <= 0:
        shoot()
        shooting_cooldown = 0.22

    update_bullets(delta)
    update_bots(delta)

    camera_x = clamp(player_pos.x - screen_size.x * 0.4, 0.0, WORLD_WIDTH - screen_size.x)
    queue_redraw()

func is_on_ground() -> bool:
    if abs(player_velocity.y) > 5:
        return false

    var feet = player_pos.y + 26
    for platform in platforms:
        if player_pos.x + 15 > platform.position.x and player_pos.x - 15 < platform.end.x:
            if abs(feet - platform.position.y) < 4:
                return true
    return false

func shoot():
    bullets.append({
        "pos": player_pos + Vector2(facing * 24, -4),
        "vel": Vector2(facing * BULLET_SPEED, 0),
        "life": 1.5
    })

func update_bullets(delta):
    for i in range(bullets.size() - 1, -1, -1):
        var b = bullets[i]
        b["pos"] += b["vel"] * delta
        b["life"] -= delta
        var remove_bullet = b["life"] <= 0

        for j in range(bots.size() - 1, -1, -1):
            var bot = bots[j]
            if b["pos"].distance_to(bot["pos"]) < 28:
                bot["hp"] -= 1
                remove_bullet = true
                if bot["hp"] <= 0:
                    bots.remove_at(j)
                    score += 100
                break

        if remove_bullet:
            bullets.remove_at(i)

func update_bots(delta):
    for bot in bots:
        var distance = player_pos.x - bot["pos"].x
        if abs(distance) < 650:
            bot["dir"] = sign(distance)
            bot["pos"].x += bot["dir"] * 75.0 * delta
            bot["cooldown"] -= delta

            if bot["cooldown"] <= 0 and abs(player_pos.y - bot["pos"].y) < 120:
                bot["cooldown"] = 1.5
                if abs(distance) < 350:
                    health = max(0, health - 3)

        bot["pos"].x = clamp(bot["pos"].x, 30.0, WORLD_WIDTH - 30.0)

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            handle_touch(event.position, true)
        else:
            handle_touch(event.position, false)

    elif event is InputEventScreenDrag:
        handle_touch(event.position, true)

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            handle_touch(event.position, event.pressed)

func handle_touch(pos: Vector2, pressed: bool):
    var x = pos.x
    var y = pos.y

    if y < screen_size.y * 0.60:
        if pressed:
            fire_pressed = true
        else:
            fire_pressed = false
        return

    if x < screen_size.x * 0.34:
        left_pressed = pressed
        if pressed:
            right_pressed = false
    elif x < screen_size.x * 0.53:
        right_pressed = pressed
        if pressed:
            left_pressed = false
    elif x < screen_size.x * 0.72:
        jump_pressed = pressed
    elif x < screen_size.x * 0.88:
        jetpack_pressed = pressed
    else:
        fire_pressed = pressed

func restart_game():
    player_pos = Vector2(250, 400)
    player_velocity = Vector2.ZERO
    fuel = 100.0
    health = 100
    score = 0
    bullets.clear()
    bots.clear()

    for i in range(8):
        bots.append({
            "pos": Vector2(650 + i * 420, 500),
            "hp": 3,
            "dir": -1.0,
            "cooldown": 1.0
        })

func _draw():
    draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.08, 0.12, 0.20))

    for i in range(15):
        var sx = fposmod(i * 280.0 - camera_x * 0.3, screen_size.x)
        draw_circle(Vector2(sx, 100 + (i % 4) * 45), 30, Color(0.14, 0.19, 0.27))

    for platform in platforms:
        var r = Rect2(platform.position.x - camera_x, platform.position.y, platform.size.x, platform.size.y)
        draw_rect(r, Color(0.24, 0.29, 0.34))
        draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Color(0.28, 0.82, 0.42))

    for b in bullets:
        var p = b["pos"] - Vector2(camera_x, 0)
        draw_circle(p, 5, Color(1.0, 0.86, 0.24))
        draw_line(p, p - b["vel"].normalized() * 14, Color(1.0, 0.55, 0.15), 3)

    for bot in bots:
        var p = bot["pos"] - Vector2(camera_x, 0)
        draw_rect(Rect2(p - Vector2(15, 20), Vector2(30, 38)), Color(0.82, 0.20, 0.20))
        draw_circle(p + Vector2(0, -27), 12, Color(0.96, 0.69, 0.48))
        draw_rect(Rect2(p + Vector2(-18, -43), Vector2(36, 7)), Color(0.25, 0.13, 0.12))
        draw_rect(Rect2(p + Vector2(-17, -50), Vector2(34, 4)), Color(0.15, 0.85, 0.28))

    var pp = player_pos - Vector2(camera_x, 0)
    draw_rect(Rect2(pp - Vector2(15, 20), Vector2(30, 40)), Color(0.15, 0.55, 1.0))
    draw_circle(pp + Vector2(0, -27), 12, Color(0.95, 0.70, 0.52))
    draw_rect(Rect2(pp + Vector2(-17, -43), Vector2(34, 7)), Color(0.10, 0.28, 0.60))
    draw_line(pp + Vector2(facing * 10, -5), pp + Vector2(facing * 35, -5), Color(0.12, 0.12, 0.15), 7)

    if jetpack_pressed or Input.is_key_pressed(KEY_SHIFT):
        draw_colored_polygon(PackedVector2Array([
            pp + Vector2(-7, 18),
            pp + Vector2(0, 42 + randf() * 10),
            pp + Vector2(7, 18)
        ]), Color(1.0, 0.45, 0.08))

    draw_string(ThemeDB.fallback_font, Vector2(24, 34), "MEYDAN NABARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(24, 65), "HEALTH: " + str(health) + "   SCORE: " + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

    draw_rect(Rect2(24, 82, 180, 14), Color(0.2, 0.2, 0.2))
    draw_rect(Rect2(24, 82, 180 * fuel / 100.0, 14), Color(0.15, 0.75, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(215, 95), "JETPACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

    draw_string(ThemeDB.fallback_font, Vector2(24, screen_size.y - 20), "A/D: MOVE   SPACE: JUMP   SHIFT: JETPACK   F: FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

    draw_touch_button(Vector2(70, screen_size.y - 75), "◀")
    draw_touch_button(Vector2(175, screen_size.y - 75), "▶")
    draw_touch_button(Vector2(screen_size.x - 245, screen_size.y - 75), "JUMP")
    draw_touch_button(Vector2(screen_size.x - 145, screen_size.y - 75), "FLY")
    draw_touch_button(Vector2(screen_size.x - 55, screen_size.y - 75), "FIRE")

    if health <= 0:
        draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.75))
        draw_string(ThemeDB.fallback_font, Vector2(screen_size.x / 2 - 130, screen_size.y / 2), "GAME OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.RED)
        draw_string(ThemeDB.fallback_font, Vector2(screen_size.x / 2 - 170, screen_size.y / 2 + 50), "Press ENTER to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func draw_touch_button(center: Vector2, label: String):
    draw_circle(center, 38, Color(0.15, 0.25, 0.38, 0.85))
    draw_arc(center, 38, 0, TAU, 32, Color(0.3, 0.75, 1.0), 3)
    draw_string(ThemeDB.fallback_font, center + Vector2(-27, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 54, 15, Color.WHITE)
