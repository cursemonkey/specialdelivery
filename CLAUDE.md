# Cozy Delivery Co. — Claude Code Guidelines

## GDScript Type Annotations

Always use explicit long-form type annotations instead of `:=` inference when the right-hand side is:
- A method call on a variable typed as a base class (`Node`, `Object`, etc.)
- `Array.filter()`, `Array.slice()`, `Array.duplicate()`
- `get_tree().get_nodes_in_group()`
- Any function returning an untyped or base-class value

**Correct:**
```gdscript
var nav_poly : NavigationPolygon = pad.navigation_polygon
var packages : Array[int]        = mgr.get_packages()
var targets  : Array             = player.delivery_targets
```

**Avoid:**
```gdscript
var nav_poly := pad.navigation_polygon   # fails if pad is typed as Object/Node
var packages := mgr.get_packages()       # fails if mgr is typed as Node
```
