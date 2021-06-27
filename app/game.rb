Maw!

controls.define :jump, keyboard: :space, controller_one: :a, mouse: :button_left
controls.define :left, keyboard: :a, controller_one: :left
controls.define :right, keyboard: :d, controller_one: :right
controls.define :reset, keyboard: :r, controller_one: :r1, mouse: :button_right
controls.define :quit, keyboard: :q, controller_one: :start

init {
  audio[:start_chime] = {
    input: 'sounds/GameStart.wav',
    pitch: 0.6 + rand() * 1.5
  }

  $state.platforms = [platform!(), platform!(y: 300)]
  $state.gravity     = -0.4
  $state.player.platforms_cleared = 0
  $state.player.x  = 0
  $state.player.y  = 100
  $state.player.w  = 16
  $state.player.h  = 64
  $state.player.dy = 9
  $state.player.dx = 35
  $state.player_jump_power           = 13
  $state.player_jump_power_duration  = 10
  $state.player_max_run_speed        = 15
  $state.player_speed_slowdown_rate  = 0.88
  $state.player_acceleration         = 1
  $state.camera = { y: -100 }
}

tick {
  if controls.reset_down?
    $gtk.reset(seed: rand(999999999))
    next
  end

  input
  calc

  solids << $state.background ||= [
    0, 0, grid.w, grid.h,
    rand(185), rand(175), rand(215), 155 + rand(100)
  ]

  solids << $state.platforms.map do |p|
    [p.x + 300, p.y - $state.camera[:y], p.w, p.h]
  end

  solids << [
    $state.player.x + 300,
    $state.player.y - $state.camera[:y],
    $state.player.w,
    $state.player.h,
    $state.player.color ||= [rand(255), rand(255), rand(255)]
  ]
}

def platform! opts={}
  {x: 0, y: 0, w: 700, h: 16, dx: 1, speed: 0, rect: nil}.merge! opts
end

def input
  exit if controls.quit?

  player = $state.player

  if controls.jump?
    if (player.jumped_at ||= tick_count) == tick_count
      play_jump_sound
      player.w += 2
      player.x -= 1
    end

    if player.jumped_at.elapsed_time < $state.player_jump_power_duration && !player.falling
      player.dy = $state.player_jump_power
    end
  end

  if controls.jump_up?
    player.falling = true
  end

  if player.falling
    stop_jump_sound
  end

  if controls.left?
    player.dx -= $state.player_acceleration
    player.dx = player.dx.greater(-$state.player_max_run_speed)
  elsif controls.right?
    player.dx += $state.player_acceleration
    player.dx  = player.dx.lesser($state.player_max_run_speed)
  else
    player.dx *= $state.player_speed_slowdown_rate
  end
end

def calc
  camera = $state.camera
  platforms = $state.platforms
  player = $state.player
  gravity = $state.gravity

  platforms.each do |p|
    p.rect = [p.x, p.y, p.w, p.h]
  end

  player.point = [player.x + player.w.half, player.y]

  collision = platforms.find { |p| player.point.inside_rect? p.rect }

  if collision && player.dy <= 0
    player.dy = 0 if player.dy < 0
    player.y = collision.rect.y + collision.rect.h - 2
    if !player.platform
      player.dx = 0
    end
    player.x += collision.dx * collision.speed
    player.platform = collision
    if player.falling
      player.dx = 0
    end
    player.falling = false
    player.jumped_at = nil
  else
    player.platform = nil
    player.y  += player.dy
    player.dy += gravity
  end

  platforms.each do |p|
    p.x += p.dx * p.speed
    if p.x < -300
      p.dx *= -1
      p.x = -300
    elsif p.x > (1000 - p.w)
      p.dx *= -1
      p.x = (1000 - p.w)
    end
  end

  delta = (player.y - camera[:y] - 100)

  if delta > -200
    camera[:y] += delta * 0.01
    player.x  += player.dx
    has_platforms = platforms.find { |p| p.y > (player.y + 300) }

    if !has_platforms
      width = 700 - player.platforms_cleared * 50
      player.platforms_cleared += 1
      last_platform = platforms[-1]

      platforms << platform!(
        x: (700 - width) * rand,
        y: last_platform.y + 300,
        w: width,
        dx: 1.randomize(:sign),
        speed: 1.5 * player.platforms_cleared)
    end
  else
    $state.clear!
  end
end

def play_jump_sound
  audio[:jump] = {
    input: 'sounds/jump.wav',
    pitch: 0.4 + $state.player.platforms_cleared.to_f / 7,
    speed: 2
  }
end

def stop_jump_sound
  audio[:jump] = nil
end
