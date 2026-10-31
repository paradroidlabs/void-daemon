class_name CombatGeometry
extends RefCounted

static func clear(a: Vector2, b: Vector2, walls: Array[Rect2], radius: float = 0) -> bool:
	for wall in walls:
		var rect := wall.grow(radius)
		if rect.has_point(a) or rect.has_point(b):
			return false
		var corners := [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null:
				return false
	return true

static func resolve(point: Vector2, radius: float, walls: Array[Rect2]) -> Vector2:
	var result := point
	for wall in walls:
		var rect := wall.grow(radius)
		if not rect.has_point(result):
			continue
		var distances := [result.x-rect.position.x, rect.end.x-result.x, result.y-rect.position.y, rect.end.y-result.y]
		match distances.find(distances.min()):
			0: result.x = rect.position.x-0.01
			1: result.x = rect.end.x+0.01
			2: result.y = rect.position.y-0.01
			3: result.y = rect.end.y+0.01
	return result

static func clip(a: Vector2, b: Vector2, walls: Array[Rect2]) -> Vector2:
	var result := b
	for rect in walls:
		if rect.has_point(a): return a
		var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		for i in range(4):
			var hit = Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])
			if hit != null and a.distance_squared_to(hit) < a.distance_squared_to(result): result=hit
	return result

static func waypoint(a: Vector2, b: Vector2, walls: Array[Rect2], doors: Array[Vector2]) -> Vector2:
	if clear(a,b,walls,24): return b
	var points: Array[Vector2] = [a,b]
	points.append_array(doors)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i in points.size():
		costs.append(INF)
		previous.append(-1)
		visited.append(false)
	costs[0]=0
	for iteration in points.size():
		var best := -1
		for i in points.size():
			if not visited[i] and (best < 0 or costs[i] < costs[best]): best=i
		if best < 0 or is_inf(costs[best]): break
		if best==1: break
		visited[best]=true
		for i in points.size():
			if visited[i] or not clear(points[best],points[i],walls,24): continue
			var cost := costs[best]+points[best].distance_to(points[i])
			if cost < costs[i]:
				costs[i]=cost
				previous[i]=best
	var index := 1
	if previous[index] < 0: return a
	while previous[index] > 0: index=previous[index]
	return points[index]
