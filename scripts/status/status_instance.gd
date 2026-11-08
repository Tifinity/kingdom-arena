class_name StatusInstance
extends RefCounted

## 一次状态施加的运行时数据。每个单位、每个来源可以拥有独立实例。

var definition: StatusDefinition
var target: Unit
var source: Unit

var remaining := 0.0
var stacks := 1
var power := 0.0
var tick_accum := 0.0
var vfx: Node2D
var instance_id := 0
