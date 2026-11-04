#!/usr/bin/env python3
"""Build the Kingdom Arena asset and data layer from the Tiny RPG pack.

The runtime game is node/scene/resource based. This tool only prepares the
checked-in copies of the source art, portraits, SpriteFrames resources and
UnitDefinition resources. It is deterministic and can be re-run safely.

Usage: python3 tools/build_assets.py
"""

from __future__ import annotations

import math
import os
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = Path(os.environ.get(
    "TINY_RPG_PACK",
    str(Path.home() / "Downloads" / "Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters"),
))
CHAR_SRC = PACK / "Characters(100x100 split)"
_font_env = os.environ.get("FUSION_PIXEL_FONT_DIR", "")
REF_FONT = Path(_font_env) if _font_env else None

ASSETS = ROOT / "assets"
CHAR_OUT = ASSETS / "characters"
PORTRAIT_OUT = ASSETS / "portraits"
RES_UNITS = ROOT / "resources" / "units"
RES_VISUALS = ROOT / "resources" / "visuals"
RES_ACTIONS = ROOT / "resources" / "actions"
VISUAL_SCENES = ROOT / "scenes" / "units"
RES_BEHAVIORS = ROOT / "resources" / "behaviors"


@dataclass
class Unit:
    slug: str
    name: str
    title: str
    faction: int  # 0 kingdom, 1 legion
    role: str
    order: int
    description: str
    max_hp: float
    attack_damage: float
    attack_speed: float
    attack_range: float
    move_speed: float
    armor: float
    attack_windup: float
    attack_kind: int  # 0 melee, 1 ranged
    projectile_kind: int  # 0 none, 1 arrow, 2 magic
    visual_scale: float
    body_radius: float
    source: str = ""
    foot_offset: float = 7.0
    animations: dict[str, str] = field(default_factory=dict)


ROLE_COLORS = {
    "坦克": "#7db2ff",
    "战士": "#f0b36b",
    "突袭": "#ff8fa3",
    "射手": "#8fe3a8",
    "法师": "#c39cff",
    "辅助": "#ffe28a",
}

UNITS = [
    Unit("soldier", "士兵", "王庭新兵", 0, "战士", 0,
         "攻守均衡的近战新兵，适合放在前排吸收第一波冲锋。",
         640, 56, 1.00, 76, 125, 0.05, 0.30, 0, 0, 4.0, 30, source="Soldier"),
    Unit("archer", "弓箭手", "林间猎手", 0, "射手", 1,
         "超远射程的物理射手，脆弱但持续输出稳定。",
         400, 50, 1.05, 340, 118, 0.02, 0.38, 1, 1, 4.0, 28, source="Archer"),
    Unit("knight", "骑士", "铁壁骑士", 0, "坦克", 2,
         "披甲的王国骑士，护甲与生命都很扎实。",
         940, 64, 1.15, 80, 105, 0.18, 0.32, 0, 0, 4.1, 32, source="Knight"),
    Unit("knight_templar", "圣殿骑士", "圣殿守护者", 0, "坦克", 3,
         "圣殿的精锐守护者，全场最可靠的前排之一。",
         1020, 72, 1.10, 84, 100, 0.22, 0.34, 0, 0, 4.2, 33, source="Knight Templar"),
    Unit("armored_axeman", "重甲斧兵", "断岳斧手", 0, "战士", 4,
         "挥动巨斧的重装战士，单次伤害极高。",
         800, 82, 1.35, 86, 95, 0.12, 0.40, 0, 0, 4.2, 33, source="Armored Axeman"),
    Unit("lancer", "枪兵", "长枪卫兵", 0, "战士", 5,
         "长枪的攻击距离更远，能在敌人近身前先手命中。",
         660, 68, 1.20, 112, 118, 0.08, 0.30, 0, 0, 4.1, 30, source="Lancer"),
    Unit("swordsman", "剑士", "疾风剑士", 0, "突袭", 6,
         "高速近战刺客，攻速极快但生命偏低。",
         580, 72, 0.90, 72, 142, 0.04, 0.24, 0, 0, 4.0, 28, source="Swordsman"),
    Unit("priest", "牧师", "圣光牧师", 0, "辅助", 7,
         "以圣光攻击的远程支援者，MVP 中只使用普攻。",
         480, 44, 1.25, 310, 110, 0.03, 0.42, 1, 2, 4.0, 28, source="Priest"),
    Unit("wizard", "法师", "秘法法师", 0, "法师", 8,
         "秘法飞弹威力惊人，需要队友保护。",
         380, 96, 1.55, 360, 105, 0.00, 0.50, 1, 2, 4.0, 28, source="Wizard"),
    Unit("orc", "兽人", "荒原兽人", 1, "战士", 9,
         "来自荒原的兽人战士，皮糙肉厚且好战。",
         720, 70, 1.10, 78, 122, 0.06, 0.30, 0, 0, 4.0, 30, source="Orc"),
    Unit("elite_orc", "精锐兽人", "血牙精锐", 1, "战士", 10,
         "血牙氏族的精锐，攻守都强于普通兽人。",
         880, 86, 1.30, 86, 112, 0.12, 0.36, 0, 0, 4.1, 32, source="Elite Orc"),
    Unit("armored_orc", "重甲兽人", "铁颚重甲", 1, "坦克", 11,
         "铁颚重甲兽人，移动缓慢但极难击倒。",
         1060, 72, 1.50, 84, 92, 0.22, 0.42, 0, 0, 4.2, 34, source="Armored Orc"),
    Unit("orc_rider", "兽人骑兵", "裂地骑兵", 1, "突袭", 12,
         "高速冲锋的兽人骑兵，善于切入后排。",
         780, 84, 1.20, 104, 158, 0.08, 0.30, 0, 0, 4.4, 36, source="Orc rider"),
    Unit("skeleton", "骷髅", "枯骨兵", 1, "战士", 13,
         "骨架松散却不知疼痛，最廉价的战线填充者。",
         420, 48, 1.00, 74, 122, 0.03, 0.28, 0, 0, 3.9, 28, source="Skeleton"),
    Unit("armored_skeleton", "重甲骷髅", "墓卫骷髅", 1, "坦克", 14,
         "墓园守卫，旧甲提供了可观的防护。",
         680, 60, 1.30, 80, 108, 0.18, 0.34, 0, 0, 4.0, 30, source="Armored Skeleton"),
    Unit("greatsword_skeleton", "巨剑骷髅", "断魂巨剑", 1, "战士", 15,
         "拖着巨剑的骸骨，一次挥砍就能重创脆皮。",
         760, 92, 1.50, 96, 96, 0.10, 0.42, 0, 0, 4.2, 33, source="Greatsword Skeleton"),
    Unit("skeleton_archer", "骷髅弓手", "骸骨射手", 1, "射手", 16,
         "从墓穴中爬出的弓手，远程压制力不俗。",
         350, 48, 1.10, 330, 118, 0.02, 0.36, 1, 1, 3.9, 28, source="Skeleton Archer"),
    Unit("necromancer", "死灵法师", "墓穴低语者", 1, "法师", 17,
         "操纵暗影法术的施法者，普攻为暗影弹。",
         440, 90, 1.60, 350, 102, 0.02, 0.48, 1, 2, 4.0, 28, source="Necromancer"),
    Unit("bat", "蝙蝠", "夜翼蝠", 1, "突袭", 18,
         "飞行的夜翼蝠，移速极快，能绕开前排。",
         300, 36, 0.70, 60, 195, 0.00, 0.20, 0, 0, 3.2, 22, source="Bat"),
    Unit("slime", "史莱姆", "沼泽史莱姆", 1, "战士", 19,
         "黏稠的沼泽生物，缓慢但难以彻底打散。",
         540, 42, 1.25, 66, 88, 0.08, 0.34, 0, 0, 3.3, 25, source="Slime"),
    Unit("werebear", "熊人", "裂林熊人", 1, "坦克", 20,
         "巨熊般的体魄，全场最高生命与重击。",
         1150, 98, 1.60, 94, 102, 0.18, 0.46, 0, 0, 4.6, 40, source="Werebear"),
    Unit("werewolf", "狼人", "血月狼人", 1, "突袭", 21,
         "月下狂奔的狼人，速度极快，专猎后排。",
         680, 80, 0.95, 76, 168, 0.05, 0.26, 0, 0, 4.1, 30, source="Werewolf"),
]

# Animation source mapping. Values are source file stems inside the character folder.
SPECIAL_SOURCES = {
    "Bat": {"idle": "Bat_Flying", "move": "Bat_Flying"},
    "Knight Templar": {"move": "Knight Templar_Walk01"},
    "Lancer": {"move": "Lancer_Walk01"},
    "Necromancer": {"death": "Necromancer_DEATH"},
    "Skeleton Archer": {"attack_01": "Skeleton Archer_Attack"},
    "Priest": {"attack_01": "Priest_Attack"},
}

ANIM_ORDER = ["idle", "move", "attack_01", "attack_02", "attack_03",
              "hurt", "death", "block", "summon", "heal", "move_02", "fly"]
ANIM_LOOP = {"idle": True, "move": True, "move_02": True, "fly": True}
ANIM_SPEED = {
    "idle": 8.0, "move": 10.0, "move_02": 10.0, "fly": 10.0,
    "attack_01": 16.0, "attack_02": 16.0, "attack_03": 16.0,
    "hurt": 12.0, "death": 10.0, "block": 8.0, "summon": 12.0, "heal": 10.0,
}
SKIP_PATTERNS = ("with_magic_effects", "_effect", "sumon_effect", "summon_effect")


def snake_anim(stem: str, char_name: str) -> str:
    base = stem
    prefix = char_name + "_"
    if base.startswith(prefix):
        base = base[len(prefix):]
    base = base.lower().replace(" ", "_").replace("(", "").replace(")", "")
    base = base.replace("-", "_")
    return base


def canonical_anim(raw: str) -> str:
    if raw in ("attack", "attack01"):
        return "attack_01"
    if raw == "attack02":
        return "attack_02"
    if raw in ("attack3", "attack03"):
        return "attack_03"
    if raw == "walk" or raw == "walk01":
        return "move"
    if raw == "walk02":
        return "move_02"
    return raw


def godot_color(hex_str: str) -> str:
    value = hex_str.lstrip("#")
    r = int(value[0:2], 16) / 255.0
    g = int(value[2:4], 16) / 255.0
    b = int(value[4:6], 16) / 255.0
    return f"Color({r:.3f}, {g:.3f}, {b:.3f}, 1)"


def _write_effect_resource(effect_id: str, effect: dict) -> str:
    """Build one ActionEffectDefinition as an embedded subresource."""
    lines = [
        f'[sub_resource type="Resource" id="{effect_id}"]',
        'script = ExtResource("2")',
        f'kind = {effect["kind"]}',
        f'shape = {effect["shape"]}',
        f'trigger_frame = {effect["trigger_frame"]}',
        f'damage_ratio = {effect["damage_ratio"]:.2f}',
        f'radius = {effect["radius"]:.1f}',
        f'half_angle = {effect["half_angle"]:.1f}',
        f'length = {effect.get("length", 0.0):.1f}',
        f'width = {effect.get("width", 0.0):.1f}',
        f'center_on_self = {"true" if effect.get("center_on_self", False) else "false"}',
        f'status_kind = {effect.get("status_kind", 0)}',
        f'status_duration = {effect.get("status_duration", 0.0):.2f}',
        f'status_power = {effect.get("status_power", 0.0):.2f}',
        f'heal_amount = {effect.get("heal_amount", 0.0):.1f}',
        f'heal_ratio = {effect.get("heal_ratio", 0.0):.2f}',
        f'summon_unit_id = &"{effect.get("summon_unit_id", "")}"',
        f'summon_count = {effect.get("summon_count", 1)}',
        f'knockback = {effect.get("knockback", 0.0):.1f}',
        f'projectile_kind = {effect["projectile_kind"]}',
        f'duration = {effect.get("duration", 0.0):.2f}',
    ]
    if effect.get("scene_id"):
        lines.append(f'effect_scene = ExtResource("{effect["scene_id"]}")')
    return "\n".join(lines)


def _write_action(
    path: Path,
    action_id: str,
    display_name: str,
    category: int,
    target_mode: int,
    animation: str,
    action_range: float,
    cooldown: float,
    priority: int,
    effect: dict | list[dict],
    mana_cost: float = 0.0,
    action_duration: float = 0.0,
    min_self_hp_ratio: float = 0.0,
    max_self_hp_ratio: float = 1.0,
    advance_speed: float = 0.0,
    min_targets: int = 1,
    requires_wounded_ally: bool = False,
) -> None:
    effects = effect if isinstance(effect, list) else [effect]
    lines = [
        '[gd_resource type="Resource" script_class="CombatActionDefinition" format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/data/combat_action_definition.gd" id="1"]',
        '[ext_resource type="Script" path="res://scripts/data/action_effect_definition.gd" id="2"]',
    ]
    scene_paths: list[str] = []
    for effect_data in effects:
        scene_path = effect_data.get("scene_path")
        if scene_path and scene_path not in scene_paths:
            scene_paths.append(scene_path)
    for index, scene_path in enumerate(scene_paths):
        scene_id = str(3 + index)
        lines.append(f'[ext_resource type="PackedScene" path="{scene_path}" id="{scene_id}"]')
        for effect_data in effects:
            if effect_data.get("scene_path") == scene_path:
                effect_data["scene_id"] = scene_id
    lines.append('')
    effect_refs = []
    for index, effect_data in enumerate(effects):
        effect_id = f"effect_{index}"
        effect_refs.append(f'SubResource("{effect_id}")')
        lines.append(_write_effect_resource(effect_id, effect_data))
        lines.append('')
    lines += [
        '[resource]',
        'script = ExtResource("1")',
        f'action_id = &"{action_id}"',
        f'display_name = "{display_name}"',
        f'category = {category}',
        f'target_mode = {target_mode}',
        f'animation = &"{animation}"',
        'animation_speed = 1.0',
        f'action_range = {action_range:.1f}',
        'min_range = 0.0',
        f'cooldown = {cooldown:.2f}',
        f'mana_cost = {mana_cost:.1f}',
        f'action_duration = {action_duration:.2f}',
        f'min_self_hp_ratio = {min_self_hp_ratio:.2f}',
        f'max_self_hp_ratio = {max_self_hp_ratio:.2f}',
        f'advance_speed = {advance_speed:.1f}',
        f'min_targets = {min_targets}',
        f'requires_wounded_ally = {"true" if requires_wounded_ally else "false"}',
        f'priority = {priority}',
        f'effects = [{", ".join(effect_refs)}]',
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _fx(kind=0, shape=0, frame=4, ratio=0.0, radius=0.0, half=0.0,
        length=0.0, width=0.0, projectile=0, duration=0.0, center_self=False,
        status_kind=0, status_duration=0.0, status_power=0.0,
        heal_amount=0.0, heal_ratio=0.0, summon_id="", summon_count=1, knockback=0.0) -> dict:
    return {
        "kind": kind, "shape": shape, "trigger_frame": frame,
        "damage_ratio": ratio, "radius": radius, "half_angle": half,
        "length": length, "width": width, "projectile_kind": projectile,
        "duration": duration, "center_on_self": center_self,
        "status_kind": status_kind, "status_duration": status_duration,
        "status_power": status_power, "heal_amount": heal_amount,
        "heal_ratio": heal_ratio, "summon_unit_id": summon_id,
        "summon_count": summon_count, "knockback": knockback,
    }


def _skill(action_id: str, name: str, animation: str, effects: list[dict],
           cooldown: float, priority: int, action_range: float,
           attack_range: float, mana: float = 0.0, target_mode: int = 0,
           category: int = 1, action_duration: float = 0.0,
           advance: float = 0.0, min_targets: int = 1,
           requires_wounded_ally: bool = False, max_hp: float = 1.0) -> dict:
    return {
        "id": action_id, "name": name, "animation": animation,
        "effects": effects, "cooldown": cooldown, "priority": priority,
        "range": action_range, "attack_range": attack_range, "mana": mana,
        "target_mode": target_mode, "category": category,
        "action_duration": action_duration, "advance": advance,
        "min_targets": min_targets, "requires_wounded_ally": requires_wounded_ally,
        "max_hp": max_hp,
    }


def _guard_action(prefix: str, name: str, cooldown: float = 12.0) -> dict:
    return _skill(prefix, name, "block", [_fx(kind=8, shape=3, frame=0, duration=1.0)],
                  cooldown, 6, 0.0, 0.0, category=2, target_mode=2,
                  action_duration=1.0, max_hp=0.55)


def _skills_for(unit: Unit) -> list[dict]:
    """The complete action kit for one hero, authored against the actual animation."""
    slug = unit.slug
    rng = unit.attack_range
    skills: list[dict] = []

    if slug == "soldier":
        skills.append(_skill("soldier_cleave", "横斩", "attack_02",
                             [_fx(shape=2, ratio=1.25, frame=4, radius=rng + 10.0, half=60.0)],
                             6.0, 7, rng, rng))
        skills.append(_skill("soldier_thrust", "破阵突刺", "attack_03",
                             [_fx(shape=4, ratio=2.0, frame=6, length=170.0, width=44.0)],
                             14.0, 10, 180.0, rng, mana=100.0))
    elif slug == "archer":
        skills.append(_skill("archer_piercing_shot", "贯云箭", "attack_02",
                             [_fx(shape=4, ratio=2.1, frame=9, length=360.0, width=40.0)],
                             14.0, 10, 380.0, rng, mana=100.0))
    elif slug == "knight":
        skills.append(_skill("knight_cleave", "回旋斩", "attack_02",
                             [_fx(shape=2, ratio=1.3, frame=4, radius=rng + 10.0, half=62.0)],
                             7.0, 7, rng, rng))
        skills.append(_skill("knight_flame_slash", "火焰斩击", "attack_03",
                             [_fx(shape=2, ratio=1.4, frame=7, radius=170.0, half=65.0)],
                             14.0, 10, 170.0, rng, mana=100.0))
        skills.append(_guard_action("knight_block", "格挡"))
    elif slug == "knight_templar":
        skills.append(_skill("knight_templar_cleave", "圣光斩", "attack_02",
                             [_fx(shape=2, ratio=1.3, frame=4, radius=rng + 10.0, half=62.0)],
                             7.0, 7, rng, rng))
        skills.append(_skill("knight_templar_judgement", "圣光裁决", "attack_03",
                             [_fx(shape=2, ratio=2.0, frame=6, radius=190.0, half=55.0)],
                             15.0, 10, 200.0, rng, mana=100.0))
        skills.append(_guard_action("knight_templar_block", "格挡"))
    elif slug == "armored_axeman":
        skills.append(_skill("armored_axeman_heavy", "重击", "attack_03",
                             [_fx(shape=0, ratio=2.0, frame=8)],
                             6.0, 8, rng, rng))
        spin = [_fx(shape=4, ratio=0.50, frame=frame, length=190.0, width=120.0)
                for frame in [4, 5, 6, 7, 8]]
        skills.append(_skill("armored_axeman_spin", "旋风斩", "attack_02", spin,
                             12.0, 10, 190.0, rng, mana=100.0,
                             target_mode=4, advance=240.0, min_targets=1))
    elif slug == "lancer":
        skills.append(_skill("lancer_pierce", "贯穿突刺", "attack_02",
                             [_fx(shape=4, ratio=1.3, frame=4, length=170.0, width=42.0)],
                             6.0, 7, 180.0, rng))
        skills.append(_skill("lancer_flame_pierce", "烈焰贯穿", "attack_03",
                             [_fx(shape=4, ratio=2.2, frame=6, length=210.0, width=48.0)],
                             14.0, 10, 220.0, rng, mana=100.0))
    elif slug == "swordsman":
        skills.append(_skill("swordsman_triple", "疾风三连", "attack_02",
                             [_fx(shape=0, ratio=0.45, frame=frame) for frame in [4, 6, 8]],
                             7.0, 7, rng, rng))
        skills.append(_skill("swordsman_flurry", "追魂连刺", "attack_03",
                             [_fx(shape=0, ratio=0.40, frame=frame) for frame in [3, 5, 7, 9, 11]],
                             13.0, 10, rng, rng, mana=100.0))
    elif slug == "priest":
        skills.append(_skill("priest_sanctuary", "圣光普照", "heal",
                             [_fx(kind=3, shape=1, frame=2, radius=520.0,
                                  heal_amount=140.0, heal_ratio=1.0)],
                             15.0, 10, 0.0, 0.0, mana=100.0,

                             target_mode=2, requires_wounded_ally=True))
    elif slug == "wizard":
        skills.append(_skill("wizard_blast", "奥术冲击", "attack_02",
                             [_fx(shape=1, ratio=2.2, frame=6, radius=100.0)],
                             14.0, 10, 380.0, rng, mana=100.0))
    elif slug == "orc":
        skills.append(_skill("orc_rage_cleave", "狂暴斩", "attack_02",
                             [_fx(shape=2, ratio=1.9, frame=4, radius=rng + 10.0, half=65.0)],
                             12.0, 10, rng, rng, mana=100.0))
    elif slug == "elite_orc":
        skills.append(_skill("elite_orc_rend", "血牙斩", "attack_02",
                             [_fx(shape=2, ratio=1.3, frame=4, radius=rng + 10.0, half=60.0),
                              _fx(kind=5, shape=0, frame=4, status_kind=2,
                                  status_duration=3.0, status_power=8.0)],
                             6.0, 7, rng, rng))
        skills.append(_skill("elite_orc_bloodmoon", "血月狂斩", "attack_03",
                             [_fx(shape=2, ratio=2.2, frame=6, radius=185.0, half=60.0)],
                             14.0, 10, 195.0, rng, mana=100.0))
    elif slug == "armored_orc":
        skills.append(_skill("armored_orc_bash", "盾牌震击", "attack_02",
                             [_fx(shape=1, ratio=1.2, frame=5, radius=110.0, center_self=True),
                              _fx(kind=5, shape=1, frame=5, radius=110.0, center_self=True,
                                  status_kind=0, status_duration=0.9),
                              _fx(kind=6, shape=1, frame=5, radius=110.0, center_self=True,
                                  knockback=35.0)],
                             7.0, 7, 0.0, rng, target_mode=2))
        skills.append(_skill("armored_orc_quakeslam", "裂地", "attack_03",
                             [_fx(shape=1, ratio=1.8, frame=6, radius=150.0, center_self=True),
                              _fx(kind=5, shape=0, frame=6, status_kind=0,
                                  status_duration=1.0)],
                             16.0, 10, 0.0, rng, mana=100.0, target_mode=2))
        skills.append(_guard_action("armored_orc_block", "格挡"))
    elif slug == "orc_rider":
        skills.append(_skill("orc_rider_whirl", "回旋斩", "attack_02",
                             [_fx(shape=1, ratio=1.2, frame=4, radius=105.0, center_self=True)],
                             6.0, 7, 0.0, rng, target_mode=2))
        skills.append(_skill("orc_rider_cyclone", "裂阵回旋", "attack_03",
                             [_fx(shape=1, ratio=2.0, frame=6, radius=155.0, center_self=True)],
                             14.0, 10, 0.0, rng, mana=100.0, target_mode=2))
    elif slug == "skeleton":
        skills.append(_skill("skeleton_cleave", "骨刃斩", "attack_02",
                             [_fx(shape=2, ratio=1.3, frame=4, radius=rng + 8.0, half=60.0)],
                             5.0, 7, rng, rng))
        skills.append(_skill("skeleton_summon", "亡者召唤", "summon",
                             [_fx(kind=7, frame=2, summon_id="skeleton", summon_count=2)],
                             16.0, 9, 0.0, 0.0, mana=100.0, target_mode=2))
    elif slug == "armored_skeleton":
        skills.append(_skill("armored_skeleton_whirl", "墓甲回旋", "attack_02",
                             [_fx(shape=1, ratio=1.3, frame=4, radius=95.0, center_self=True)],
                             7.0, 7, 0.0, rng, target_mode=2))
        skills.append(_skill("armored_skeleton_summon", "墓卫召唤", "summon",
                             [_fx(kind=7, frame=2, summon_id="armored_skeleton", summon_count=1)],
                             18.0, 9, 0.0, 0.0, mana=100.0, target_mode=2))
    elif slug == "greatsword_skeleton":
        skills.append(_skill("greatsword_skeleton_cleave", "断魂斩", "attack_02",
                             [_fx(shape=2, ratio=1.4, frame=7, radius=rng + 14.0, half=62.0)],
                             8.0, 7, rng, rng))
        skills.append(_skill("greatsword_skeleton_pierce", "穿魂刺", "attack_03",
                             [_fx(shape=4, ratio=2.4, frame=6, length=210.0, width=46.0)],
                             15.0, 10, 220.0, rng, mana=100.0))
    elif slug == "skeleton_archer":
        skills.append(_skill("skeleton_archer_summon", "骸骨箭阵", "summon",
                             [_fx(kind=7, frame=2, summon_id="skeleton", summon_count=2)],
                             16.0, 9, 0.0, 0.0, mana=100.0, target_mode=2))
    elif slug == "necromancer":
        skills.append(_skill("necromancer_bolt", "暗影弹", "attack_02",
                             [_fx(shape=1, ratio=1.3, frame=6, radius=80.0),
                              _fx(kind=5, shape=0, frame=6, status_kind=1,
                                  status_duration=2.0, status_power=0.5)],
                             6.0, 7, 360.0, rng))
        skills.append(_skill("necromancer_summon", "亡者大军", "summon",
                             [_fx(kind=7, frame=2, summon_id="skeleton", summon_count=2)],
                             18.0, 9, 0.0, 0.0, mana=100.0, target_mode=2))
    elif slug == "bat":
        skills.append(_skill("bat_sonic", "音波冲击", "attack_02",
                             [_fx(shape=2, ratio=1.8, frame=4, radius=rng + 10.0, half=70.0)],
                             12.0, 10, rng, rng, mana=100.0))
    elif slug == "slime":
        skills.append(_skill("slime_acid", "酸液喷吐", "attack_02",
                             [_fx(shape=1, ratio=1.8, frame=8, radius=120.0),
                              _fx(kind=5, shape=0, frame=8, status_kind=1,
                                  status_duration=2.5, status_power=0.55)],
                             14.0, 10, 180.0, rng, mana=100.0))
    elif slug == "werebear":
        skills.append(_skill("werebear_claw", "裂林爪击", "attack_02",
                             [_fx(shape=2, ratio=1.4, frame=6, radius=rng + 12.0, half=62.0)],
                             7.0, 7, rng, rng))
        skills.append(_skill("werebear_quake", "裂地", "attack_03",
                             [_fx(shape=1, ratio=1.8, frame=6, radius=160.0, center_self=True),
                              _fx(kind=5, shape=0, frame=6, status_kind=0,
                                  status_duration=1.0)],
                             16.0, 10, 0.0, rng, mana=100.0, target_mode=2))
    elif slug == "werewolf":
        skills.append(_skill("werewolf_rend", "血月爪击", "attack_02",
                             [_fx(shape=2, ratio=1.8, frame=9, radius=rng + 12.0, half=65.0),
                              _fx(kind=5, shape=0, frame=9, status_kind=2,
                                  status_duration=3.0, status_power=10.0)],
                             12.0, 10, rng, rng, mana=100.0))
    return skills


def build_actions(unit: Unit, out_dir: Path) -> list[str]:
    RES_ACTIONS.mkdir(parents=True, exist_ok=True)
    attack_frames = Image.open(out_dir / unit.animations["attack_01"]).width // 100
    trigger_frame = max(1, min(attack_frames - 1, round(unit.attack_windup * ANIM_SPEED["attack_01"])))
    is_ranged = unit.attack_kind == 1
    basic_effect = _fx(kind=1 if is_ranged else 0, shape=0, frame=trigger_frame,
                       ratio=1.0, projectile=unit.projectile_kind if is_ranged else 0)
    basic_name = f"{unit.slug}_basic"
    _write_action(
        RES_ACTIONS / f"{basic_name}.tres", basic_name, "普通攻击", 0, 0,
        "attack_01", unit.attack_range, 1.0 / max(unit.attack_speed, 0.05),
        0, basic_effect,
    )
    actions = [f"res://resources/actions/{basic_name}.tres"]
    for spec in _skills_for(unit):
        path = RES_ACTIONS / f"{spec['id']}.tres"
        _write_action(
            path, spec["id"], spec["name"], spec["category"], spec["target_mode"],
            spec["animation"], spec["range"], spec["cooldown"], spec["priority"],
            spec["effects"], mana_cost=spec["mana"],
            action_duration=spec["action_duration"], max_self_hp_ratio=spec["max_hp"],
            advance_speed=spec["advance"], min_targets=spec["min_targets"],
            requires_wounded_ally=spec["requires_wounded_ally"],
        )
        actions.append(f"res://resources/actions/{spec['id']}.tres")
    return actions
def build_visual_scene(unit: Unit, foot_offset: float, character_height: float) -> str:
    """Create a standalone visual scene once; do not overwrite manual edits."""
    VISUAL_SCENES.mkdir(parents=True, exist_ok=True)
    path = VISUAL_SCENES / f"{unit.slug}_visual.tscn"
    res_path = f"res://scenes/units/{unit.slug}_visual.tscn"
    if path.exists():
        return res_path
    scale = unit.visual_scale * 1.12
    body_y = -foot_offset * scale
    bar_y = -character_height * scale - 15.0
    shadow_scale = unit.body_radius * 1.05 / 80.0
    hurt_radius = unit.body_radius * 1.05
    content = f'''[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/battle/team_ring.gd" id="1"]
[ext_resource type="Script" path="res://scripts/battle/selection_ring.gd" id="2"]
[ext_resource type="Script" path="res://scripts/battle/health_bar.gd" id="3"]
[ext_resource type="Texture2D" path="res://assets/ui/soft_shadow.png" id="4"]
[ext_resource type="SpriteFrames" path="res://resources/visuals/{unit.slug}_frames.tres" id="5"]

[sub_resource type="CircleShape2D" id="hurt_shape"]
radius = {hurt_radius:.1f}

[sub_resource type="CircleShape2D" id="attack_shape"]
radius = {unit.attack_range:.1f}

[node name="UnitVisual" type="Node2D"]

[node name="Shadow" type="Sprite2D" parent="."]
texture_filter = 1
z_index = -1
texture = ExtResource("4")
position = Vector2(0, -1)
scale = Vector2({shadow_scale:.3f}, {shadow_scale:.3f})

[node name="TeamRing" type="Node2D" parent="."]
script = ExtResource("1")

[node name="SelectionRing" type="Node2D" parent="."]
visible = false
script = ExtResource("2")

[node name="Body" type="AnimatedSprite2D" parent="."]
texture_filter = 1
centered = true
position = Vector2(0, {body_y:.1f})
scale = Vector2({scale:.3f}, {scale:.3f})
sprite_frames = ExtResource("5")

[node name="HealthBar" type="Node2D" parent="."]
z_index = 20
position = Vector2(0, {bar_y:.1f})
script = ExtResource("3")

[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 0
monitoring = false
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("hurt_shape")
debug_color = Color(1, 0.35, 0.35, 0.55)

[node name="AttackBox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 0
monitoring = false
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="AttackBox"]
shape = SubResource("attack_shape")
debug_color = Color(0.35, 0.7, 1, 0.45)

[node name="FootMarker" type="Marker2D" parent="."]

[node name="HitPoint" type="Marker2D" parent="."]
position = Vector2(0, {bar_y + 15.0:.1f})
'''
    path.write_text(content, encoding="utf-8")
    return res_path


def build_behavior(unit: Unit) -> str:
    """Create a per-hero behavior profile once; manual edits are preserved."""
    RES_BEHAVIORS.mkdir(parents=True, exist_ok=True)
    path = RES_BEHAVIORS / f"{unit.slug}.tres"
    res_path = f"res://resources/behaviors/{unit.slug}.tres"
    if path.exists():
        return res_path

    role = unit.role
    ranged = unit.attack_kind == 1
    if role == "坦克":
        target = dict(distance_weight=0.42, low_hp_weight=0.12, threat_weight=0.30,
                      backline_bonus=0.0, assassin_ranged_bonus=0.05, ranged_tank_penalty=0.0,
                      sticky_bonus=0.14, random_jitter=0.02)
        move = dict(preferred_range_ratio=1.0, lateral_span=60.0, forward_ratio=0.90,
                    flank_y_bias=0.0, kite_ratio=0.42, kite_stop_ratio=0.72)
    elif role == "突袭":
        target = dict(distance_weight=0.34, low_hp_weight=0.26, threat_weight=0.08,
                      backline_bonus=0.30, assassin_ranged_bonus=0.18, ranged_tank_penalty=0.0,
                      sticky_bonus=0.04, random_jitter=0.02)
        move = dict(preferred_range_ratio=0.94, lateral_span=70.0, forward_ratio=0.94,
                    flank_y_bias=18.0, kite_ratio=0.42, kite_stop_ratio=0.72)
    elif ranged:
        target = dict(distance_weight=0.40, low_hp_weight=0.30, threat_weight=0.15,
                      backline_bonus=0.10, assassin_ranged_bonus=0.18, ranged_tank_penalty=0.12,
                      sticky_bonus=0.08, random_jitter=0.02)
        move = dict(preferred_range_ratio=0.85, lateral_span=55.0, forward_ratio=0.92,
                    flank_y_bias=0.0, kite_ratio=0.42, kite_stop_ratio=0.72)
    else:
        target = dict(distance_weight=0.50, low_hp_weight=0.20, threat_weight=0.12,
                      backline_bonus=0.04, assassin_ranged_bonus=0.18, ranged_tank_penalty=0.08,
                      sticky_bonus=0.08, random_jitter=0.02)
        move = dict(preferred_range_ratio=0.97, lateral_span=50.0, forward_ratio=0.92,
                    flank_y_bias=0.0, kite_ratio=0.42, kite_stop_ratio=0.72)

    content = f'''[gd_resource type="Resource" script_class="UnitBehaviorProfile" format=3]

[ext_resource type="Script" path="res://scripts/ai/behavior/unit_behavior_profile.gd" id="1"]
[ext_resource type="Script" path="res://scripts/ai/behavior/weighted_targeting.gd" id="2"]
[ext_resource type="Script" path="res://scripts/ai/behavior/standard_movement.gd" id="3"]

[sub_resource type="Resource" id="targeting"]
script = ExtResource("2")
distance_weight = {target["distance_weight"]:.2f}
low_hp_weight = {target["low_hp_weight"]:.2f}
threat_weight = {target["threat_weight"]:.2f}
backline_bonus = {target["backline_bonus"]:.2f}
assassin_ranged_bonus = {target["assassin_ranged_bonus"]:.2f}
ranged_tank_penalty = {target["ranged_tank_penalty"]:.2f}
sticky_bonus = {target["sticky_bonus"]:.2f}
random_jitter = {target["random_jitter"]:.2f}

[sub_resource type="Resource" id="movement"]
script = ExtResource("3")
preferred_range_ratio = {move["preferred_range_ratio"]:.2f}
lateral_span = {move["lateral_span"]:.1f}
forward_ratio = {move["forward_ratio"]:.2f}
flank_y_bias = {move["flank_y_bias"]:.1f}
kite_ratio = {move["kite_ratio"]:.2f}
kite_stop_ratio = {move["kite_stop_ratio"]:.2f}

[resource]
script = ExtResource("1")
behavior_id = &"{unit.slug}_behavior"
display_name = "{unit.name}行为"
targeting = SubResource("targeting")
movement = SubResource("movement")
'''
    path.write_text(content, encoding="utf-8")
    return res_path


def build_character(unit: Unit) -> tuple[float, str]:
    src_dir = CHAR_SRC / unit.source / unit.source
    out_dir = CHAR_OUT / unit.slug
    out_dir.mkdir(parents=True, exist_ok=True)
    by_stem = {p.stem: p for p in sorted(src_dir.glob("*.png"))}
    specials = SPECIAL_SOURCES.get(unit.source, {})

    # Copy every per-animation strip into the project (the combined sheet is skipped).
    copied: dict[str, str] = {}
    for stem, path in by_stem.items():
        if stem == unit.source:  # combined multi-row reference sheet
            continue
        raw = snake_anim(stem, unit.source)
        if any(pat in raw for pat in SKIP_PATTERNS):
            continue
        dest_name = raw.replace("/", "_") + ".png"
        shutil.copy2(path, out_dir / dest_name)
        copied[raw] = dest_name

    # Build the canonical animation -> destination file map.
    animations: dict[str, str] = {}
    for raw, dest in copied.items():
        if raw in ("flying",):
            animations["fly"] = dest
            continue
        animations[canonical_anim(raw)] = dest

    # Units that have no dedicated idle / walk (Bat) reuse the flying strip.
    for key, stem in specials.items():
        raw = snake_anim(stem, unit.source)
        if raw in copied:
            animations[key] = copied[raw]
    if "idle" not in animations and "fly" in animations:
        animations["idle"] = animations["fly"]
    if "move" not in animations and "fly" in animations:
        animations["move"] = animations["fly"]
    if "move" not in animations and "move_02" in animations:
        animations["move"] = animations["move_02"]

    unit.animations = animations

    # Portrait: tight square crop from the first idle frame, nearest-neighbour upscale.
    idle_dest = animations.get("idle")
    if idle_dest is None:
        raise RuntimeError(f"{unit.slug}: no idle animation")
    idle_img = Image.open(out_dir / idle_dest).convert("RGBA")
    frames = [idle_img.crop((x, 0, x + 100, 100)) for x in range(0, idle_img.width, 100)]
    boxes = [frame.getbbox() for frame in frames if frame.getbbox()]
    if not boxes:
        raise RuntimeError(f"{unit.slug}: idle frames are empty")
    left = min(b[0] for b in boxes)
    top = min(b[1] for b in boxes)
    right = max(b[2] for b in boxes)
    bottom = max(b[3] for b in boxes)
    unit.foot_offset = float(max(bottom for b in boxes)) - 50.0
    character_height = float(bottom - top)
    pad = 5
    cx = (left + right) / 2.0
    cy = (top + bottom) / 2.0
    side = max(right - left, bottom - top) + pad * 2
    box = (int(round(cx - side / 2)), int(round(cy - side / 2)),
           int(round(cx + side / 2)), int(round(cy + side / 2)))
    portrait = idle_img.crop(box).resize((160, 160), Image.Resampling.NEAREST)
    PORTRAIT_OUT.mkdir(parents=True, exist_ok=True)
    portrait.save(PORTRAIT_OUT / f"{unit.slug}.png")

    # SpriteFrames resource.
    anim_names = [a for a in ANIM_ORDER if a in animations]
    for extra in sorted(animations):
        if extra not in anim_names:
            anim_names.append(extra)
    lines = [
        '[gd_resource type="SpriteFrames" format=3]',
        "",
    ]
    ext_ids = {}
    for index, anim in enumerate(anim_names):
        ext_ids[anim] = f"tex_{anim}"
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/{unit.slug}/{animations[anim]}" id="{ext_ids[anim]}"]')
    lines.append("")
    for anim in anim_names:
        image = Image.open(out_dir / animations[anim])
        count = image.width // 100
        for i in range(count):
            lines += [
                f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]',
                f'atlas = ExtResource("{ext_ids[anim]}")',
                f"region = Rect2({i * 100}, 0, 100, 100)",
                "",
            ]
    lines.append("[resource]")
    lines.append("animations = [{")
    for anim_i, anim in enumerate(anim_names):
        image = Image.open(out_dir / animations[anim])
        count = image.width // 100
        frames = ", ".join(
            '{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i)
            for i in range(count)
        )
        lines += [
            '"frames": [%s],' % frames,
            '"loop": %s,' % ("true" if ANIM_LOOP.get(anim, False) else "false"),
            '"name": &"%s",' % anim,
            '"speed": %.1f' % ANIM_SPEED.get(anim, 10.0),
            "}" + (", {" if anim_i < len(anim_names) - 1 else ""),
        ]
    lines.append("]")
    visual_path = RES_VISUALS / f"{unit.slug}_frames.tres"
    visual_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    # Actions + visual scene + UnitDefinition resource.
    action_paths = build_actions(unit, out_dir)
    visual_scene_path = build_visual_scene(unit, unit.foot_offset, character_height)
    behavior_path = build_behavior(unit)
    action_ext_lines = []
    action_refs = []
    for index, action_path in enumerate(action_paths):
        ext_id = str(4 + index)
        action_ext_lines.append(f'[ext_resource type="Resource" path="{action_path}" id="{ext_id}"]')
        action_refs.append(f'ExtResource("{ext_id}")')
    visual_id = str(4 + len(action_paths))
    behavior_id = str(5 + len(action_paths))
    visual_ext_line = f'[ext_resource type="PackedScene" path="{visual_scene_path}" id="{visual_id}"]'
    behavior_ext_line = f'[ext_resource type="Resource" path="{behavior_path}" id="{behavior_id}"]'
    accent = ROLE_COLORS[unit.role]
    load_steps = 6 + len(action_paths)
    content = f'''[gd_resource type="Resource" script_class="UnitDefinition" load_steps={load_steps} format=3]

[ext_resource type="Script" path="res://scripts/data/unit_definition.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://resources/visuals/{unit.slug}_frames.tres" id="2"]
[ext_resource type="Texture2D" path="res://assets/portraits/{unit.slug}.png" id="3"]
{chr(10).join(action_ext_lines)}
{visual_ext_line}
{behavior_ext_line}

[resource]
script = ExtResource("1")
unit_id = &"{unit.slug}"
display_name = "{unit.name}"
title = "{unit.title}"
faction = {unit.faction}
role = "{unit.role}"
roster_order = {unit.order}
description = "{unit.description}"
max_hp = {unit.max_hp:.1f}
attack_damage = {unit.attack_damage:.1f}
attack_speed = {unit.attack_speed:.2f}
attack_range = {unit.attack_range:.1f}
max_mana = 100.0
mana_regen = 8.0
move_speed = {unit.move_speed:.1f}
armor = {unit.armor:.2f}
attack_windup = {unit.attack_windup:.2f}
attack_kind = {unit.attack_kind}
projectile_kind = {unit.projectile_kind}
visual_scale = {unit.visual_scale * 1.12:.2f}
foot_offset = {unit.foot_offset:.1f}
character_height = {character_height:.1f}
body_radius = {unit.body_radius * 1.05:.1f}
accent_color = {godot_color(accent)}
actions = [{", ".join(action_refs)}]
behavior_profile = ExtResource("{behavior_id}")
visual_scene = ExtResource("{visual_id}")
sprite_frames = ExtResource("2")
portrait = ExtResource("3")
'''
    (RES_UNITS / f"{unit.slug}.tres").write_text(content, encoding="utf-8")
    return unit.foot_offset, visual_path.name


def build_projectiles() -> None:
    out = ASSETS / "projectiles"
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACK / "Arrow(Projectile)" / "Arrow01(32x32).png", out / "arrow.png")

    # A neutral white orb; the game tints it per caster with CanvasItem.modulate.
    size = 48
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pix = img.load()
    center = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - center, y - center) / center
            if d > 1.0:
                continue
            if d < 0.34:
                a = 255
                c = (255, 255, 255)
            elif d < 0.55:
                a = int(255 * (1.0 - (d - 0.34) / 0.21))
                c = (235, 245, 255)
            else:
                a = int(150 * (1.0 - (d - 0.55) / 0.45) ** 2)
                c = (190, 225, 255)
            pix[x, y] = (*c, a)
    img.save(out / "magic_orb.png")


def build_ui_assets() -> None:
    out = ASSETS / "ui"
    out.mkdir(parents=True, exist_ok=True)
    # Soft radial shadow.
    w, h = 192, 96
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pix = shadow.load()
    for y in range(h):
        for x in range(w):
            nx = (x - w / 2) / (w / 2)
            ny = (y - h / 2) / (h / 2)
            d = math.sqrt(nx * nx + ny * ny)
            if d < 1.0:
                a = int(110 * (1.0 - d) ** 2)
                pix[x, y] = (0, 0, 0, a)
    shadow.save(out / "soft_shadow.png")

    # 1x1 white pixel for particles / separators.
    Image.new("RGBA", (1, 1), (255, 255, 255, 255)).save(out / "pixel.png")

    # Ember/spark dot.
    dot = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    dpx = dot.load()
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5) / 7.5
            if d < 1.0:
                dpx[x, y] = (255, 255, 255, int(255 * (1.0 - d) ** 1.5))
    dot.save(out / "spark.png")


def build_fonts() -> None:
    if REF_FONT is None or not REF_FONT.exists():
        print("skip font copy (assets/fonts already contains the OFL font)")
        return
    dest = ASSETS / "fonts"
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(REF_FONT / "fusion-pixel-12px-zh_hans.woff2", dest / "fusion-pixel-12px-zh_hans.woff2")
    shutil.copy2(REF_FONT / "OFL-fusion-pixel.txt", dest / "OFL-fusion-pixel.txt")
    licenses = REF_FONT / "fusion-pixel-licenses"
    if licenses.exists():
        shutil.copytree(licenses, dest / "fusion-pixel-licenses", dirs_exist_ok=True)


def main() -> None:
    RES_UNITS.mkdir(parents=True, exist_ok=True)
    RES_VISUALS.mkdir(parents=True, exist_ok=True)
    RES_ACTIONS.mkdir(parents=True, exist_ok=True)
    for unit in UNITS:
        foot, _ = build_character(unit)
        print(f"built {unit.slug:18s} foot={foot:.0f} anims={len(unit.animations)}")
    build_projectiles()
    build_ui_assets()
    build_fonts()
    print(f"\n{len(UNITS)} units built into {ROOT}")


if __name__ == "__main__":
    main()
