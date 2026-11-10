# Mod Panel 模组作者指南

Mod Panel（模组面板）是 Phantom Blade Zero 的 UE4SS 模组的游戏内设置面板。它读取与 Mods Menu（模组菜单）相同的两个文件：**如果你的模组已经在 Mods Menu 中显示设置，那么无需做任何改动，它也会在 Mod Panel 中显示这些设置。** Mod Panel 不需要 Mods Menu，玩家可以只装其中一个，也可以两个都装。为 Mods Menu 制作的 JavaScript 模组需要 Mods Menu 才能运行；在 Mods Menu 运行它们时，它们也会显示在 Mod Panel 中（[第 2 节](#javascript-模组)）。

本指南介绍 Mod Panel 1.0.1：它会列出哪些模组、它读取的文件的完整格式、它写入什么，以及你的模组如何立即采用更改。

[English](MOD-AUTHORS.md)

## 目录

1. [快速开始](#1-快速开始)
2. [哪些模组会被列出](#2-哪些模组会被列出)
3. [设置文件](#3-设置文件)
4. [说明文件](#4-说明文件)
5. [Mod Panel 如何写入你的设置](#5-mod-panel-如何写入你的设置)
6. [让更改立即生效的信号文件](#6-让更改立即生效的信号文件)
7. [模组有自己的面板或自行读取按键时](#7-模组有自己的面板或自行读取按键时)
8. [检查你的文件](#8-检查你的文件)
9. [许可协议](#9-许可协议)

## 1. 快速开始

你的模组文件夹，位于 `platform\steam\ue4ss\Mods\`：

```
MyMod\
    enabled.txt              UE4SS starts the mod
    Scripts\main.lua         your code
    MyMod.config.json        the settings, written by your mod at its first start
    MyMod.modsmenu.json      how each setting shows (optional, but strongly advised)
```

`MyMod.config.json`，一个单独的 JSON 对象：

```json
{
  "Enabled": true,
  "Strength": 1.5
}
```

`MyMod.modsmenu.json`：

```json
{
  "title": { "en": "My Mod", "zh-Hans": "我的模组" },
  "description": "What the mod does, in one or two sentences.",
  "version": "1.0.0",
  "settings": [
    { "key": "Enabled", "type": "toggle", "label": "Enabled", "default": true },
    { "key": "Strength", "type": "number", "label": "Strength", "default": 1.5, "min": 0, "max": 3, "step": 0.1,
      "help": "How strong the effect is. 1 is the game's." }
  ]
}
```

这样面板就能列出你的模组并修改它的设置。若想在游戏运行时立即采用更改、无需重启，请每秒读取一次信号文件（[第 6 节](#6-让更改立即生效的信号文件)）。

## 2. 哪些模组会被列出

一个模组必须同时满足以下所有条件才会被列出：

- UE4SS 会启动它：它的文件夹里有 `enabled.txt`，或者 `Mods\mods.txt` 里有一行 `MyMod : 1`。
- 它的文件夹名只使用字母、数字、`_`、`-`、`.`、空格和括号，最多 64 个字符，且不能只由点组成。
- 它的文件夹里有 `<FolderName>.config.json`，其中是一个 JSON 对象，最大 256 KiB。
- 它至少有一行可以使用（[第 4 节](#4-说明文件)）。

桥接文件夹 `PBZModsMenuBridge` 和 `shared` 文件夹永远不会被列出。Mod Panel 最多列出 256 个模组。

**顺序：** 先是 Mod Panel，然后按英文标题排列（不区分字母大小写），再按文件夹名排列。所有语言下的顺序都相同。

**开启与关闭：** 键为 `Enabled` 的 `toggle` 行就是你的模组的开关。默认情况下，列表只显示已开启的模组（勾选“模组已开启”（Mod enabled）的框，不勾选“模组已关闭”（Mod disabled）的框）；没有 `Enabled` 行的模组视为已开启。请给你的模组加一个 `Enabled` 行，并放在列表第一位，这样玩家就可以把它关闭，从而缩短列表。列表顶部的“所有模组”（All mods）一次即可关闭所有带有这一行的模组，之后只重新开启这些模组；没有这一行的模组会继续运行，`Enabled` 行为灰色的模组不受影响。这一更改与其他更改一样传达给你的模组（[第 6 节](#6-让更改立即生效的信号文件)）。

**文件何时被读取：** 说明文件在游戏启动时读取，之后每次打开面板时，如果其文本有变化就再读取一次；设置文件在每次打开面板时读取。你的模组或玩家对这些文件所做的更改，会在下次打开面板时显示出来。

### JavaScript 模组

为 Mods Menu 制作、通过 `PBZModsMenu.push` 把设置交给 Mods Menu 的 JavaScript 模组，在 Mods Menu 运行它时也会被列出。Mod Panel 附带一个小的 JavaScript 文件 `AAModPanelLink`，它把每个模组交给 Mods Menu 的内容转交给 Mod Panel：你的模组不需要添加任何东西。之后 Mod Panel 会像 Mods Menu 一样读取和写入你的 Key=Value 设置文件；如果该文件还不存在，Mod Panel 会在第一次更改时创建它及其文件夹。在 Mod Panel 中：

- `action` 行不会显示：它们运行游戏脚本内部的函数，Mod Panel 无法触及；
- 如果 `choice` 行的某个选项的值包含 `;` 或 `#`，该行不会显示：Key=Value 文件会把它们当作注释的开始；
- 不会写信号文件（[第 6 节](#6-让更改立即生效的信号文件)）：你的模组会自己重新读取它的文件。

Mod Panel 最多列出 64 个 JavaScript 模组。每次打开面板时都会重新读取它们的列表。

## 3. 设置文件

`<FolderName>.config.json`，位于你的 `Scripts` 文件夹旁边：

- **由你的模组写入**，在首次启动时写入默认值。Mod Panel 从不创建设置文件，也从不写入只读的设置文件。
- **一个 JSON 对象。** Mod Panel 只修改玩家更改过的值，其他所有键都保持原样，包括未知的键（[第 5 节](#5-mod-panel-如何写入你的设置)）。
- **宽容地读取：** 忽略你不认识的键，缺失的键使用其默认值，无法读取的文件则当作默认值处理，并在你的日志中记一行。玩家可能会手动编辑这个文件。
- **如果你的模组之后还要再次写入它**（例如更新后要添加一个键），请先写入临时文件，再重命名覆盖旧文件，这样就不会有人看到写到一半的文件。

说明文件中没有任何一行提到的键，仍然会根据它的值得到一行：

| 文件中的值 | 行 |
|---|---|
| `true` 或 `false` | `toggle` |
| 数字 | `number`，整数的步长为 1，否则为 0.1，没有上下限，也没有滑条 |
| 字符串 | `readonly`：显示文本，呈灰色，不能更改 |
| 对象、数组或 `null` | 没有行 |

这样的行没有默认值：“恢复默认设置”（`Restore defaults`）不会改动它。它的键必须遵守行键的规则（[第 4 节](#通用字段)）。请改为在说明文件中描述每一个设置：这样玩家就能得到标签、解释、上下限和默认值。

## 4. 说明文件

`<FolderName>.modsmenu.json`，位于设置文件旁边，最大 256 KiB。如果没有它，或者它不是有效的 JSON，各行就只来自设置文件，原因会写入日志。

### 模组本身

| 字段 | 含义 |
|---|---|
| `title` | 一个[文本](#文本)，最多 80 个字符。没有它时使用文件夹名 |
| `description` | 一个文本，最多 300 个字符，与版本号一起显示在“说明”栏的底部 |
| `version` | 一个字符串，最多 20 个字符 |
| `settings` | 行的数组，按其显示顺序排列。一个模组最多显示 100 行：先是你的行，然后是由设置文件生成的行（[第 3 节](#3-设置文件)） |
| `greyedUnless` | 一个[条件](#灰色的行)：条件不满足时，该模组的所有行都显示为灰色 |

### 文本

文本要么是一个字符串（英文），要么是一个语言对象：

```json
"label": { "en": "Strength", "fr": "Force", "ja": "強さ", "zh-Hans": "强度", "zh-Hant": "強度" }
```

- `en` 必填：没有英文的文本视为不存在。
- 游戏的其他语言都是可选的：`de`、`es-419`（拉丁美洲西班牙语）、`es-ES`、`fr`、`it`、`ja`、`ko`、`pt-BR`、`pt-PT`、`ru`、`th`、`vi`、`zh-Hans`（简体中文）和 `zh-Hant`（繁体中文），与 Mods Menu 读取的代码相同。常见的其他写法也会被读取（`zh-CN`、`zh-TW`、`es`、`pt`、`ja-JP` 等）；精确的代码优先于其他写法。其他任何键都会被忽略。
- 面板显示它自己的语言：游戏的语言，或玩家在 Mod Panel 的 `Language`（语言）行中选择的语言。某种语言缺失的文本会先使用相近的语言（简体与繁体中文、两种西班牙语、两种葡萄牙语），再回退到英文。
- 两端的空格会被去掉，超过长度限制的文本会被截断。

### 通用字段

| 字段 | 含义 |
|---|---|
| `type` | 必填：`toggle`、`choice`、`number`、`key`、`action`、`heading` 或 `readonly` |
| `key` | 必填，`heading` 除外：该设置在设置文件中的键。只能使用字母、数字和 `_`，最多 64 个字符 |
| `label` | 一个文本，最多 80 个字符。没有它时使用键 |
| `help` | 一个文本，最多 400 个字符，该行被选中时显示在“说明”栏中 |
| `restart` | `true`：在帮助文字下方显示“重启后生效。”（Applies after a restart.）。用于你的模组只在游戏启动时才读取的设置 |
| `default` | `toggle`、`choice`、`key` 和 `number` 必填：“恢复默认设置”（`Restore defaults`）放回的值 |
| `missing` | 键不在设置文件中，或其值无法使用时显示的值。没有它时使用默认值 |
| `greyedUnless` | 一个[条件](#灰色的行)：条件不满足时，该行显示为灰色 |
| `neverGreyed` | `true`：模组的 `greyedUnless` 永远不会让这一行变灰 |

### `toggle`

开启或关闭。写入为 `true` 或 `false`。读取时接受 `true` 或 `false`，也接受 `"on"`、`"off"`、`"yes"`、`"no"`、`"true"`、`"false"`、`1` 和 `0`。

```json
{ "key": "CleanImage", "type": "toggle", "label": "Clean image", "default": false,
  "help": "On: no vignette, film grain or bloom. Off: the game's image." }
```

### `choice`

一个选项列表，用左右键逐项切换。

- `options`：1 到 64 个选项。每个选项要么是一个值（字符串、数字、`true` 或 `false`），要么是一个对象 `{ "value": ..., "label": text }`。值按写入的样子计算，最多 64 个字符，且在同一行内；标签最多 40 个字符。没有标签时显示该值。
- `default` 必须是这些值之一。
- 写入为该选项的值，并保留其 JSON 类型：`"Far"`、`2`、`true`。
- `"slider": true` 把该行显示为滑条，条件是它有两个或更多选项，且每个值都是数字，但第一个或最后一个最多可以有一个单词（`"Off", 1, 2, 3`）。

```json
{ "key": "Preset", "type": "choice", "label": "Preset", "default": "Default",
  "options": [
    { "value": "Close", "label": "Close" },
    { "value": "Default", "label": "Default" },
    { "value": "Far", "label": "Far" }
  ] }
```

**控制器按键。** 当一个 `choice` 的每个值都是下表中的按键名或 `"None"`，并且至少有一个按键时，面板会把每个按键显示为其 PlayStation 或 Xbox 图标，并且在使用控制器时，在该行上按×键（Cross）后，面板会等待玩家按下列表中的某个按键。无需添加任何东西：使用引擎的名称作为值即可。游戏没有图标的按键（触摸板键、选项键、视图键、菜单键和摇杆方向）显示其名称。

| 值 | PlayStation | Xbox |
|---|---|---|
| `Gamepad_FaceButton_Bottom` | ×键（Cross） | A |
| `Gamepad_FaceButton_Right` | ○键（Circle） | B |
| `Gamepad_FaceButton_Left` | □键（Square） | X |
| `Gamepad_FaceButton_Top` | △键（Triangle） | Y |
| `Gamepad_LeftShoulder`, `Gamepad_RightShoulder` | L1, R1 | LB, RB |
| `Gamepad_LeftTrigger`, `Gamepad_RightTrigger` | L2, R2 | LT, RT |
| `Gamepad_LeftThumbstick`, `Gamepad_RightThumbstick` | L3, R3 | LS, RS |
| `Gamepad_DPad_Up`, `_Down`, `_Left`, `_Right` | 方向键（D-pad） | 方向键（D-pad） |
| `Gamepad_LeftStick_Up`, `_Down`, `_Left`, `_Right` | 左摇杆（Left stick） | 左摇杆（Left stick） |
| `Gamepad_RightStick_Up`, `_Down`, `_Left`, `_Right` | 右摇杆（Right stick） | 右摇杆（Right stick） |
| `Gamepad_Special_Left` | 触摸板键（Touchpad） | 视图键（View） |
| `Gamepad_Special_Right` | 选项键（Options） | 菜单键（Menu） |
| `PBZ_Gamepad_Create` | 创建键（Create，游戏自己的按键名） | 无（Xbox 控制器没有这个按键） |

方向键和摇杆的方向要写全：`Gamepad_DPad_Down`、`Gamepad_LeftStick_Up`，依此类推。触摸板键和选项键会打开游戏的地图和菜单：提供它们之前请三思。

### `number`

一个数字，用左右键逐步调整；按住方向键会加速。

- `step`：必填，大于 0。写入的值带有步长的小数位数（`0.1` 就是一位小数）。
- 从数字读取，也可以从含有数字的文本读取（`"2"`、`"2,5"`）。
- `min`、`max`：可选；`min` 不得大于 `max`。调整到两端时会停止。
- `default` 必须位于 `min` 和 `max` 之间。
- 同时有 `min` 和 `max` 时，该行显示为滑条；`"slider": false` 则改为在两个箭头之间显示数值。

```json
{ "key": "Distance", "type": "number", "label": "Distance", "default": 0, "min": -50, "max": 100, "step": 5,
  "help": "In % of each view's own distance. 0 is the game's." }
```

### `key`

一个键盘按键。它的选项是固定的；不要写 `options`。写入为引擎中该按键的名称，或 `"None"`。`default` 必须是下列名称之一：

`None`、`F1` 到 `F9`、`F12`、`PageUp`、`PageDown`、`Home`、`End`、`Insert`、`Delete`、`NumPadZero`、`NumPadOne`、`NumPadTwo`、`NumPadFour` 到 `NumPadNine`、`Multiply`、`Add`、`Subtract`、`Decimal`、`Divide`、`G`、`H`、`J`、`L`、`N`、`U`、`Y`、`Zero`、`Nine`。

这些是游戏没有占用的按键。在该行上按×键（Cross）后，面板等待按键（“请按键”，Press a key）；按 Esc 取消，5 秒后等待也会自动结束。面板不提供 F9（它默认用来打开 Mods Menu），也不提供已被某个已列出模组的其他按键行占用的按键，Mod Panel 自己的面板按键也包括在内。`F9` 仍可作为 `default`；如果某个按键行的默认键已被其他按键行使用，“恢复默认设置”不会改动该行。

```json
{ "key": "PanelKey", "type": "key", "label": "Panel key", "default": "F8" }
```

### `action`

一个按钮，告诉你的模组立即做某件事，例如重置镜头。第一次按下使其进入待确认状态（“再按一次”（Press again），3 秒），第二次按下才发送，此时该行显示“已发送”（Sent）。设置文件中不会写入任何内容：动作通过信号文件传递（[第 6 节](#动作)）。

```json
{ "key": "ResetCamera", "type": "action", "label": "Reset the camera",
  "help": "Puts the camera back behind the character." }
```

### `heading`

位于其后各行上方的标题，直到下一个标题为止。`label` 必填；没有 `key`。

```json
{ "type": "heading", "label": { "en": "Camera position", "zh-Hans": "镜头位置" } }
```

每个标题都可以折叠其下方的行：玩家选中标题后按 ×键、Enter、左或右，或点击它的“显示”或“隐藏”。`collapsed: true` 让该部分一开始就是折叠的；没有它时，一开始是展开的。Mod Panel 会保持玩家留下的折叠状态，重新启动游戏后也是如此。它按英文标题识别各部分：修改英文标题会让该部分恢复为你设定的状态，添加或移动部分不会改变其他部分。同一模组中相同的标题按先后顺序区分。“恢复默认设置”也会恢复折叠部分中的行。

```json
{ "type": "heading", "label": { "en": "Advanced", "zh-Hans": "高级" }, "collapsed": true }
```

### `readonly`

显示为灰色、玩家不能更改的值：即其键在设置文件中的值。`key` 可选。

```json
{ "key": "Build", "type": "readonly", "label": "Build", "help": "Written by the mod at its start." }
```

### 灰色的行

`greyedUnless` 保存一个条件：一个对象，其键是该模组的设置，每个键对应它必须具有的值，或一个值的列表。只要其中某个设置不具有它的任何一个值，该行就显示为灰色。

```json
{
  "title": "My Mod",
  "greyedUnless": { "Enabled": true },
  "settings": [
    { "key": "Enabled", "type": "toggle", "label": "Enabled", "default": true },
    { "key": "Preset", "type": "choice", "label": "Preset", "default": "Default",
      "options": [ { "value": "Off", "label": "Off" }, { "value": "Default", "label": "Default" },
                   { "value": "Custom", "label": "Custom" } ] },
    { "key": "Strength", "type": "number", "label": "Strength", "default": 50, "min": 0, "max": 100, "step": 5,
      "greyedUnless": { "Preset": "Custom" } },
    { "key": "Speed", "type": "number", "label": "Speed", "default": 1, "min": 1, "max": 3, "step": 1,
      "greyedUnless": { "Preset": ["Default", "Custom"] } },
    { "key": "PanelKey", "type": "key", "label": "Panel key", "default": "F8", "neverGreyed": true }
  ]
}
```

- **写在行上**时，条件只让这一行变灰。上例中，除非 Preset 为 Custom，否则 Strength 为灰色；Preset 为 Off 时，Speed 为灰色。
- **写在模组上**时，它让所有行变灰，但标题、`readonly` 行、它所指明的设置以及标有 `neverGreyed: true` 的行除外。上例中，Enabled 关闭时，除 Enabled 本身和面板按键外，其余全部为灰色。
- 灰色的行仍然可以被选中。此时它的说明在标签下方、你的帮助文字之前显示“将“Preset”设为“Custom”后可调整此项。”，用你的标签和选项、以玩家的语言写成；条件列出多个值时，只说第一个；两个条件都不满足时，先说模组的条件。除“恢复默认设置”和“撤销”外，任何操作都不会更改灰色的行（方向键、×键、Enter、点击、滑条、等待按键）。
- 条件按面板显示的值判断，包括尚未保存的更改：玩家一把 Preset 设为 Custom，Strength 就立即恢复可调。
- 条件中指明的某个设置会被排除在条件之外，并在日志中记一行，如果它不是该模组的 `toggle`、`choice` 或 `number` 行（`key`、`action`、`heading`、`readonly` 行不能被指明）、是该行自己的键、给出的值是该设置无法取得的，或给出空的值列表，或超过 64 个值。指明超过 100 个设置的条件整体被忽略。写在 `heading` 或 `readonly` 行上的 `greyedUnless` 不起作用。Mods Menu 会忽略 `greyedUnless`、`neverGreyed` 和 `collapsed`：添加它们不会在那边造成任何变化。

### 被省略的行

违反上述任一规则的行会被省略，并在日志中记一行（[第 8 节](#8-检查你的文件)）；其他行仍会显示。常见原因：未知的 `type`，缺失或无效的 `key`，缺失 `default`，`default` 不是选项之一或超出 `min` 和 `max` 的范围，`step` 为 0 或更小，`min` 大于 `max`，`options` 列表为空或多于 64 个。有 `key` 的行才算可用：标题和没有 `key` 的 `readonly` 行不算。没有任何可用行的模组不会被列出。

## 5. Mod Panel 如何写入你的设置

- **何时：** 玩家最后一次更改之后半秒，面板切换到另一个模组之前，发送动作之前，以及面板关闭时。
- **写什么：** Mod Panel 在写入之前再读取一次该文件，然后只在文本中就地修改玩家更改过的值。其他所有键、键的顺序、空白和未知的键都保持原样；文件中没有的键会添加在最后一个右花括号之前。
- **怎么写：** 先写入一个临时文件 `<file>.modpanel-tmp`，把旧文件暂时挪开为 `<file>.modpanel-bak` 以便替换，然后新文件取而代之。如果游戏在中途停止，Mod Panel 会在下次启动时处理被挪开的文件：设置文件缺失时把它放回原处，否则把它重命名为 `<file>.modpanel-kept`；它从不删除这个文件。你的模组可以忽略这三个名称。
- **如果文件被占用**（另一个程序正持有它）：Mod Panel 每秒重试一次，总共尝试五次，在此期间面板显示“设置未保存”（Settings not saved）；最后一次失败会连同原因写入日志。
- **值：** `toggle` 写为 `true` 或 `false`，`number` 写为 JSON 数字，`choice` 写为其选项的值，`key` 写为字符串。文本以 ASCII 写入：ASCII 以外的字符写成 `\uXXXX`，任何 JSON 读取程序都能解码。
- **然后**它通过信号文件通知你的模组，绝不会早于设置文件写完之前。

## 6. 让更改立即生效的信号文件

每写完一个设置文件之后，以及每个动作，Mod Panel 都会为你的模组写一个小的信号文件。Mods Menu 写的是同一个文件，格式也相同：**一个读取程序就能同时服务两个菜单。** 本节针对 UE4SS 模组：JavaScript 模组不会收到信号文件（[第 2 节](#javascript-模组)）。

**位置：** `platform\steam\ue4ss\Mods\PBZModsMenuBridge\events-<FolderName>.txt`。在文件名中，字母、数字和 `_` 保持原样；其他每个字节都变成 `%` 加两位小写十六进制数字（`My Mod` 变成 `events-My%20Mod.txt`）。文件夹不存在时，Mod Panel 会在游戏允许的情况下创建它；否则会在日志中说明，你的模组将在下次启动时采用更改。

**内容**，使用 Windows 换行符：

```
; Mod Panel events for MyMod: numbers only grow, one per event.
Changed=1793000123456
Action=1793000123457 ResetCamera
End=1
```

- `Changed=<n>`：每次你的设置文件被写入后，这个数字就会增大。比你上次看到的数字更大，就表示：重新读取你的设置文件。当文件只携带动作时，它可以为空。
- `Action=<n> <key>`：一个 action 行的键，每个你的模组尚未执行的动作占一行；保留最近的 16 个。
- `End=1`：文件是完整的。没有这一行就说明它还在写入中：下一秒再试。
- 这些数字只增不减：它们从自 1970 年起的毫秒时间开始，每个新事件取一个更大的数字。请把它们当作数字来比较。

**你的模组每秒要做的事：**

1. 读取该文件。如果它不存在，或没有 `End=1` 这一行，就什么都不做，等到下一秒。
2. 如果 `Changed` 大于你上次看到的数字，就重新读取你的设置文件并应用它。
3. 对每个编号大于你的标记的 `Action`，按编号从小到大，执行该键对应的动作；然后把你的新标记写入 `PBZModsMenuBridge\done-<FolderName>.txt`。

在你的模组启动时，把文件中已有的 `Changed` 数字视为已看到：它早于你的模组启动，而且你的模组在启动时本来就会读取它的设置。

### 动作

标记文件 `done-<FolderName>.txt` 保存你的模组所执行的最后一个动作的编号，写在一行 `Action=<n>` 中，如果你愿意，可以在它上面加一行注释。Mod Panel 读取它，但从不写入它：当它再次写信号文件时，会丢弃编号等于或小于你的标记的动作。没有标记文件时，你的模组的标记为 0。

### Lua 示例

把它复制到你的模组中；文件夹名取自脚本自身的路径。请在你的模组的循环中每秒调用一次 `Signal.second(reload, run_action)`，其中 `reload()` 重新读取你的设置文件，`run_action(key)` 执行一个 action 行对应的动作。

```lua
-- my_mod_signal.lua: takes new settings at once, and runs actions, sent by Mod Panel or Mods Menu.
local Signal = {}

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_dir = source:match("^(.*)[/\\]Scripts[/\\][^/\\]+$")      -- ...\Mods\MyMod
local name = mod_dir:match("([^/\\]+)$")                               -- MyMod
local bridge = mod_dir:match("^(.*)[/\\][^/\\]+$") .. "/PBZModsMenuBridge/"

local function encode(s)
	return (s:gsub("[^A-Za-z0-9_]", function(c) return string.format("%%%02x", c:byte()) end))
end
local EVENTS = bridge .. "events-" .. encode(name) .. ".txt"
local DONE = bridge .. "done-" .. encode(name) .. ".txt"

local function read(path)
	local f = io.open(path, "rb")
	if f == nil then return nil end
	local text = f:read(8192)
	f:close()
	return text
end

-- The signal file's text with a line end before its first line, or nil while it is missing or being written.
local function whole()
	local text = read(EVENTS)
	if text == nil or not text:find("\nEnd=1", 1, true) then return nil end
	return "\n" .. text
end

local first = whole()
local last_changed = first and tonumber(first:match("\nChanged=(%d+)")) or 0
local mark = tonumber(("\n" .. (read(DONE) or "")):match("\nAction=(%d+)")) or 0

-- Windows cannot rename onto an existing file: the old mark goes first. If the game stops in between, the mark is
-- lost and the actions still listed run again; keep your actions safe to run twice.
local function save_mark()
	local temporary = DONE .. ".tmp"
	local f = io.open(temporary, "wb")
	if f == nil then return end
	f:write("; " .. name .. ": the last action it ran.\r\nAction=" .. mark .. "\r\n")
	f:close()
	os.remove(DONE)
	os.rename(temporary, DONE)
end

function Signal.second(reload, run_action)
	local text = whole()
	if text == nil then return end
	local changed = tonumber(text:match("\nChanged=(%d+)"))
	if changed ~= nil and changed > last_changed then
		last_changed = changed
		reload()
	end
	local todo = {}
	for n, key in text:gmatch("\nAction=(%d+) ([A-Za-z0-9_]+)") do
		n = tonumber(n)
		if n > mark then todo[#todo + 1] = { n = n, key = key } end
	end
	table.sort(todo, function(a, b) return a.n < b.n end)
	for _, action in ipairs(todo) do
		run_action(action.key)
		mark = action.n
	end
	if #todo > 0 then save_mark() end
end

return Signal
```

不读取信号文件的模组仍然可以工作：它会在下次启动时采用新的设置。Mod Panel 1.0.1 不会发送 Mods Menu 的控制台命令。

## 7. 模组有自己的面板或自行读取按键时

**同一时间只有一个面板。** 两个面板同时打开，会争夺控制器、光标和游戏的输入模式。Mod Panel 和遵守这条规则的面板共用一个 UE4SS 变量 `PBZ_OpenPanel`：

- 它里面始终是文本：打开着面板的那个模组的文件夹名，一个空格，然后是以整秒计的 `os.time()`（`MyMod 1793000123`）；没有面板打开时为 `""`。绝不要把它设为 `nil`。
- 面板在显示时写入它的值，保持打开期间每秒再写一次，关闭时写入 `""`，但只有在该变量仍然保存着它自己的名称时才这样做。
- 在打开之前，即在按键时以及显示之前，面板都要读取这个变量。如果它保存的是另一个模组的名称，且其时间与 `os.time()` 相差不超过 3 秒（无论早于还是晚于），面板就不打开。其他任何值都不算数：空值、无法读取、它自己的名称，或更早的时间。因此，被不当关闭的面板只会阻挡其他面板 3 秒。
- 文件夹名中可以有空格：时间是该值的最后一个词。

```lua
-- Whether another mod's panel is open now.
local function other_panel_open(my_name)
	local ok, value = pcall(function() return ModRef:GetSharedVariable("PBZ_OpenPanel") end)
	if not ok or type(value) ~= "string" then return false end
	local owner, time = value:match("^(.+) (%d+)$")
	return owner ~= nil and owner ~= my_name and math.abs(os.time() - tonumber(time)) <= 3
end
```

**由你的模组读取的按键。** Mod Panel 打开期间，游戏听不到控制器的任何按键，也听不到它所使用的任何按键。自己读取按键的模组（例如用 `IsInputKeyDown`）仍可能看到玩家在面板中做出的按键操作。请用上面的函数检查 `PBZ_OpenPanel`，并使用你自己的文件夹名，在有面板打开时忽略这些按键操作。

## 8. 检查你的文件

Mod Panel 会在 `platform\steam\ue4ss\UE4SS.log` 中写入它省略的每一行和它不列出的每一个模组，每次运行游戏、每种原因只写一次。每一行以时间和 `[Lua]` 开头；请搜索 `[ModPanel]` 和你的文件夹名：

```
[ModPanel] MyMod: setting Hotkey: default F13, left out
[ModPanel] MyMod: the descriptor is not JSON (...), rows from the settings file instead
[ModPanel] MyMod: the settings file is not one JSON object, not shown
[ModPanel] MyMod: no usable setting (type color), not shown
[ModPanel] MyMod: setting Strength: greyedUnless Preset, a value it cannot take, left out
```

从你的文件中引用的键或值超过 64 个字符时会被截断并加上 `...`，其中的换行符或其他控制字符显示为 `?`。

每次保存你的设置时，Mod Panel 还会写出它更改了哪些值：`[ModPanel] MyMod: settings written (Strength 2)`。请把它与你的模组声称读取到的内容对照。文件无法写入时：`[ModPanel] MyMod: settings not saved (the settings file is read-only, or held by another program)`。

## 9. 许可协议

本指南中的代码和 JSON 示例以 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) 献给公有领域：你可以把它们复制到自己的模组中，无论是否修改，也无论是否署名。

Mod Panel 本身采用 [PolyForm Strict License 1.0.0](https://polyformproject.org/licenses/strict/1.0.0)。要让你的模组与 Mod Panel 配合工作，不需要它的任何代码：你写自己的文件，采用本指南所描述的格式即可。
